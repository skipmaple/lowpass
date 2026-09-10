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
end
