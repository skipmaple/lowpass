module Item::Translating
  extend ActiveSupport::Concern

  included do
    has_many :translation_preservations
  end

  class_methods do
    def translation_counts_by_issue(issue_ids)
      counts = issue_ids.index_with { { pending: 0, preserved: 0 } }
      visible.where(issue_id: issue_ids).includes(:source, :issue, :translation_preservations).each do |item|
        if item.translation_field && item.public_send("#{item.translation_field}_zh").blank?
          counts.fetch(item.issue_id)[item.needs_translation? ? :pending : :preserved] += 1
        end
      end
      counts
    end
  end

  def translation_field
    return unless !hidden? && issue.kind == "daily" && issue.published?

    if translate_title?
      "title"
    elsif translate_summary?
      "summary"
    end
  end

  def translation_digest(field)
    Digest::SHA256.hexdigest([ 1, issue.kind, source_id, source.adapter, source.publication, field, public_send(field) ].to_json)
  end

  def translation_target
    if field = translation_field
      { "item_id" => id, "field" => field, "input_digest" => translation_digest(field) }
    end
  end

  def needs_translation?(reassess: false)
    field = translation_field
    return false unless field && public_send("#{field}_zh").blank?

    reassess || translation_preservations.none? { |marker| marker.field == field && marker.input_digest == translation_digest(field) }
  end

  # 请求/账本在外层；这里仅短事务核对冻结输入并保存成功结果。
  def store_translation(result, target:, assessed_at:)
    with_lock do
      source.reload
      issue.reload
      field = translation_field
      next false unless target["item_id"] == id && field == target["field"] && field &&
        translation_digest(field) == target["input_digest"] && public_send("#{field}_zh").blank?

      if result.decision == "translated"
        update!("#{field}_zh" => result.text)
        translation_preservations.where(field: field).delete_all
      else
        marker = translation_preservations.find_or_initialize_by(field: field)
        marker.update!(input_digest: target.fetch("input_digest"), assessed_at: assessed_at)
      end
      association(:translation_preservations).reset
      true
    end
  rescue ActiveRecord::RecordNotFound
    false
  end
end
