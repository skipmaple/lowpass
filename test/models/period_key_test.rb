require "test_helper"

class PeriodKeyTest < ActiveSupport::TestCase
  test "日刊按上海时区的自然日" do
    assert_equal "2026-09-08", PeriodKey.daily(Time.utc(2026, 9, 8, 15, 59))   # 上海 23:59
    assert_equal "2026-09-09", PeriodKey.daily(Time.utc(2026, 9, 8, 16, 0))    # 上海 00:00
  end

  test "服务器时区不是上海也不影响" do
    Time.use_zone("America/New_York") do
      assert_equal "2026-09-09", PeriodKey.daily(Time.utc(2026, 9, 8, 16, 0))
    end
  end

  test "周刊按 ISO 周，周一起" do
    assert_equal "2026-W36", PeriodKey.weekly(Time.utc(2026, 8, 30, 20, 0))   # 上海 8月31日 周一 04:00
    assert_equal "2026-W35", PeriodKey.weekly(Time.utc(2026, 8, 30, 15, 0))   # 上海 8月30日 周日 23:00
  end

  test "周范围与日期反解" do
    assert_equal Date.new(2026, 8, 31)..Date.new(2026, 9, 6), PeriodKey.week_range("2026-W36")
    assert_equal Date.new(2026, 9, 8), PeriodKey.date_of("2026-09-08")
  end
end
