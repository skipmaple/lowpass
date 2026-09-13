require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "设置页：调度时间与白名单" do
    get admin_settings_path

    assert_equal "Admin/Settings/Show", page_component
    assert_equal({ "daily_time" => "06:00", "weekly_time" => "09:00" }, page_props["schedule"])
    assert_equal [ "drew@example.com" ], page_props["whitelist"]
  end

  test "改调度时间，审计记旧值新值" do
    patch admin_settings_path, params: { schedule: { daily_time: "06:30", weekly_time: "09:00" } }

    assert_redirected_to admin_settings_path
    assert_equal "已保存", flash[:notice]
    assert_equal "06:30", Setting.get("daily_time")
    log = AuditLog.sole
    assert_equal "settings.update", log.action
    assert_equal({ "daily_time" => [ "06:00", "06:30" ] }, log.payload)
  end

  test "格式不对回到设置页，错误按字段" do
    patch admin_settings_path, params: { schedule: { daily_time: "6:00", weekly_time: "25:00" } }

    assert_redirected_to admin_settings_path
    follow_redirect!
    assert_equal [ "格式是 HH:MM" ], page_props.dig("errors", "daily_time")
    assert_equal [ "格式是 HH:MM" ], page_props.dig("errors", "weekly_time")
    assert_equal "06:00", Setting.get("daily_time")
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    get admin_settings_path
    assert_response :forbidden
  end
end
