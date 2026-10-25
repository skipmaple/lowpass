# D39：日刊译文独立补缺，不依赖推荐理由或兴趣画像。
module Translations
  def self.targets(issue, item_ids: nil, reassess: false)
    scope = issue.items.visible.ranked.includes(:source, :issue, :translation_preservations)
    scope = scope.where(id: item_ids) if item_ids
    scope.filter_map { |item| item.translation_target if item.needs_translation?(reassess: reassess) }
  end
end
