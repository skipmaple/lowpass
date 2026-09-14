require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup { Rails.cache.clear }

  # OmniAuth.config.mock_auth 是进程级的：不清掉，忘了 mock_omniauth 的测试会拿上一条测试的身份登录成功
  teardown { OmniAuth.config.mock_auth.clear }

  # 真的在浏览器里点登录按钮：OmniAuth 的 mock 让 POST /auth/<策略> 直接回到回调
  def sign_in_with_browser(user)
    identity = user.auth_identities.first!
    strategy = strategy_for(identity)
    mock_omniauth(strategy, identity_auth(identity))
    visit login_path
    click_on AuthenticationTestHelpers::LABELS.fetch(strategy)
    # click_on 提交的是原生表单，落地前要走一串重定向；不等它落地就把控制权交还调用方，
    # 调用方紧接着的 visit 有时会跟这串重定向赛跑抢先跳走，看起来像是没登录成功
    assert_no_current_path login_path
  end
end
