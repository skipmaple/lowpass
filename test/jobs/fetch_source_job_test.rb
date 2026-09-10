require "test_helper"

class FetchSourceJobTest < ActiveJob::TestCase
  test "失败后重试，最多 3 次" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    assert_enqueued_with(job: FetchSourceJob) do
      FetchSourceJob.perform_now(sources(:hn), issues(:daily_0908), "scheduled")
    end
    assert_equal 1, FetchRun.where(source: sources(:hn), attempt: 1, status: "failed").count
  end

  test "429 直接放弃不重试" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked.new("429"))
    assert_no_enqueued_jobs do
      FetchSourceJob.perform_now(sources(:hn), issues(:daily_0908), "scheduled")
    end
    assert_equal 1, FetchRun.where(source: sources(:hn), attempt: 1, status: "failed").count
  end
end
