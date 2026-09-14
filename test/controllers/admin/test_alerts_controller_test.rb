require "test_helper"

class Admin::TestAlertsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "R-7.4 发送测试告警：建事件、入队、审计、提示" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      assert_enqueued_with(job: DeliverAlertJob) { post admin_test_alert_path }
      assert_redirected_to admin_settings_path
      assert_equal "已发送测试告警", flash[:notice]
      event = AlertEvent.find_by!(kind: "test")
      assert_equal "由 Drew Lee 触发", event.summary
      assert_equal "alert.test", AuditLog.sole.action
      assert_equal "AlertEvent##{event.id}", AuditLog.sole.target
    end
  end

  test "渠道都没配：不建事件，提示未配置" do
    assert_no_difference("AlertEvent.count") { post admin_test_alert_path }
    assert_redirected_to admin_settings_path
    assert_equal "告警渠道未配置", flash[:alert]
  end

  test "每分钟 5 次" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      5.times { post admin_test_alert_path }
      assert_no_difference("AlertEvent.count") { post admin_test_alert_path }
      assert_equal "操作过于频繁，请稍后再试。", flash[:alert]
    end
  end

  test "成员 403" do
    sign_in_as(users(:guest))
    post admin_test_alert_path
    assert_response :forbidden
  end
end
