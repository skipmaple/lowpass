# 服务端会话（R-5.6、D11）：cookie 里只有签名过的 token。有效 = 没过 90 天硬上限，且 30 天内来过。
class Session < ApplicationRecord
  IDLE = 30.days
  MAX = 90.days
  TOUCH_EVERY = 1.hour

  belongs_to :user
  has_secure_token :token

  before_create do
    self.last_seen_at ||= Time.current
    self.expires_at ||= last_seen_at + MAX
  end

  scope :active, -> { where(expires_at: Time.current..).where(last_seen_at: IDLE.ago..) }
  scope :stale, -> { where(expires_at: ...Time.current).or(where(last_seen_at: ...IDLE.ago)) }

  # 每次访问续期（R-5.6），但一小时内只写一次库
  def touch_last_seen!
    update_column(:last_seen_at, Time.current) if last_seen_at < TOUCH_EVERY.ago
  end

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
