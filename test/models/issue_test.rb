require "test_helper"

class IssueTest < ActiveSupport::TestCase
  test "同刊物同周期键只有一期" do
    dup = Issue.new(kind: "daily", period_key: issues(:daily_0908).period_key, state: "generating", generation_started_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "缺期是推导出来的" do
    assert_nil Issue.daily.find_by(period_key: "2026-09-03")
  end
end
