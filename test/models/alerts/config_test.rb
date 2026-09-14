require "test_helper"

class Alerts::ConfigTest < ActiveSupport::TestCase
  teardown { Alerts::Config.load!({}) }

  test "什么都没配：两渠道都未配置，BASE_URL 用本机默认" do
    Alerts::Config.load!({})
    assert_not Alerts::Config.email?
    assert_not Alerts::Config.webhook?
    assert_not Alerts::Config.configured?
    assert_equal "http://localhost:3000", Alerts::Config.base_url
    assert_equal "localhost", Alerts::Config.host
    assert_equal({ email: { configured: false, label: "未配置" }, webhook: { configured: false, label: "未配置" } }, Alerts::Config.status_props)
  end

  # Kamal 把没配的变量当空串注进容器：空串必须等于没配，不能当成「配了一个空值」
  test "空字符串当没配" do
    Alerts::Config.load!({ "SMTP_PORT" => "", "BASE_URL" => "", "ALERT_EMAIL_TO" => "", "ALERT_WEBHOOK_URL" => "" })

    assert_equal "http://localhost:3000", Alerts::Config.base_url
    assert_empty Alerts::Config.email_to
    assert_not Alerts::Config.email?
    assert_not Alerts::Config.webhook?
    assert_not Alerts::Config.configured?
    assert_empty Alerts::Config.warnings
  end

  test "邮件要 ALERT_EMAIL_TO 与 SMTP_ADDRESS 都有；地址脱敏" do
    Alerts::Config.load!({ "ALERT_EMAIL_TO" => "drew@example.com, ops@example.com", "BASE_URL" => "https://lowpass.example.com" })
    assert_not Alerts::Config.email?
    assert_includes Alerts::Config.warnings, "ALERT_EMAIL_TO 已配但 SMTP_ADDRESS 缺失，邮件渠道视为未配置"

    Alerts::Config.load!({ "ALERT_EMAIL_TO" => "drew@example.com, ops@example.com", "SMTP_ADDRESS" => "smtp.example.com", "BASE_URL" => "https://lowpass.example.com" })
    assert Alerts::Config.email?
    assert_equal [ "drew@example.com", "ops@example.com" ], Alerts::Config.email_to
    assert_equal "lowpass@lowpass.example.com", Alerts::Config.email_from
    assert_equal "d***@example.com · o***@example.com", Alerts::Config.status_props.dig(:email, :label)
  end

  test "webhook 只认 https；格式不认识按 generic" do
    Alerts::Config.load!({ "ALERT_WEBHOOK_URL" => "http://hooks.example/x" })
    assert_not Alerts::Config.webhook?
    assert_includes Alerts::Config.warnings, "ALERT_WEBHOOK_URL 不是 https 地址，webhook 渠道视为未配置"

    Alerts::Config.load!({ "ALERT_WEBHOOK_URL" => "https://open.feishu.cn/hook/abc", "ALERT_WEBHOOK_FORMAT" => "feishu" })
    assert Alerts::Config.webhook?
    assert_equal "feishu", Alerts::Config.webhook_format
    assert_equal "open.feishu.cn · feishu", Alerts::Config.status_props.dig(:webhook, :label)

    Alerts::Config.load!({ "ALERT_WEBHOOK_URL" => "https://hooks.example/x", "ALERT_WEBHOOK_FORMAT" => "telegram" })
    assert_equal "generic", Alerts::Config.webhook_format
    assert_includes Alerts::Config.warnings, "ALERT_WEBHOOK_FORMAT=telegram 不认识（generic / feishu / wecom / dingtalk），按 generic 发"
  end

  test "with_alert_channels 用完还原" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) { assert Alerts::Config.configured? }
    assert_not Alerts::Config.configured?
  end
end
