require "test_helper"

class FetchRunTest < ActiveSupport::TestCase
  test "active 是排队与运行中；manual_recent 是 60 秒内更新过的手动任务" do
    running = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "running", started_at: Time.current)
    done = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "succeeded", started_at: Time.current, item_count: 10)
    old = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "succeeded", started_at: 2.minutes.ago)
    old.update_column(:updated_at, 2.minutes.ago)

    assert_equal [ running ], FetchRun.active.to_a
    assert_equal [ running, done ].sort_by(&:id), FetchRun.manual_recent.to_a.sort_by(&:id)
    assert_not_includes FetchRun.manual_recent, fetch_runs(:hn_ok)
  end

  test "状态与触发方式的中文" do
    assert_equal "成功", fetch_runs(:hn_ok).status_label
    assert_equal "调度", fetch_runs(:hn_ok).trigger_label
    assert_equal "超时", FetchRun.new(status: "timed_out").status_label
    assert_equal "测试", FetchRun.new(trigger: "test").trigger_label
  end
end
