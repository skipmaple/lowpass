# 读者（PRD 附录 A）。角色不是自己选的：每次登录按白名单推导（R-5.5）。显示名与头像跟着最近一次登录的 provider 走（R-5.2）。
class User < ApplicationRecord
  ROLES = %w[admin member].freeze
  PROVIDER_LABELS = { "google" => "Google", "github" => "GitHub", "developer" => "开发登录" }.freeze

  has_many :auth_identities, dependent: :destroy
  has_many :sessions, dependent: :destroy

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :email, length: { maximum: 254 }, allow_nil: true
  validates :avatar_url, length: { maximum: 2048 }, allow_nil: true
  validates :role, inclusion: { in: ROLES }

  # 后台用户列表（5.6，只读）。PostgreSQL 的 DESC 默认 NULLS FIRST：不显式要求 NULLS LAST，
  # 从没登录过的人（last_login_at 是 NULL）会排到登录过的人前面
  def self.admin_rows
    includes(:auth_identities).order(Arel.sql("last_login_at DESC NULLS LAST"), created_at: :desc).map do |user|
      {
        id: user.id, display_name: user.display_name, email: user.email, role: user.role,
        providers_label: user.auth_identities.map { |identity| PROVIDER_LABELS.fetch(identity.provider) }.uniq.sort.join(" · "),
        last_login_label: user.last_login_at&.in_time_zone(PeriodKey::ZONE)&.strftime("%Y-%m-%d %H:%M")
      }
    end
  end

  def admin? = role == "admin"

  # R-5.5：任一已验证邮箱在白名单中即为 admin，否则 member；白名单改动在下次登录生效（登录时调用）
  def refresh_role!
    verified = auth_identities.where(email_verified: true).pluck(:email)
    update!(role: Identity::Whitelist.include_any?(verified) ? "admin" : "member")
  end
end
