# 后台写操作的审计（PRD 5.6、附录 A）：谁、何时、对什么、改了什么。没有界面（查看界面是 P2 优先级），保留 90 天（7.8）
class AuditLog < ApplicationRecord
  RETENTION = 90.days

  belongs_to :user, optional: true

  validates :action, presence: true, length: { maximum: 50 }
  validates :target, presence: true, length: { maximum: 100 }

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
