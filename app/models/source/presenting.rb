# 后台信息源页的 props（R-3.1）：健康度由最近记录推导（Source::Fetching#health），上次抓取与下次计划都是展示用的短句
module Source::Presenting
  extend ActiveSupport::Concern

  HEALTH_LABELS = { "ok" => "正常", "recent_failure" => "最近失败", "consecutive_failures" => "连续失败", "disabled" => "已停用" }.freeze
  RUN_LIMIT = 50

  class_methods do
    def admin_rows(now: Time.current)
      times = { "daily" => Setting.get("daily_time"), "weekly" => Setting.get("weekly_time") }
      # sort_order 只在同一刊物内唯一（R-1.8）：跨刊物列全部源时先按刊物分组（daily 排在 weekly 前），
      # 组内再按 sort_order、name；不能直接用 ordered（order(:sort_order, :name)），两个刊物的排序值会交叉
      order(:publication, :sort_order, :name).map do |source|
        health = source.health
        {
          id: source.id, sort_order: source.sort_order, name: source.name, adapter: source.adapter, adapter_label: source.adapter_label,
          publication: source.publication, enabled: source.enabled, health: health, health_label: HEALTH_LABELS.fetch(health),
          last_fetch_label: source.last_fetch_label, next_run_label: (source.next_run_label(times.fetch(source.publication), now: now) if source.enabled?),
          config: source.config
        }
      end
    end

    def adapter_options
      Source::ADAPTERS.map { |key| { key: key, label: Source::ADAPTER_LABELS.fetch(key), publications: Source::Config.for(key).publications } }
    end
  end

  # 新建来源时 name 还没填，AR 属性是 nil；AdminSourceForm.name 的类型承诺是 string 不是 string | null——
  # 不补 to_s 的话表单拿到 null，测试抓取成功后自动填名称那行的 name.trim() 直接抛出
  def form_props
    { id: id, name: name.to_s, adapter: adapter, publication: publication, sort_order: sort_order, config: config }
  end

  # 「9月8日 06:12 · 成功 · 10 条」/「9月9日 06:05 · 超时 · 连接超时」；测试抓取不算
  def last_fetch_label
    run = fetch_runs.where(trigger: %w[ scheduled manual ]).where.not(status: %w[ queued running ]).ordered.first
    if run.nil?
      "尚未抓取"
    elsif run.status == "succeeded"
      "#{stamp(run.started_at)} · 成功 · #{run.item_count.to_i} 条"
    else
      [ stamp(run.started_at), run.status_label, run.error_summary.to_s[0, 40].presence ].compact.join(" · ")
    end
  end

  # R-3.1 下次计划时间：今天的生成时间还没到就是今天，否则明天（周刊源看周刊检查时间）
  def next_run_label(hhmm, now: Time.current)
    local = now.in_time_zone(PeriodKey::ZONE)
    hour, minute = hhmm.split(":").map(&:to_i)
    at = local.change(hour: hour, min: minute)
    at += 1.day if at <= local
    stamp(at)
  end

  def run_rows(status)
    scope = fetch_runs.ordered.limit(RUN_LIMIT)
    scope = scope.where(status: "succeeded") if status == "succeeded"
    scope = scope.where(status: %w[ failed timed_out ]) if status == "failed"
    scope.map do |run|
      {
        id: run.id, started_label: run.started_at && "#{stamp(run.started_at)}:#{run.started_at.in_time_zone(PeriodKey::ZONE).strftime('%S')}",
        duration_label: run.duration_ms && format("%.1f 秒", run.duration_ms / 1000.0), status: run.status, status_label: run.status_label,
        attempt_label: "#{run.attempt} / #{FetchSourceJob::MAX_ATTEMPTS}", item_count: run.item_count, dropped_count: run.dropped_count,
        error_summary: run.error_summary, trigger_label: run.trigger_label
      }
    end
  end

  private
    def stamp(time)
      local = time.in_time_zone(PeriodKey::ZONE)
      "#{local.month}月#{local.day}日 #{local.strftime("%H:%M")}"
    end
end
