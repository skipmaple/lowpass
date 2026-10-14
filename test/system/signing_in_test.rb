require "application_system_test_case"

# P2-① 出口：真的在浏览器里走一遍——撞登录墙、点「使用 Google 登录」回到原页、开头像菜单、登出回到登录页
class SigningInTest < ApplicationSystemTestCase
  test "登录回到原页，头像菜单登出" do
    identity = auth_identities(:drew_google)
    mock_omniauth(:google_oauth2, identity_auth(identity))

    visit daily_issue_path("2026-09-08")
    assert_current_path login_path(next: "/daily/2026-09-08")
    assert_text "每天一期技术日刊，登录后阅读"
    # 登录页不套站点布局：报头与页脚在这里都没处可去。Inertia 会先拿 props 试调一次 Show.layout，
    # 恒等函数返回的不是元素，就被当成 props 解析器、照样套上默认 Layout——单元测试看不见这一步
    assert_no_selector ".masthead"

    click_on "使用 Google 登录"

    assert_current_path daily_issue_path("2026-09-08")
    # 头像按钮只有 aria-label，Capybara 默认不按它找按钮（enable_aria_label 关着）
    find("button[aria-label='账户']").click
    assert_selector "[role='menu']", text: "drew@example.com"
    assert_link "管理", href: "/admin/sources"

    click_on "登出"

    assert_current_path login_path
    # 登出是 router.delete 发起的 Inertia 访问：从套着 Layout 的页面客户端换到登录页，走的是另一条渲染路径
    assert_no_selector ".masthead"
    visit daily_issue_path("2026-09-08")
    assert_current_path login_path(next: "/daily/2026-09-08")
  end

  # R-5.11、AC-5.8：确认框是挂在 body 上的 Dialog；删成之后从套着 Layout 的设置页换到不套布局的登录页，提示走 notice
  test "设置页注销：确认之后回到登录页" do
    guest = users(:guest)
    sign_in_with_browser(guest)

    visit settings_path
    click_on "注销"
    within("[role='dialog']") do
      assert_text "注销后无法恢复。确认注销这个账号？"
      assert_text "guest@example.com"
      click_on "确认注销"
    end

    assert_selector ".login-card [role='status']", text: "已注销账号。"
    assert_current_path login_path
    assert_no_selector ".masthead"
    assert_not User.exists?(guest.id)
  end

  test "取消授权回到登录卡" do
    mock_omniauth(:github, :access_denied)

    visit login_path
    click_on "使用 GitHub 登录"

    # The native form redirects back to the same URL. Wait for the new document's
    # specific outcome, rather than letting the old /login URL satisfy the wait.
    assert_selector ".login-card [role='alert']", text: "已取消登录。"
    assert_current_path login_path
  end

  # 设计说明 2026-10-14 C1：登录卡在视口里居中，视觉重心略高（上方留白约占 40%）
  test "登录卡在 1440×900 的视口里垂直居中、略偏上" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    visit login_path

    top, height = evaluate_script("(() => { const r = document.querySelector('.login-card').getBoundingClientRect(); return [r.top, r.height] })()")
    share = top / (900 - height)
    assert_in_delta 0.4, share, 0.06
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  # 自查第 1 轮：登录卡最宽 400px，窄屏上要收进视口，不撑出横向滚动
  test "登录页在 320、375 宽不横向溢出" do
    [ 320, 375 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 800, deviceScaleFactor: 1, mobile: false)
      visit login_path
      assert_selector ".login-card"

      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, evaluate_script("document.documentElement.clientWidth"), "#{width}px"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
