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
    # 5.7：告警要读生成出来的期（issue.kind / period_key）并把它挂到 AlertEvent 上，mock 得给一个
    # 能用的 Issue。不能先 Issue.create! 好再让 mock 返回它：generate_daily_if_due 自己会先查
    # Issue.daily.exists?(period_key: key)，那条记录一旦提前存在，这一步就直接短路、mock 永远
    # 不会被调用。这里给未存盘的 Issue.new 补上 NOT NULL 的 generation_started_at，让它在
    # AlertEvent 的 belongs_to 自动保存里（这时 exists? 早就查过了）能存得进去
    Issue.expects(:generate_daily!).with("2026-09-10", late: true).once
      .returns(Issue.new(kind: "daily", period_key: "2026-09-10", generation_started_at: Time.current))
    Scheduler.tick(now: sh("2026-09-10 07:05:00"))
    assert_equal "晚于生成时间 65 分钟", AlertEvent.find_by!(kind: "issue_late").summary
  end

  # 晚一两分钟是重启之类的正常抖动，不是 5.7 说的「事故」：这里要看真实生成的期，
  # 不能用 setup 里那个只返回空 Issue 的 stub
  test "晚一两分钟的补跑只标延迟，不告警" do
    Issue.unstub(:generate_daily!)
    Scheduler.tick(now: sh("2026-09-10 06:05:00"))
    assert Issue.daily.find_by!(period_key: "2026-09-10").generated_late
    assert_nil AlertEvent.find_by(kind: "issue_late")
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

  test "过了 04:00 清理一次抓取记录、搜索日志与点击" do
    alert_event(created_at: 91.days.ago)
    ModelCall.create!(status: "ok", created_at: 91.days.ago)
    FetchRun.expects(:cleanup).once
    Search::Log.expects(:cleanup).once
    Search::Click.expects(:cleanup).once
    Session.expects(:cleanup).once
    AuditLog.expects(:cleanup).once
    Scheduler.tick(now: sh("2026-09-10 04:02:10"))
    assert_equal "2026-09-10", Setting.get("cleaned_on")
    assert_equal 0, AlertEvent.count
    assert_equal 0, ModelCall.count
  end

  test "未到 04:00 不清理" do
    FetchRun.expects(:cleanup).never
    Search::Log.expects(:cleanup).never
    Search::Click.expects(:cleanup).never
    Session.expects(:cleanup).never
    AuditLog.expects(:cleanup).never
    Scheduler.tick(now: sh("2026-09-10 03:59:00"))
  end

  test "当天已经清过就不再清" do
    Scheduler.tick(now: sh("2026-09-10 04:02:10"))

    FetchRun.expects(:cleanup).never
    Search::Log.expects(:cleanup).never
    Search::Click.expects(:cleanup).never
    Session.expects(:cleanup).never
    AuditLog.expects(:cleanup).never
    Scheduler.tick(now: sh("2026-09-10 09:30:00"))
  end

  # 04:02 那一分钟的 tick 错过了（服务停过、机器睡过）也要补上，不能整天不清
  test "错过清理那一分钟后照样补跑" do
    FetchRun.expects(:cleanup).once
    Scheduler.tick(now: sh("2026-09-10 07:05:00"))
    assert_equal "2026-09-10", Setting.get("cleaned_on")
  end

  test "清理标记跨天重置" do
    Scheduler.tick(now: sh("2026-09-10 04:02:10"))

    FetchRun.expects(:cleanup).once
    Scheduler.tick(now: sh("2026-09-11 04:02:10"))
    assert_equal "2026-09-11", Setting.get("cleaned_on")
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

  test "5.7 发布 30 分钟后仍缺理由：告警一次；未到 30 分钟或没配供应商不告" do
    issue = issues(:daily_0908)
    issue.update!(published_at: sh("2026-09-08 06:12"))
    with_model_provider do
      Scheduler.tick(now: sh("2026-09-08 06:40"))
      assert_nil AlertEvent.find_by(kind: "reasons_missing")

      Scheduler.tick(now: sh("2026-09-08 06:43"))
      event = AlertEvent.find_by!(kind: "reasons_missing")
      assert_equal "理由缺失 1 条", event.summary
      assert_no_difference("AlertEvent.count") { Scheduler.tick(now: sh("2026-09-08 07:00")) }
    end
    AlertEvent.delete_all
    Scheduler.tick(now: sh("2026-09-08 07:10"))
    assert_nil AlertEvent.find_by(kind: "reasons_missing")
  end

  # 画像为空时根本不该生成（终审 F1），缺理由就不是事故——后台那一格已经写着「兴趣画像为空」
  test "5.7 画像为空：缺理由不告警" do
    issues(:daily_0908).update!(published_at: sh("2026-09-08 06:12"))
    InterestArea.update_all(enabled: false)
    with_model_provider do
      Scheduler.tick(now: sh("2026-09-08 06:43"))
      assert_nil AlertEvent.find_by(kind: "reasons_missing")
    end
  end
end
