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
      issue.revise!(source, run) if !issue.generating? && run.status == "succeeded"
      run
    end

    # 一期列哪些栏：定稿的期只认它自己记下的源（R58），后来停用的源照样有内容，后来新增的
    # 源不出现在旧期里；生成中与缺期按当前启用的日刊源。pool 是一次查好的全部源——归档一页
    # 列一个月，不能一行一次查询。
    def daily_columns(issue, pool)
      if issue.nil? || issue.generating?
        pool.select { |source| source.enabled? && source.publication == "daily" }
      else
        pool.select { |source| issue.source_states.key?(source.id) }
      end
    end
  end

  def daily_sources
    Source.enabled.daily.ordered
  end

  # AC-1.7 成功返回 0 条也算成功，栏内显示「今日无新内容」。
  # 定稿之后读固化下来的结果：抓取记录 30 天后清掉（F-26），推导不出来的栏不能变成失败。
  def source_state(source)
    generating? ? pending_state(source) : source_states[source.id] || "failed"
  end

  # R-1.5 重抓成功：整栏已经换过了，这里记修订时间，并改写这一栏固化下来的结果
  def revise!(source, run)
    update!(revised_at: Time.current, state: "published", published_at: published_at || Time.current,
      source_states: source_states.merge(source.id => run.item_count.to_i.zero? ? "empty" : "ok"))
  end

  def timed_out?
    generating? && generation_started_at < ISSUE_TIMEOUT.ago
  end

  private
    def pending_state(source)
      last = latest_run(source)

      if last.nil? || last.status.in?(%w[ queued running ])
        "pending"
      elsif last.status != "succeeded"
        "failed"
      else
        last.item_count.to_i.zero? ? "empty" : "ok"
      end
    end

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
