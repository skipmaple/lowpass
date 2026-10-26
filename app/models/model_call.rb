# 模型调用账本（R-9.8）：每次调用一条，费用本地按单价算（设计 C2）；保留 90 天
class ModelCall < ApplicationRecord
  RETENTION = 90.days
  STATUSES = %w[ ok failed timed_out invalid abstained ].freeze

  belongs_to :issue, optional: true
  belongs_to :item, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :error_summary, length: { maximum: 200 }, allow_nil: true
  validates :purpose, inclusion: { in: %w[ reason translation ] }
  validates :operation_key, length: { maximum: 36 }, allow_nil: true
  with_options if: -> { purpose == "translation" } do
    validates :operation_key, presence: true
    validates :input_field, inclusion: { in: %w[ title summary ] }
    validates :input_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  end

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  def self.cleanup(batch_size: 500)
    ModelOperationStop.where(expires_at: ..Time.current).delete_all
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
