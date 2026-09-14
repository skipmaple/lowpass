require "test_helper"

# R-5.10 设置页：显示名、头像、邮箱、已绑定方式与时间、角色、本次会话
class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "管理员的设置页" do
    sign_in_as(users(:drew))

    get settings_path

    assert_response :success
    assert_equal "Settings/Show", page_component
    assert_equal({ "display_name" => "Drew Lee", "email" => "drew@example.com", "avatar_url" => "https://avatars.example/drew.png", "role" => "admin" }, page_props["user"])
    assert_equal [
      { "provider" => "google", "strategy" => "google_oauth2", "linked_at_label" => "2026-09-08 14:02" },
      { "provider" => "github", "strategy" => "github", "linked_at_label" => nil }
    ], page_props["identities"]
    session = page_props["session"]
    assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, session["logged_in_label"])
    assert_equal 90.days.from_now.in_time_zone(PeriodKey::ZONE).strftime("%Y-%m-%d"), session["expires_label"]
    assert_equal "06:00", page_props["daily_time"]
  end

  test "没有邮箱的成员" do
    sign_in_as(users(:nomail))

    get settings_path

    assert_nil page_props.dig("user", "email")
    assert_equal "member", page_props.dig("user", "role")
    assert_equal [ nil, "2026-09-08 16:00" ], page_props["identities"].map { |i| i["linked_at_label"] }
  end

  test "未登录跳登录页" do
    get settings_path

    assert_redirected_to login_path(next: "/settings")
  end
end
