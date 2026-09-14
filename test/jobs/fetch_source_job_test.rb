require "test_helper"

class FetchSourceJobTest < ActiveJob::TestCase
  test "失败后重试，最多 3 次" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    issue = Issue.generate_daily!("2026-09-14")
    assert_enqueued_with(job: FetchSourceJob) do
      FetchSourceJob.perform_now(sources(:hn), issue, "scheduled")
    end
    assert_equal 1, FetchRun.where(source: sources(:hn), issue: issue, attempt: 1, status: "failed").count
  end

  test "可重试失败后写入排队记录，重试复用它而不是新增一条" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    issue = Issue.generate_daily!("2026-09-15")

    FetchSourceJob.perform_now(sources(:hn), issue, "scheduled")
    assert_equal 1, FetchRun.where(source: sources(:hn), issue: issue, attempt: 2, status: "queued").count

    retry_job = FetchSourceJob.new(sources(:hn), issue, "scheduled")
    retry_job.executions = 1   # 第二次执行，attempt 2
    retry_job.perform_now

    second = FetchRun.where(source: sources(:hn), issue: issue, attempt: 2)
    assert_equal 1, second.count
    assert_equal "failed", second.first.status
    assert_equal 1, FetchRun.where(source: sources(:hn), issue: issue, attempt: 3, status: "queued").count
  end

  # 退避是 30 秒、120 秒（WAITS）：重试挤在一起对上游没意义，也赶不上 20 分钟的期级超时
  test "两次重试分别等 30 秒与 120 秒" do
    freeze_time do
      Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
      issue = Issue.generate_daily!("2026-09-17")

      clear_enqueued_jobs

      assert_enqueued_with(job: FetchSourceJob, at: 30.seconds.from_now) do
        FetchSourceJob.perform_now(sources(:hn), issue, "scheduled")
      end

      # 退避读的是这个 job 自己的重试记账：接着上一步排出来的那个 job 往下跑，才轮得到 120 秒
      second = ActiveJob::Base.deserialize(enqueued_jobs.last)
      clear_enqueued_jobs

      assert_enqueued_with(job: FetchSourceJob, at: 120.seconds.from_now) { second.perform_now }
    end
  end

  test "429 直接放弃不重试" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked.new("429"))
    issue = Issue.generate_daily!("2026-09-16")
    assert_no_enqueued_jobs do
      FetchSourceJob.perform_now(sources(:hn), issue, "scheduled")
    end
    assert_equal 1, FetchRun.where(source: sources(:hn), issue: issue, attempt: 1, status: "failed").count
  end

  test "同一期同一源同时只允许一个抓取任务" do
    assert_equal 1, FetchSourceJob.concurrency_limit

    job = FetchSourceJob.new(sources(:hn), issues(:daily_0908), "manual")
    key = job.concurrency_key
    assert_includes key, sources(:hn).id.to_s
    assert_includes key, issues(:daily_0908).id.to_s

    job2 = FetchSourceJob.new(sources(:hn), issues(:weekly_w36), "manual")
    key2 = job2.concurrency_key
    refute_equal key, key2
  end

  test "backfill 参数走适配器的 backfill，而不是 fetch" do
    Adapters::HackerNews.any_instance.expects(:fetch).never
    Adapters::HackerNews.any_instance.expects(:backfill).with(Date.new(2026, 9, 3)).returns([ Adapters::Entry.new(title: "h", url: "https://h/1") ])
    issue = Issue.daily.create!(period_key: "2026-09-03", state: "generating", generation_started_at: Time.current, generated_late: true)

    FetchSourceJob.perform_now(sources(:hn), issue, "manual", true)

    assert_equal "succeeded", FetchRun.find_by(source: sources(:hn), issue: issue).status
  end

  # 7.7 无法回填是设计上的「不能」：记一条固定文案的失败就到此为止，不重试
  test "不支持回填的源直接丢弃，不排重试" do
    issue = Issue.daily.create!(period_key: "2026-09-03", state: "generating", generation_started_at: Time.current, generated_late: true)

    assert_no_enqueued_jobs do
      FetchSourceJob.perform_now(sources(:github), issue, "manual", true)
    end

    run = FetchRun.find_by(source: sources(:github), issue: issue)
    assert_equal "failed", run.status
    assert_equal "该来源无法回填", run.error_summary
  end

  test "周刊期的手动重抓走 Issue.refetch_weekly!" do
    Issue.expects(:refetch_weekly!).with(issues(:weekly_w36), sources(:ruanyf), attempt: 1).returns(FetchRun.new(status: "succeeded"))
    Source.any_instance.expects(:fetch_now).never

    FetchSourceJob.perform_now(sources(:ruanyf), issues(:weekly_w36), "manual")
  end

  # 跟日刊路径同一个做法：可重试失败先写 queued 占位，重试认领它而不是新开一条，
  # 不然那条 queued 永远留在 FetchRun.active 里，后台会把这个源一直报成运行中
  test "周刊重抓可重试失败后写入排队记录，重试复用它而不是新增一条" do
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).raises(Adapters::Http::Error, "down")
    issue = issues(:weekly_w36)
    issue.items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })

    FetchSourceJob.perform_now(sources(:ruanyf), issue, "manual")

    assert_equal 1, FetchRun.where(source: sources(:ruanyf), issue: issue, attempt: 1, status: "failed").count
    assert_equal 1, FetchRun.where(source: sources(:ruanyf), issue: issue, attempt: 2, status: "queued").count

    retry_job = FetchSourceJob.new(sources(:ruanyf), issue, "manual")
    retry_job.executions = 1   # 第二次执行，attempt 2
    retry_job.perform_now

    second = FetchRun.where(source: sources(:ruanyf), issue: issue, attempt: 2)
    assert_equal 1, second.count
    assert_equal "failed", second.first.status
    assert_equal 1, FetchRun.where(source: sources(:ruanyf), issue: issue, attempt: 3, status: "queued").count
  end

  test "5.7 三次都失败：告警一次，第三次仍然抛出" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    issue = Issue.generate_daily!("2026-09-18")
    job = FetchSourceJob.new(sources(:hn), issue, "scheduled")
    job.executions = 2
    # retry_on 的 attempts: 数的是 exception_executions，不是 executions（Task 3 笔记）：新建的 job
    # 这个计数是空的，只设 executions 触发不了耗尽块；这里把它也垫到 2，加上下面真正抛出的这一次
    # 正好凑满 3 次。键的写法核对过安装的 activejob 8.1.3.1（exceptions.rb#executions_for 用
    # exceptions.to_s，即 retry_on 声明的异常数组原样 to_s）
    job.exception_executions = { "[Adapters::Http::Error, Timeout::Error]" => 2 }
    assert_difference("AlertEvent.where(kind: 'source_failed').count", 1) { assert_raises(Adapters::Http::Error) { job.perform_now } }
    event = AlertEvent.find_by!(kind: "source_failed")
    assert_equal sources(:hn), event.source
    assert_equal issue, event.issue
    assert_equal "down", event.summary
  end

  test "第一次可重试失败不告警" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    issue = Issue.generate_daily!("2026-09-19")
    assert_no_difference("AlertEvent.count") { FetchSourceJob.perform_now(sources(:hn), issue, "scheduled") }
  end

  test "429 丢弃也告警" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked.new("429"))
    issue = Issue.generate_daily!("2026-09-20")
    assert_difference("AlertEvent.where(kind: 'source_failed').count", 1) { FetchSourceJob.perform_now(sources(:hn), issue, "scheduled") }
  end

  test "解析异常不重试：告警并抛出；无法回填不告警" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(RuntimeError, "bad html")
    issue = Issue.generate_daily!("2026-09-21")
    assert_difference("AlertEvent.where(kind: 'source_failed').count", 1) do
      assert_raises(RuntimeError) { FetchSourceJob.perform_now(sources(:hn), issue, "scheduled") }
    end

    old = Issue.backfill_daily!("2026-09-01")
    assert_no_difference("AlertEvent.count") { FetchSourceJob.perform_now(sources(:github), old, "manual", true) }
  end

  test "抓取成功后恢复同源的未恢复事件" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      open = alert_event
      Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "ok", url: "https://h/ok") ])
      issue = Issue.generate_daily!("2026-09-22")
      assert_enqueued_with(job: DeliverAlertJob, args: [ open, "recovery" ]) { FetchSourceJob.perform_now(sources(:hn), issue, "scheduled") }
      assert_not_nil open.reload.recovered_at
    end
  end
end
