module Identity
  # 只是给已有 developer 策略预填账号；不建用户、不改角色，权限仍由登录时的白名单推导。
  module DevelopmentAccounts
    READER_EMAIL = "reader@lowpass.test"

    def self.call
      return [] unless Rails.env.development?

      whitelist = Whitelist.emails
      admin_email = ENV["DEV_LOGIN_ADMIN_EMAIL"].to_s.strip.downcase.presence || whitelist.first
      accounts = []
      if whitelist.include?(admin_email)
        accounts << account("admin", admin_email, "开发管理员")
      end

      reader = owner(READER_EMAIL)
      reader_emails = [ READER_EMAIL, *reader&.auth_identities&.where(email_verified: true)&.pluck(:email) ]
      unless Whitelist.include_any?(reader_emails)
        accounts << { role: "reader", name: reader&.display_name || "普通读者", email: READER_EMAIL }
      end
      accounts
    end

    def self.account(role, email, default_name)
      { role: role, name: owner(email)&.display_name || default_name, email: email }
    end

    # 跟 Resolution 的身份查找顺序一致，不能用 users.email 认领未验证的邮箱。
    def self.owner(email)
      identity = AuthIdentity.find_by(provider: "developer", provider_uid: email) ||
        AuthIdentity.find_by(email: email, email_verified: true)
      identity&.user
    end

    private_class_method :account, :owner
  end
end
