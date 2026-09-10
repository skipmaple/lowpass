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

  test "一步出错不影响其他步" do
    Issue.unstub(:generate_daily!)
    Issue.stubs(:generate_daily!).raises(ActiveRecord::RecordNotUnique, "dup")

    # Create a stale issue on 2026-09-11
    issue = Issue.daily.create!(period_key: "2026-09-11", state: "generating", generation_started_at: sh("2026-09-11 06:00:00"))

    # Subscribe to error reports
    reported_errors = []
    subscriber = Class.new do
      define_method(:initialize) { |errors| @errors = errors }
      define_method(:report) { |error, handled:, severity: nil, context: nil, source: nil|
        @errors << { error:, handled:, context: }
      }
    end.new(reported_errors)
    Rails.error.subscribe(subscriber)

    begin
      # Tick at 2026-09-12 09:30:00 (no issue for that day, so generate_daily! is called and raises)
      # But other steps should still run
      assert_enqueued_with(job: WeeklyCheckJob) { Scheduler.tick(now: sh("2026-09-12 09:30:00")) }

      # Verify the stale issue was finalized despite the error in step 1
      assert_not issue.reload.generating?

      # Verify the error was reported with context
      assert_equal 1, reported_errors.length
      error_info = reported_errors[0]
      assert_instance_of ActiveRecord::RecordNotUnique, error_info[:error]
      assert_equal true, error_info[:handled]
      assert_equal :generate_daily_if_due, error_info[:context][:step]
    ensure
      Rails.error.unsubscribe(subscriber)
    end
  end

  test "迟于设定 1 分钟以内不算延迟" do
    Issue.expects(:generate_daily!).with("2026-09-10", late: false).once
    Scheduler.tick(now: sh("2026-09-10 06:01:00"))
  end

  test "迟于设定超过 1 分钟算延迟" do
    Issue.expects(:generate_daily!).with("2026-09-10", late: true).once
    Scheduler.tick(now: sh("2026-09-10 06:01:01"))
  end

  test "周刊检查标记跨天重置" do
    # First tick on 2026-09-10
    assert_enqueued_with(job: WeeklyCheckJob) { Scheduler.tick(now: sh("2026-09-10 09:00:30")) }
    assert_equal "2026-09-10", Setting.get("weekly_checked_on")

    # Clear the job queue for the next assertion
    clear_enqueued_jobs

    # Next tick on 2026-09-11 should enqueue again
    assert_enqueued_with(job: WeeklyCheckJob) { Scheduler.tick(now: sh("2026-09-11 09:00:30")) }
    assert_equal "2026-09-11", Setting.get("weekly_checked_on")
  end
end
