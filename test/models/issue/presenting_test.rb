require "test_helper"

class Issue::PresentingTest < ActiveSupport::TestCase
  # 上海 9月9日 05:00（还没到 06:00 的生成时间）与 07:00（过了）
  BEFORE_DAILY_TIME = Time.utc(2026, 9, 8, 21, 0)
  AFTER_DAILY_TIME = Time.utc(2026, 9, 8, 23, 0)

  def publish!(period_key)
    Issue.create!(kind: "daily", period_key: period_key, state: "published",
                  generation_started_at: Time.utc(2026, 9, 8, 22, 0), published_at: Time.utc(2026, 9, 8, 22, 12))
  end

  # 5.1 边界：00:00 到 06:00 访问首页看到的是昨日那一期，期头要说清楚今天几点出
  test "生成时间之前且今天还没有期时，昨日那一期是 is_yesterday" do
    props = Issue.daily_props_for("2026-09-08", now: BEFORE_DAILY_TIME)

    assert props[:is_yesterday]
    assert_equal "昨日日刊，今日将于 06:00 生成", props[:status]
  end

  test "过了生成时间就不再是昨日那一期" do
    props = Issue.daily_props_for("2026-09-08", now: AFTER_DAILY_TIME)

    assert_not props[:is_yesterday]
    assert_nil props[:status]
  end

  test "今天已经出了期，昨日那一期就不再标 is_yesterday" do
    publish!("2026-09-09")

    props = Issue.daily_props_for("2026-09-08", now: BEFORE_DAILY_TIME)

    assert_not props[:is_yesterday]
  end

  test "前一期与后一期取相邻的日刊周期键，最新一期没有后一期" do
    publish!("2026-09-09")

    older = Issue.daily_props_for("2026-09-08", now: AFTER_DAILY_TIME)
    newer = Issue.daily_props_for("2026-09-09", now: AFTER_DAILY_TIME)

    assert_nil older[:prev_key]
    assert_equal "2026-09-09", older[:next_key]
    assert_equal "2026-09-08", newer[:prev_key]
    assert_nil newer[:next_key]
  end

  # 控制器已经查过这一期就传进来；显式的 nil 是「确实没有这一期」，不再回库查一遍
  test "传进来的期优先于按周期键查库" do
    props = Issue.daily_props_for("2026-09-08", issue: nil, now: AFTER_DAILY_TIME)

    assert_nil props[:state]
    assert_equal "本期未生成", props[:status]
    assert_equal "9月8日", props[:date_label]
  end
end
