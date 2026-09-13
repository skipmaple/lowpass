# 读者（PRD 附录 A）。角色不是自己选的：每次登录按白名单推导（R-5.5）。显示名与头像跟着最近一次登录的 provider 走（R-5.2）。
class User < ApplicationRecord
  ROLES = %w[admin member].freeze

  has_many :auth_identities, dependent: :destroy
  has_many :sessions, dependent: :destroy

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :email, length: { maximum: 254 }, allow_nil: true
  validates :avatar_url, length: { maximum: 2048 }, allow_nil: true
  validates :role, inclusion: { in: ROLES }

  def admin? = role == "admin"

  # R-5.5：任一已验证邮箱在白名单中即为 admin，否则 member；白名单改动在下次登录生效（登录时调用）
  def refresh_role!
    verified = auth_identities.where(email_verified: true).pluck(:email)
    update!(role: Identity::Whitelist.include_any?(verified) ? "admin" : "member")
  end
end
