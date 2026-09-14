require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "设置页：调度时间与白名单" do
    get admin_settings_path

    assert_equal "Admin/Settings/Show", page_component
    assert_equal({ "daily_time" => "06:00", "weekly_time" => "09:00" }, page_props["schedule"])
    assert_equal [ "drew@example.com" ], page_props["whitelist"]
    assert_equal({ "email" => { "configured" => false, "label" => "未配置" }, "webhook" => { "configured" => false, "label" => "未配置" } }, page_props["alerts"])
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

  # 表单少提交一项（或整个 schedule 都没有）是校验错误，不是 400
  test "缺参数按校验错误处理" do
    patch admin_settings_path

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

  test "设置页带推荐理由配置、用量与兴趣画像" do
    get admin_settings_path
    assert_equal false, page_props.dig("reasons", "configured")
    assert_equal [ "AI / LLM", "前端开发", "硬件设计" ], page_props["interest_areas"].map { |a| a["name"] }
    assert_equal false, page_props["interest_areas"].last["enabled"]
  end

  test "改模型配置：地址要 https，数字不小于 0；保存记审计" do
    patch admin_settings_path, params: { model: { base_url: "http://model.example/v1", model_name: "m", input_price: "-1", output_price: "abc", monthly_cap: "10" } }
    assert_redirected_to admin_settings_path
    follow_redirect!
    assert_equal [ "地址必须是 https" ], page_props.dig("errors", "base_url")
    assert_equal [ "不小于 0" ], page_props.dig("errors", "input_price")
    assert_equal [ "不小于 0" ], page_props.dig("errors", "output_price")
    assert_equal "", Setting.get("model_base_url")

    patch admin_settings_path, params: { model: { base_url: "https://model.example/v1", model_name: "gpt-x", input_price: "0.5", output_price: "1.5", monthly_cap: "10" } }
    assert_redirected_to admin_settings_path
    assert_equal "已保存", flash[:notice]
    assert_equal "https://model.example/v1", Setting.get("model_base_url")
    assert_equal "gpt-x", Setting.get("model_name")
    assert_equal "0.5", Setting.get("model_input_price")
    log = AuditLog.last
    assert_equal "Setting#model", log.target
    assert_equal [ "", "gpt-x" ], log.payload["model_name"]
  end

  test "模型配置可以清空（地址与模型名留空 = 未配置）" do
    Setting.set("model_base_url", "https://model.example/v1")
    patch admin_settings_path, params: { model: { base_url: "", model_name: "", input_price: "0", output_price: "0", monthly_cap: "0" } }
    assert_redirected_to admin_settings_path
    assert_equal "", Setting.get("model_base_url")
  end
end
