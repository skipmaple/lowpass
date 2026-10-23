module Item::Reasoning
  extend ActiveSupport::Concern

  included do
    has_one :reason_abstention

    scope :daily, -> { joins(:issue).where(issues: { kind: "daily" }) }
    scope :without_reason_abstention, -> { where.missing(:reason_abstention) }
    scope :pending_reasons, -> { visible.daily.where(reason: nil).without_reason_abstention }
    scope :reusable_reasons, -> { daily.where.not(reason: nil).without_reason_abstention }
  end

  class_methods do
    def reason_counts_by_issue(issue_ids)
      result = issue_ids.index_with { { with_reason: 0, abstained: 0, retained: 0, missing: 0, last_assessed_at: nil } }
      return result if issue_ids.empty?

      items = visible.daily.where(issue_id: issue_ids).left_joins(:reason_abstention)
      items.group(:issue_id, Arel.sql("items.reason IS NOT NULL"), Arel.sql("reason_abstentions.id IS NOT NULL")).count.each do |(issue_id, has_reason, marked), count|
        key = if marked
          has_reason ? :retained : :abstained
        elsif has_reason
          :with_reason
        end
        result.fetch(issue_id)[key] = count if key
      end
      pending_reasons.where(issue_id: issue_ids).group(:issue_id).count.each { |id, count| result.fetch(id)[:missing] = count }
      items.group(:issue_id).maximum("reason_abstentions.assessed_at").each { |id, time| result.fetch(id)[:last_assessed_at] = time }
      result
    end
  end

  def record_reason_abstention(assessed_at:)
    with_lock do
      marker = ReasonAbstention.find_or_initialize_by(item_id: id)
      marker.update!(assessed_at: assessed_at)
      association(:reason_abstention).reset
      marker
    end
  end

  # 网络与账本不在此事务内；只提交本次合法内容与判断状态。
  def store_generated_reason(result, generated_at:)
    with_lock do
      attributes = { reason: result.reason, interest_tag: result.interest_tag, reason_generated_at: generated_at }
      attributes[:title_zh] = result.title_zh if translate_title? && result.title_zh
      attributes[:summary_zh] = result.summary_zh if translate_summary? && result.summary_zh
      update!(attributes)
      ReasonAbstention.where(item_id: id).delete_all
      association(:reason_abstention).reset
    end
    nil
  end
end
