require "test_helper"

class SchedulerTest < ActiveSupport::TestCase
  setup { Issue.stubs(:generate_daily!).returns(Issue.new) }

  def sh(str) = Time.find_zone("Asia/Shanghai").parse(str)

  test "AC-1.1 到点生成当日期" do
    Issue.expects(:generate_daily!).with("2026-09-10", late: false).once
    Scheduler.tick(now: sh("2026-09-10 06:00:30"))
  end

  test "未到点不生成" do
    Issue.expects(:generate_daily!).never
    Scheduler.tick(now: sh("2026-09-10 05:59:00"))
  end

  test "AC-1.7 错过调度后补跑并标记延迟" do
    Issue.expects(:generate_daily!).with("2026-09-10", late: true).once
    Scheduler.tick(now: sh("2026-09-10 07:05:00"))
  end

  test "当日已有期就不再生成" do
    Issue.unstub(:generate_daily!)
    assert_no_difference("Issue.count") { Scheduler.tick(now: sh("2026-09-08 07:00:00")) }
  end

  test "生成中超过 20 分钟的期被收尾" do
    Issue.unstub(:generate_daily!)
    issue = Issue.daily.create!(period_key: "2026-09-10", state: "generating", generation_started_at: sh("2026-09-10 06:00:00"))
    Scheduler.tick(now: sh("2026-09-10 06:21:00"))
    assert_not issue.reload.generating?
  end

  test "到周刊检查时间当天只入队一次" do
    assert_enqueued_with(job: WeeklyCheckJob) { Scheduler.tick(now: sh("2026-09-10 09:00:30")) }
    assert_equal "2026-09-10", Setting.get("weekly_checked_on")

    assert_no_enqueued_jobs(only: WeeklyCheckJob) { Scheduler.tick(now: sh("2026-09-10 09:01:30")) }
  end

  test "未到周刊时间不检查" do
    assert_no_enqueued_jobs(only: WeeklyCheckJob) { Scheduler.tick(now: sh("2026-09-10 08:59:00")) }
  end

  test "04:02 清理抓取记录" do
    FetchRun.expects(:cleanup).once
    Scheduler.tick(now: sh("2026-09-10 04:02:10"))
  end

  test "其余时间不清理抓取记录" do
    FetchRun.expects(:cleanup).never
    Scheduler.tick(now: sh("2026-09-10 04:03:00"))
  end
end
