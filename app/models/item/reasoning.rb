module Item::Reasoning
  extend ActiveSupport::Concern

  included do
    has_one :reason_abstention

    scope :daily, -> { joins(:issue).where(issues: { kind: "daily" }) }
    scope :without_reason_abstention, -> { where.missing(:reason_abstention) }
    scope :pending_reasons, -> { visible.daily.where(reason: nil).without_reason_abstention }
    scope :reusable_reasons, -> { daily.where.not(reason: nil).without_reason_abstention }
  end
end
