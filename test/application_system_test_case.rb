require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup { Rails.cache.clear }

  # 真的在浏览器里点登录按钮：OmniAuth 的 mock 让 POST /auth/<策略> 直接回到回调
  def sign_in_with_browser(user)
    identity = user.auth_identities.first!
    strategy = strategy_for(identity)
    mock_omniauth(strategy, identity_auth(identity))
    visit login_path
    click_on AuthenticationTestHelpers::LABELS.fetch(strategy)
  end
end
