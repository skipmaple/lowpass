require "middleware/auth/callback_rate_limit"

# 登录只把一件事交给 OmniAuth：从 provider 拿到资料（request.env["omniauth.auth"]）。匹配、合并、会话都在
# SessionsController 与 Identity::Resolution 里。策略只在环境变量齐全时挂载（test 两家都挂、凭证是占位；
# development 再加 developer），登录页据 config.x.auth_providers 决定画哪几个按钮。
google = ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
github = ENV["GITHUB_CLIENT_ID"].present? && ENV["GITHUB_CLIENT_SECRET"].present?
providers = []
providers << "google_oauth2" if google || Rails.env.test?
providers << "github" if github || Rails.env.test?
providers << "developer" if Rails.env.development?
Rails.application.config.x.auth_providers = providers.freeze
# 一个都没有就没人登得进来，而登录页照样渲染得出来（只是按钮那块空着）：至少在日志里喊一声。
# development 有 developer、test 两家都挂，这条只可能在生产响
if providers.empty?
  Rails.logger.warn { "没有配置任何登录 provider（GOOGLE_CLIENT_ID/SECRET、GITHUB_CLIENT_ID/SECRET 都缺），登录页将没有按钮" }
end

OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
# 失败（取消、state 不符、换 token 出错）直接调 sessions#failure，不经 /auth/failure 的重定向，
# 也不在 development 抛异常（OmniAuth 默认 failure_raise_out_environments 含 development）
OmniAuth.config.on_failure = ->(env) { SessionsController.action(:failure).call(env) }

Rails.application.config.middleware.use OmniAuth::Builder do
  if providers.include?("google_oauth2")
    provider :google_oauth2, ENV.fetch("GOOGLE_CLIENT_ID", "test"), ENV.fetch("GOOGLE_CLIENT_SECRET", "test"),
             scope: "openid email profile", prompt: "select_account"
  end
  if providers.include?("github")
    provider :github, ENV.fetch("GITHUB_CLIENT_ID", "test"), ENV.fetch("GITHUB_CLIENT_SECRET", "test"), scope: "user:email"
  end
  provider :developer, fields: [ :name, :email ], uid_field: :email if providers.include?("developer")
end
# 回调限流要在换 token 之前，所以排在 OmniAuth 之前；两者都在会话中间件之后，能写 flash
Rails.application.config.middleware.insert_before OmniAuth::Builder, Auth::CallbackRateLimit
