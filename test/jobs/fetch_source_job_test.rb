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
end
