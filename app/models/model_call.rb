# 模型调用账本（R-9.8）：每次调用一条，费用本地按单价算（设计 C2）；保留 90 天
class ModelCall < ApplicationRecord
  RETENTION = 90.days
  STATUSES = %w[ ok failed timed_out invalid ].freeze

  belongs_to :issue, optional: true
  belongs_to :item, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :error_summary, length: { maximum: 200 }, allow_nil: true

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
