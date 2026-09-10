require "test_helper"

class IssueTest < ActiveSupport::TestCase
  test "同刊物同周期键只有一期" do
    dup = Issue.new(kind: "daily", period_key: issues(:daily_0908).period_key, state: "generating", generation_started_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end
end
