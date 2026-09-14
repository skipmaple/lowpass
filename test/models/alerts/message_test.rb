require "test_helper"

class Alerts::MessageTest < ActiveSupport::TestCase
  test "告警正文：事件名、来源、期、摘要、链接（R-7.2）" do
    with_alert_channels(BASE_URL: "https://lowpass.example.com/") do
      event = alert_event
      assert_equal "[lowpass] 警告 · 源抓取失败 · Hacker News", Alerts::Message.subject(event, "alert")
      assert_equal <<~TEXT.chomp, Alerts::Message.text(event, "alert")
        [lowpass] 警告 · 源抓取失败
        来源：Hacker News
        期：2026-09-08
        摘要：连接超时
        https://lowpass.example.com/admin/sources/#{sources(:hn).id}/runs
      TEXT
    end
  end

  test "恢复正文不带摘要；没有来源与期的事件只有两行" do
    with_alert_channels(BASE_URL: "https://lowpass.example.com") do
      event = alert_event
      assert_equal "[lowpass] 已恢复 · 源抓取失败\n来源：Hacker News\n期：2026-09-08\nhttps://lowpass.example.com/admin/sources/#{sources(:hn).id}/runs", Alerts::Message.text(event, "recovery")

      test_event = alert_event(kind: "test", level: "info", source: nil, issue: nil, summary: "由 Drew Lee 触发", url_path: "/admin/settings", dedup_key: "test:1")
      assert_equal "[lowpass] 提示 · 测试告警\n摘要：由 Drew Lee 触发\nhttps://lowpass.example.com/admin/settings", Alerts::Message.text(test_event, "alert")
      assert_equal "[lowpass] 提示 · 测试告警", Alerts::Message.subject(test_event, "alert")
    end
  end
end
