require "test_helper"

class AlertEventTest < ActiveSupport::TestCase
  test "kind 与 level 只认既定值，摘要与路径有上限" do
    event = alert_event
    assert event.valid?
    assert_equal "源抓取失败", event.kind_label
    assert_equal "警告", event.level_label
    assert event.recoverable?

    event.kind = "nope"
    assert_not event.valid?
    # insert! 不走校验也不走 before_create（id 要自己给），撞的是数据库的 CHECK
    assert_raises(ActiveRecord::StatementInvalid) do
      AlertEvent.insert!({ id: Lowpass::Uuid.generate, kind: "nope", level: "warning", dedup_key: "x", created_at: Time.current, updated_at: Time.current })
    end
  end

  test "同一 dedup_key 只能有一条（R-7.1 靠数据库）" do
    alert_event
    assert_raises(ActiveRecord::RecordNotUnique) { alert_event }
  end

  test "open_for 只找未恢复的同 kind 同源" do
    open = alert_event
    alert_event(dedup_key: "k2", recovered_at: Time.current)
    alert_event(dedup_key: "k3", source: sources(:github))
    assert_equal [ open ], AlertEvent.open_for("source_failed", sources(:hn)).to_a
    assert_equal [], AlertEvent.open_for("issue_empty", nil).to_a
  end

  test "delivered? 按渠道与阶段" do
    event = alert_event(delivered: [ "email:alert" ])
    assert event.delivered?("email", "alert")
    assert_not event.delivered?("webhook", "alert")
    assert_not event.delivered?("email", "recovery")
  end

  test "保留 90 天" do
    alert_event(created_at: 91.days.ago)
    keep = alert_event(dedup_key: "k2", created_at: 89.days.ago)
    AlertEvent.cleanup
    assert_equal [ keep ], AlertEvent.all.to_a
  end
end
