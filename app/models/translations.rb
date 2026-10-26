# D39：日刊译文独立补缺，不依赖推荐理由或兴趣画像。
module Translations
  def self.ready? = Reasons::Provider.configured? && !Reasons::Budget.exhausted?

  def self.unready_label
    Reasons::Provider.configured? ? "本月费用已达上限，已停止生成" : "未配置模型供应商"
  end

  # 只在入队时决定当日范围；后续重排与跨午夜不重新选取条目。
  def self.automatic_context(issue, item_ids:)
    { "operation" => ModelRequests.operation,
      "translation_targets" => issue.period_key == PeriodKey.today ? targets(issue, item_ids: item_ids) : [] }
  end

  def self.targets(issue, item_ids: nil, reassess: false)
    scope = issue.items.visible.ranked.includes(:source, :issue, :translation_preservations)
    scope = scope.where(id: item_ids) if item_ids
    scope.filter_map { |item| item.translation_target if item.needs_translation?(reassess: reassess) }
  end
end
