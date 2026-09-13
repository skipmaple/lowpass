# 按 fixture 里的身份伪造一次 OmniAuth 登录（OmniAuth.config.test_mode，test_helper 打开）：
# POST /auth/<策略> 会被 OmniAuth 直接 302 到回调，回调把 mock 塞进 env["omniauth.auth"] 再交给 sessions#create。
# sign_in_as 停在 create 的那个 302 上，要看落地页自己 follow_redirect!。
module AuthenticationTestHelpers
  STRATEGIES = { "google" => :google_oauth2, "github" => :github }.freeze
  LABELS = { google_oauth2: "使用 Google 登录", github: "使用 GitHub 登录" }.freeze

  def sign_in_as(user, next_path: nil)
    identity = user.auth_identities.first!
    strategy = strategy_for(identity)
    mock_omniauth(strategy, identity_auth(identity))
    post "/auth/#{strategy}", params: { origin: next_path }.compact
    follow_redirect!
  end

  def strategy_for(identity) = STRATEGIES.fetch(identity.provider)

  # mock 的形状照 Identity::Profile 读的字段：Google 看 info.email / email_verified，GitHub 看 extra.all_emails
  def identity_auth(identity, name: identity.user.display_name, image: identity.user.avatar_url)
    emails = identity.email ? [ { "email" => identity.email, "primary" => true, "verified" => identity.email_verified } ] : []
    OmniAuth::AuthHash.new(
      provider: strategy_for(identity).to_s, uid: identity.provider_uid,
      info: { name: name, nickname: name, email: identity.email_verified ? identity.email : nil, email_verified: identity.email_verified, image: image },
      extra: { all_emails: emails }
    )
  end

  # 传 AuthHash 是成功；传符号（:access_denied、:csrf_detected、:invalid_credentials）是 OmniAuth 的失败类型
  def mock_omniauth(strategy, auth_or_symbol)
    OmniAuth.config.mock_auth[strategy.to_sym] = auth_or_symbol
  end
end
