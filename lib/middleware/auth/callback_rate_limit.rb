# R-5.9 登录回调按 IP 每分钟 10 次。放在 OmniAuth 之前（config/initializers/omniauth.rb）：回调阶段在 OmniAuth 的中间件里
# 就把 code 换成了 token，控制器上的 rate_limit 拦不住那一步。计数方式与 Rails 8 的 rate_limit 一样
# （cache.increment + expires_in）；超限写一句 flash 回登录页，不进 OmniAuth。
module Auth
  class CallbackRateLimit
    LIMIT = 10
    WITHIN = 1.minute
    CALLBACK = %r{\A/auth/[^/]+/callback\z}
    NOTICE = "操作过于频繁，请稍后再试。".freeze # 附录 B，与搜索限流同一句

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return @app.call(env) unless request.path.match?(CALLBACK)

      count = Rails.cache.increment("rate-limit:auth-callback:#{request.remote_ip}", 1, expires_in: WITHIN)
      return @app.call(env) unless count && count > LIMIT

      request.flash[:alert] = NOTICE
      request.commit_flash
      [ 302, { "location" => "/login", "content-type" => "text/html; charset=utf-8" }, [] ]
    end
  end
end
