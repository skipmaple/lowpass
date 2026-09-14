module Source::Fetching
  extend ActiveSupport::Concern

  def fetch_later(issue, trigger: "scheduled", backfill: false)
    FetchSourceJob.perform_later(self, issue, trigger, backfill)
  end

  # R-3.10 管理员手动重抓：排队记录先写下再入队。重定向回来的页面就是靠它开轮询、把按钮画成
  # 「进行中」的，等 worker 拿到 job 才建就晚了——那几秒里 active_runs 是空的，重复点击也挡不住。
  # fetch_now 与 Issue::Weekly.refetch_weekly! 会认领这条占位，不另开一条
  def refetch_later(issue)
    run = queue_retry(issue, trigger: "manual", attempt: 1)
    begin
      FetchSourceJob.perform_later(self, issue, "manual", false)
    rescue StandardError
      run.destroy   # 入不了队就别留一条永远「进行中」的占位
      raise
    end
    run
  end

  def fetch_now(issue, trigger:, attempt: 1, backfill: false)
    run = fetch_runs.find_by(issue: issue, attempt: attempt, status: "queued", trigger: trigger) || fetch_runs.new(issue: issue, trigger: trigger, attempt: attempt)
    run.update!(status: "running", started_at: Time.current)

    # R-1.4 期已经定稿：只有管理员手动重抓（R-1.5）才允许改写，迟到的调度抓取原样放弃
    if issue && !issue.generating? && trigger != "manual"
      run.update!(status: "failed", error_summary: "期已定稿，放弃写入", duration_ms: 0)
    else
      entries = if backfill
        adapter_class.new(self).backfill(PeriodKey.date_of(issue.period_key))
      else
        adapter_class.new(self).fetch(period_key: (issue.period_key if issue&.kind == "weekly"))
      end
      kept, dropped = entries.partition(&:valid?)
      # 5.7 解析退化：丢弃过半仍然发布剩下的，但要告警；不过半的成功抓取顺手恢复之前的退化事件
      degraded = entries.any? && dropped.size > kept.size
      Alerts.parse_degraded!(self, issue, "丢弃 #{dropped.size} / #{entries.size} 条") if degraded
      # 同源重复地址在写入时被去掉，也要计进 dropped_count：不然 item_count 报的是抓到几条，
      # 不是这一栏真的有几条，栏级「今日无新内容」也就判错了
      deduped = issue ? issue.replace_section!(self, kept) : 0
      run.update!(status: "succeeded", item_count: kept.size - deduped, dropped_count: dropped.size + deduped, duration_ms: elapsed(run))
      Alerts.recover!(kind: "source_failed", source: self)
      Alerts.recover!(kind: "parse_degraded", source: self) unless degraded
      # 一次抓取允许 60 秒，期可能正好在这中间定稿：按最新状态决定，不是进来时那份
      issue&.reload
      # R-1.5 管理员手动重抓已定稿的期：整栏已换过，记修订时间与该栏结果。走 job 的路径也要记，不只同步的 regenerate_source!
      issue.revise!(self, run) if issue && trigger == "manual" && !issue.generating?
    end

    run
  # 设计上的「不能」，不是这次抓取出了事：错误文案是固定的那一句，不重试也不进告警（FetchSourceJob 丢弃）
  rescue Adapters::NoBackfill
    run.update!(status: "failed", error_summary: "该来源无法回填", duration_ms: elapsed(run))
    raise
  rescue Timeout::Error => e
    run.update!(status: "timed_out", error_summary: e.message.to_s.lines.first.to_s.strip[0, 200], duration_ms: elapsed(run))
    raise
  rescue StandardError => e
    run.update!(status: "failed", error_summary: e.message.to_s.lines.first.to_s.strip[0, 200], duration_ms: elapsed(run))
    raise
  end

  # 可重试失败先占位，让期知道这个源还没结束；FetchSourceJob 的 retry_on 重试时 fetch_now 会复用这条记录
  def queue_retry(issue, trigger:, attempt:)
    fetch_runs.create!(issue: issue, trigger: trigger, attempt: attempt, status: "queued")
  end

  # 栏级失败态里的「上次成功 9月7日 06:11」：不限本期，最近一次成功抓取的时间
  def last_ok_at
    fetch_runs.where(status: "succeeded").ordered.first&.started_at
  end

  def health
    return "disabled" unless enabled?
    recent = fetch_runs.where(trigger: %w[ scheduled manual ]).where.not(status: %w[ running queued ]).ordered.limit(3).pluck(:status)
    return "ok" if recent.empty? || recent.first == "succeeded"
    failures = recent.take_while { |s| s != "succeeded" }.size
    failures >= 3 ? "consecutive_failures" : "recent_failure"
  end

  private
    def elapsed(run)
      ((Time.current - run.started_at) * 1000).to_i
    end
end
