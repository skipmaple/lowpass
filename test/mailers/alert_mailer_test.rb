require "test_helper"

class AlertMailerTest < ActionMailer::TestCase
  test "主题是首行加来源，正文是纯文本" do
    with_alert_channels(ALERT_EMAIL_TO: "drew@example.com", ALERT_EMAIL_FROM: "alerts@lowpass.example.com", SMTP_ADDRESS: "smtp.example.com", BASE_URL: "https://lowpass.example.com") do
      mail = AlertMailer.event(alert_event, "alert")
      assert_equal "[lowpass] 警告 · 源抓取失败 · Hacker News", mail.subject
      assert_equal [ "drew@example.com" ], mail.to
      assert_equal [ "alerts@lowpass.example.com" ], mail.from
      assert_equal "text/plain", mail.mime_type
      assert_includes mail.body.encoded, "摘要：连接超时"
    end
  end
end
