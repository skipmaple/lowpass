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

  # test 环境默认关掉 CSRF 校验（config/environments/test.rb 的 allow_forgery_protection = false）：
  # 块里把它打开，fetch 带的 X-CSRF-Token 才真的被校验，令牌读错了就是 422
  def with_forgery_protection
    was = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = was
  end

  # fetch 发出去的请求 Capybara 不会替你等：轮询到条件成立为止，5 秒不成立就算失败
  def wait_until
    Timeout.timeout(5) { sleep 0.1 until yield }
  end

  # 浏览器里发往 /favorites 的 fetch 有几个（书签的请求；Inertia 自己的访问走 XHR，不算）
  FAVORITE_FETCHES = "performance.getEntriesByType('resource').filter((entry) => entry.initiatorType === 'fetch' && new URL(entry.name).pathname.startsWith('/favorites')).length".freeze

  # 书签的请求回来之后，前端还要把最新的列表写回当前页（lib/favorites.tsx）；换页的访问还在路上时，
  # 这一步按设计跳过、不补。紧接着要离开这一页的测试先等这几个请求都有了结果，再让出一轮事件循环，
  # 让请求的回调跑完；光等数据库不够，库里有了，浏览器那头的回调可能还没跑
  def wait_for_favorite_requests(count)
    wait_until { evaluate_script(FAVORITE_FETCHES) >= count }
    evaluate_async_script("setTimeout(arguments[0], 0)")
  end
end
