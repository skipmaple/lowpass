module Source::Fetching
  extend ActiveSupport::Concern

  def fetch_later(issue, trigger: "scheduled")
    FetchSourceJob.perform_later(self, issue, trigger)
  end

  def fetch_now(issue, trigger:, attempt: 1)
    run = fetch_runs.find_by(issue: issue, attempt: attempt, status: "queued", trigger: trigger) || fetch_runs.new(issue: issue, trigger: trigger, attempt: attempt)
    run.update!(status: "running", started_at: Time.current)

    # R-1.4 期已经定稿：只有管理员手动重抓（R-1.5）才允许改写，迟到的调度抓取原样放弃
    if issue && !issue.generating? && trigger != "manual"
      run.update!(status: "failed", error_summary: "期已定稿，放弃写入", duration_ms: 0)
    else
      entries = adapter_class.new(self).fetch(period_key: (issue.period_key if issue&.kind == "weekly"))
      kept, dropped = entries.partition(&:valid?)
      issue.replace_section!(self, kept) if issue
      run.update!(status: "succeeded", item_count: kept.size, dropped_count: dropped.size, duration_ms: elapsed(run))
    end

    run
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
