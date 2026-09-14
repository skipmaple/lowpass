require "test_helper"

class AlertsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def sh(str) = Time.find_zone("Asia/Shanghai").parse(str)

  setup { Rails.cache.clear }

  test "R-7.1 同源同日同类只发一次，次日再发；不同 kind、不同源互不影响" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      travel_to sh("2026-09-14 08:00") do
        assert_difference("AlertEvent.count", 1) do
          event = Alerts.source_failed!(sources(:hn), issues(:daily_0908), "down\nsecond line")
          assert_equal "down", event.summary
          assert_equal "source_failed:#{sources(:hn).id}:2026-09-14", event.dedup_key
          assert_equal "/admin/sources/#{sources(:hn).id}/runs", event.url_path
          assert_nil Alerts.source_failed!(sources(:hn), issues(:daily_0908), "again")
        end
        assert_enqueued_with(job: DeliverAlertJob, args: [ AlertEvent.last, "alert" ])
        assert_difference("AlertEvent.count", 2) do
          Alerts.parse_degraded!(sources(:hn), issues(:daily_0908), "丢弃 3 / 5 条")
          Alerts.source_failed!(sources(:github), issues(:daily_0908), "down")
        end
      end
      travel_to sh("2026-09-15 00:30") do
        assert_difference("AlertEvent.count", 1) { Alerts.source_failed!(sources(:hn), issues(:daily_0908), "down") }
      end
    end
  end

  test "期级与全局事件的范围；测试告警不去重" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      travel_to sh("2026-09-14 08:00") do
        empty = Alerts.issue_empty!(issues(:daily_0908))
        assert_equal "issue_empty:2026-09-08:2026-09-14", empty.dedup_key
        assert_equal "critical", empty.level
        assert_equal "/admin/issues?month=2026-09", empty.url_path
        late = Alerts.issue_late!(issues(:daily_0908), 65)
        assert_equal "晚于生成时间 65 分钟", late.summary
        search = Alerts.search_unavailable!("搜索超时，连续 3 次")
        assert_equal "search_unavailable:-:2026-09-14", search.dedup_key
        assert_equal "/search", search.url_path
        assert_equal "/admin/issues?kind=weekly", Alerts.reasons_missing!(issues(:weekly_w36), 3).url_path
        assert_difference("AlertEvent.count", 2) { 2.times { Alerts.test!(users(:drew)) } }
        assert_equal "info", AlertEvent.where(kind: "test").first.level
      end
    end
  end

  test "没配渠道：照样记录，不入队，delivery_error 说明原因" do
    assert_no_enqueued_jobs do
      event = Alerts.source_failed!(sources(:hn), issues(:daily_0908), "down")
      assert_equal "未配置渠道", event.delivery_error
    end
  end

  test "recover! 只关未恢复的，各发一条恢复；再恢复一次什么都不做" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      open = alert_event
      alert_event(dedup_key: "k2", source: sources(:github))
      recovered_at = 1.hour.ago
      done = alert_event(dedup_key: "k3", recovered_at: recovered_at)

      assert_enqueued_with(job: DeliverAlertJob, args: [ open, "recovery" ]) { Alerts.recover!(kind: "source_failed", source: sources(:hn)) }
      assert_not_nil open.reload.recovered_at
      assert_nil AlertEvent.find_by!(dedup_key: "k2").recovered_at
      assert_equal recovered_at.to_i, done.reload.recovered_at.to_i
      assert_no_enqueued_jobs { Alerts.recover!(kind: "source_failed", source: sources(:hn)) }
    end
  end

  test "搜索连续三次失败告警一次，成功后恢复" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      assert_no_difference("AlertEvent.count") { 2.times { Alerts.search_status("timeout") } }
      assert_difference("AlertEvent.count", 1) { 2.times { Alerts.search_status("error") } }
      event = AlertEvent.find_by!(kind: "search_unavailable")
      assert_equal "搜索出错，连续 3 次", event.summary
      Alerts.search_status("ok")
      assert_not_nil event.reload.recovered_at
      assert_no_difference("AlertEvent.count") { Alerts.search_status("timeout") }   # 计数已清零
    end
  end

  test "门面从不让调用方失败（B10）" do
    AlertEvent.stubs(:new).raises(RuntimeError, "db down")
    assert_nil Alerts.source_failed!(sources(:hn), issues(:daily_0908), "down")
  end
end
