module Identity
  # 从 OmniAuth 的 auth hash 里取登录要用的那几样：provider（PRD 用语）、uid、显示名、头像、邮箱与是否已验证。
  # 三家 provider 的字段位置不同，差异只在这里；下游（Resolution、设置页）只认这一个形状。
  class Profile
    STRATEGIES = { "google_oauth2" => "google", "github" => "github", "developer" => "developer" }.freeze
    # 列长度（7.2）就是这里的上限：provider 给的资料再离谱，也只该少存一点，不该让 Resolution 的 update! 抛异常
    DISPLAY_NAME_LIMIT = 100
    EMAIL_LIMIT = 254
    AVATAR_URL_LIMIT = 2048

    attr_reader :provider, :uid, :display_name, :avatar_url, :email, :email_verified
    alias email_verified? email_verified

    def self.from(auth)
      strategy = auth["provider"].to_s
      provider = STRATEGIES.fetch(strategy) { raise ArgumentError, "unknown OmniAuth strategy: #{strategy}" }
      info = auth["info"] || {}
      email, verified = public_send(:"#{provider}_email", auth)
      new(provider: provider, uid: auth["uid"].to_s, display_name: display_name_for(info, email),
          avatar_url: info["image"].presence, email: email, email_verified: verified)
    end

    # Google：策略给的 info.email 本身只在已验证时才有值（未验证的在 info.unverified_email），email_verified 是原始布尔
    def self.google_email(auth)
      info = auth["info"] || {}
      email = normalize(info["email"])
      [ email, email.present? && info["email_verified"] == true ]
    end

    # R-5.4：只认 /user/emails 里 primary 且 verified 的那条；info.email 与公开资料里的 email 不算数
    def self.github_email(auth)
      emails = Array(auth.dig("extra", "all_emails"))
      primary = emails.find { |entry| entry["primary"] && entry["verified"] }
      primary ? [ normalize(primary["email"]), true ] : [ nil, false ]
    end

    # 只在 development 挂（设计 L8）：填什么邮箱算什么，视为已验证，用来试白名单与合并
    def self.developer_email(auth)
      email = normalize(auth.dig("info", "email"))
      [ email, email.present? ]
    end

    def self.display_name_for(info, email)
      info["name"].presence || info["nickname"].presence || email&.split("@")&.first.presence || "读者"
    end

    def self.normalize(email)
      email.to_s.strip.downcase.presence
    end

    def initialize(provider:, uid:, display_name:, avatar_url:, email:, email_verified:)
      @provider = provider
      @uid = uid
      @display_name = display_name.to_s[0, DISPLAY_NAME_LIMIT]
      # 名字截一截还是那个人；邮箱与头像地址截了就不是原来那个，超长一律当没有。
      # 邮箱没了，合并也就无从谈起（R-5.3），已验证跟着落空
      @avatar_url = avatar_url.to_s.length > AVATAR_URL_LIMIT ? nil : avatar_url
      @email = email.to_s.length > EMAIL_LIMIT ? nil : email
      @email_verified = email_verified && @email.present?
      freeze
    end
  end
end
