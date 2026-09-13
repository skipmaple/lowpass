require "application_system_test_case"

# P2-① 出口：真的在浏览器里走一遍——撞登录墙、点「使用 Google 登录」回到原页、开头像菜单、登出回到登录页
class SigningInTest < ApplicationSystemTestCase
  test "登录回到原页，头像菜单登出" do
    identity = auth_identities(:drew_google)
    mock_omniauth(:google_oauth2, identity_auth(identity))

    visit daily_issue_path("2026-09-08")
    assert_current_path login_path(next: "/daily/2026-09-08")
    assert_text "滤掉噪音，留下信号。"

    click_on "使用 Google 登录"

    assert_current_path daily_issue_path("2026-09-08")
    # 头像按钮只有 aria-label，Capybara 默认不按它找按钮（enable_aria_label 关着）
    find("button[aria-label='账户']").click
    assert_selector "[role='menu']", text: "drew@example.com"
    assert_link "管理", href: "/admin/jobs"

    click_on "登出"

    assert_current_path login_path
    visit daily_issue_path("2026-09-08")
    assert_current_path login_path(next: "/daily/2026-09-08")
  end

  test "取消授权回到登录卡" do
    mock_omniauth(:github, :access_denied)

    visit login_path
    click_on "使用 GitHub 登录"

    assert_current_path login_path
    assert_text "已取消登录。"
  end
end
