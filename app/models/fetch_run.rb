class FetchRun < ApplicationRecord
  belongs_to :source
  belongs_to :issue, optional: true

  RETENTION = 30.days

  validates :trigger, inclusion: { in: %w[ scheduled manual test ] }
  validates :status, inclusion: { in: %w[ queued running succeeded failed timed_out ] }

  scope :ordered, -> { order(created_at: :desc) }
  scope :stale,   -> { where(created_at: ...RETENTION.ago) }

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
