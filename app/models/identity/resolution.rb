module Identity
  # R-5.1 到 R-5.5：拿着 provider 资料找人、合并或新建，并刷新角色。四种结果交给控制器决定跳哪里：
  # signed_in（再次登录）、linked（已验证邮箱一致，并进现有用户）、created（已验证邮箱但没人有）、
  # unmergeable（邮箱未验证或缺失，新建独立用户并提示）。
  class Resolution
    Result = Data.define(:user, :outcome)

    def self.call(auth) = new(Profile.from(auth)).call

    def initialize(profile)
      @profile = profile
    end

    def call
      AuthIdentity.transaction do
        user, outcome = locate
        user.update!(display_name: @profile.display_name, avatar_url: @profile.avatar_url, email: @profile.email, last_login_at: Time.current)
        user.refresh_role!
        Result.new(user: user, outcome: outcome)
      end
    end

    private
      def locate
        if identity = AuthIdentity.find_by(provider: @profile.provider, provider_uid: @profile.uid)
          identity.update!(email: @profile.email, email_verified: @profile.email_verified?)
          [ identity.user, :signed_in ]
        elsif @profile.email_verified? && (owner = verified_owner)
          [ link!(owner), :linked ]
        else
          user = User.create!(display_name: @profile.display_name)
          [ link!(user), @profile.email_verified? ? :created : :unmergeable ]
        end
      end

      # 只跟已验证的身份邮箱比，不跟 users.email 比（设计 L7）：不然有人先用未验证的 a@x 建一个账号，
      # 真正的 a@x 之后用 Google 登录就被并进去了
      def verified_owner
        AuthIdentity.find_by(email: @profile.email, email_verified: true)&.user
      end

      def link!(user)
        user.auth_identities.create!(provider: @profile.provider, provider_uid: @profile.uid, email: @profile.email,
                                     email_verified: @profile.email_verified?, linked_at: Time.current)
        user
      end
  end
end
