module Issue::Finalization
  extend ActiveSupport::Concern

  # 每个源到终态后调用一次：还有源没有结果就继续等，全部有结果就结束这一期
  def finalize_if_done!
    return unless generating?

    finalize!(reason: "complete") if daily_sources.none? { |source| source_state(source) == "pending" }
  end

  # R-1.3 至少一个源有结果则发布，全部失败则空刊。期级超时也走这里，未完成的源按失败处理。
  # 各源的结果在这里固化进 source_states：抓取记录只保留 30 天（F-26），过了保留期就再也
  # 推导不出这一期各栏的结果，页面会把还在库里的条目误报成「今日抓取失败」。
  def finalize!(reason:)
    with_lock do
      return unless generating?

      states = daily_sources.index_by(&:id).transform_values { |source| finalized_state(source) }
      published = states.value?("ok") || states.value?("empty")
      update!(state: published ? "published" : "empty", published_at: Time.current, source_states: states)
      Rails.logger.info { "Issue #{period_key} finalized as #{state} (#{reason}): #{states.values.tally.to_a.map { |s, n| "#{s} #{n}" }.join(", ")}" }
    end
  end

  private
    # 期结束时还没有结果的源按失败处理（R-1.3）
    def finalized_state(source)
      state = source_state(source)
      state == "pending" ? "failed" : state
    end
end
