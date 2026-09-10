module Issue::Daily
  extend ActiveSupport::Concern

  ISSUE_TIMEOUT = 20.minutes

  class_methods do
    # R-1.1 建期后并行启动所有启用日刊源的抓取，期生成器不认识具体的源
    def generate_daily!(period_key, late: false, trigger: "scheduled")
      issue = daily.create!(period_key: period_key, state: "generating", generation_started_at: Time.current, generated_late: late)
      Source.enabled.daily.find_each { |source| source.fetch_later(issue, trigger: trigger) }
      issue
    end

    # R-1.5 重抓成功则整栏替换并记修订时间；失败时 fetch_now 抛出，旧内容原样保留
    # 期还在生成中时不提前发布：这次抓取只贡献它那一栏，是否结束这一期交给 finalize_if_done! 判断
    def regenerate_source!(issue, source)
      run = source.fetch_now(issue, trigger: "manual")
      unless issue.generating?
        issue.update!(revised_at: Time.current, state: "published", published_at: issue.published_at || Time.current) if run.status == "succeeded"
      end
      run
    end
  end

  def daily_sources
    Source.enabled.daily.ordered
  end

  # AC-1.7 成功返回 0 条也算成功，栏内显示「今日无新内容」
  def source_state(source)
    last = latest_run(source)

    if last.nil? || last.status.in?(%w[ queued running ])
      generating? ? "pending" : "failed"
    elsif last.status != "succeeded"
      "failed"
    else
      last.item_count.to_i.zero? ? "empty" : "ok"
    end
  end

  def timed_out?
    generating? && generation_started_at < ISSUE_TIMEOUT.ago
  end

  private
    # 归档页一次列一个月：期带着 fetch_runs 预加载进来时就在内存里挑，不然一行三次查询。
    # 抓取路径上没人预加载这个关联（写记录走的是 source.fetch_runs），所以拿不到过期的内存副本。
    def latest_run(source)
      if fetch_runs.loaded?
        fetch_runs.select { |run| run.source_id == source.id }.max_by(&:created_at)
      else
        fetch_runs.where(source: source).ordered.first
      end
    end
end
