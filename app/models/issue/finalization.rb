module Issue::Finalization
  extend ActiveSupport::Concern

  # 每个源到终态后调用一次：还有源没有结果就继续等，全部有结果就结束这一期
  def finalize_if_done!
    return unless generating?

    finalize!(reason: "complete") if daily_sources.none? { |source| source_state(source) == "pending" }
  end

  # R-1.3 至少一个源有结果则发布，全部失败则空刊。期级超时也走这里，未完成的源按失败处理
  def finalize!(reason:)
    with_lock do
      return unless generating?

      succeeded = daily_sources.any? { |source| source_state(source).in?(%w[ ok empty ]) }
      update!(state: succeeded ? "published" : "empty", published_at: Time.current)
    end
  end
end
