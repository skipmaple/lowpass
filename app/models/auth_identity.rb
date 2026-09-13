# 一个 provider 上的一个账号（PRD 附录 A 的 AuthIdentity）。email_verified 是合并与白名单唯一认的依据（设计 L7）。
class AuthIdentity < ApplicationRecord
  PROVIDERS = %w[google github developer].freeze

  belongs_to :user

  validates :provider, inclusion: { in: PROVIDERS }
  validates :provider_uid, presence: true, length: { maximum: 255 }, uniqueness: { scope: :provider }
  validates :email, length: { maximum: 254 }, allow_nil: true
  validates :linked_at, presence: true
end
