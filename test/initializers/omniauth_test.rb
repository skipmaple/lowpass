require "test_helper"

# config/initializers/omniauth.rb 里的请求阶段防护（设计 4.3、R-5.6）。这几条在别的测试里永远走不到：
# OmniAuth.config.test_mode 打开后整个请求阶段被换成「直接 302 到回调」，allowed_request_methods 与
# CSRF 校验一次都不会被调用——把 :get 加回去、或者把 omniauth-rails_csrf_protection 从 Gemfile 里删掉，
# 其余测试照样全绿。所以这里直接盯着配置本身。
class OmniauthTest < ActiveSupport::TestCase
  # 只收 POST：GET /auth/github 能被别人页面上的一个 <img src> 替读者发出去
  test "发起登录只允许 POST" do
    assert_equal [ :post ], OmniAuth.config.allowed_request_methods
  end

  # POST 之外还要带 Rails 的 CSRF 令牌，校验由 omniauth-rails_csrf_protection 挂在这个钩子上
  test "请求阶段校验 Rails 的 CSRF 令牌" do
    assert_kind_of OmniAuth::RailsCsrfProtection::TokenVerifier, OmniAuth.config.request_validation_phase
  end

  # 凭证是占位的，但两条策略都挂上，登录页才画得出两个按钮
  test "test 环境挂 google 与 github 两条策略" do
    assert_equal %w[google_oauth2 github], Rails.configuration.x.auth_providers
  end

  # R-5.9：换 token 就发生在 OmniAuth 的中间件里，限流排在它后面等于没限
  test "回调限流排在 OmniAuth 之前" do
    names = Rails.application.config.middleware.map(&:name)

    assert_includes names, "Auth::CallbackRateLimit"
    assert_includes names, "OmniAuth::Builder"
    assert_operator names.index("Auth::CallbackRateLimit"), :<, names.index("OmniAuth::Builder")
  end
end
