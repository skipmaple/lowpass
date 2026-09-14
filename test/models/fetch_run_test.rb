require "test_helper"

class FetchRunTest < ActiveSupport::TestCase
  test "active 是排队与运行中；manual_recent 还带上 60 秒内结束的手动任务" do
    running = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "running", started_at: Time.current)
    done = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "succeeded", started_at: Time.current, item_count: 10)
    old = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "succeeded", started_at: 2.minutes.ago)
    old.update_column(:updated_at, 2.minutes.ago)

    assert_equal [ running ], FetchRun.active.to_a
    assert_equal [ running, done ].sort_by(&:id), FetchRun.manual_recent.to_a.sort_by(&:id)
    assert_not_includes FetchRun.manual_recent, fetch_runs(:hn_ok)
  end

  # 抓取本身就允许 60 秒：还在跑的记录不能因为超过时间窗口掉出去，
  # 不然轮询停了、结束了也没人弹提示
  test "进行中的记录不按时间窗口过期" do
    stuck = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "running", started_at: 5.minutes.ago)
    stuck.update_column(:updated_at, 5.minutes.ago)

    assert_includes FetchRun.manual_recent, stuck
    assert_equal [ stuck.id ], FetchRun.manual_run_props(FetchRun.manual_recent)[:active].map { |run| run[:id] }
  end

  # 第 1 / 3 次失败后面还有一次重试：这时弹「重抓失败…已保留原内容」，紧接着又弹「已更新」
  test "重试还在排队时不把那条失败当结束" do
    sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "failed", started_at: Time.current, error_summary: "boom")
    queued = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 2, status: "queued")

    props = FetchRun.manual_run_props(FetchRun.manual_recent)

    assert_equal [ queued.id ], props[:active].map { |run| run[:id] }
    assert_equal [], props[:finished]
  end

  test "最后一次失败没有重试在排队：这条要弹提示" do
    failed = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 3, status: "failed", started_at: Time.current, error_summary: "boom")

    props = FetchRun.manual_run_props(FetchRun.manual_recent)

    assert_equal [], props[:active]
    assert_equal [ failed.id ], props[:finished].map { |run| run[:id] }
  end

  test "状态与触发方式的中文" do
    assert_equal "成功", fetch_runs(:hn_ok).status_label
    assert_equal "调度", fetch_runs(:hn_ok).trigger_label
    assert_equal "超时", FetchRun.new(status: "timed_out").status_label
    assert_equal "测试", FetchRun.new(trigger: "test").trigger_label
  end
end
