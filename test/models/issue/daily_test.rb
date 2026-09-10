require "test_helper"

class Issue::DailyTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ]) }

  def stub_all(entries_by_adapter)
    entries_by_adapter.each { |klass, entries| klass.any_instance.stubs(:fetch).returns(entries) }
  end

  test "AC-1.1 三源成功则发布" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ],
             Adapters::GithubTrending => [ Adapters::Entry.new(title: "g/g", url: "https://g/1") ],
             Adapters::Rss => [ Adapters::Entry.new(title: "r", url: "https://r/1") ])
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.published?
    assert_equal 3, issue.items.count
  end

  test "AC-1.2 一源失败其余照常发布" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ],
             Adapters::Rss => [ Adapters::Entry.new(title: "r", url: "https://r/1") ])
    Adapters::GithubTrending.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.published?
    assert_equal "failed", issue.source_state(sources(:github))
    assert_equal "ok", issue.source_state(sources(:hn))
  end

  test "AC-1.4 全部失败则空刊" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    Adapters::GithubTrending.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    Adapters::Rss.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.empty?
  end

  test "源成功但 0 条视为成功，状态是无新内容" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ], Adapters::GithubTrending => [], Adapters::Rss => [])
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.published?
    assert_equal "empty", issue.source_state(sources(:github))
  end

  test "期级超时按已完成结果发布" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ])
    issue = Issue.generate_daily!("2026-09-10")
    sources(:hn).fetch_now(issue, trigger: "scheduled")
    travel 21.minutes
    assert issue.timed_out?
    issue.finalize!(reason: "timeout")
    assert issue.reload.published?
    assert_equal "failed", issue.source_state(sources(:github))
  end

  test "重复结束不改写已发布的期" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ])
    issue = Issue.generate_daily!("2026-09-10")
    sources(:hn).fetch_now(issue, trigger: "scheduled")
    issue.finalize!(reason: "timeout")
    published_at = issue.reload.published_at

    travel 1.minute
    issue.finalize!(reason: "complete")
    issue.finalize_if_done!

    assert issue.reload.published?
    assert_equal published_at, issue.published_at
  end

  test "可重试失败在重试前是 pending，期不发布" do
    stub_all(Adapters::GithubTrending => [ Adapters::Entry.new(title: "g/g", url: "https://g/1") ],
             Adapters::Rss => [ Adapters::Entry.new(title: "r", url: "https://r/1") ])
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    issue = nil
    assert_enqueued_jobs 3 do
      issue = Issue.generate_daily!("2026-09-10")
    end

    FetchSourceJob.perform_now(sources(:hn), issue, "scheduled")

    assert_equal "pending", issue.source_state(sources(:hn))
    assert FetchRun.exists?(source: sources(:hn), issue: issue, attempt: 2, status: "queued")
    assert issue.reload.generating?
  end

  test "三次都失败后该源是 failed" do
    issue = Issue.generate_daily!("2026-09-11")
    sources(:hn).fetch_runs.create!(issue: issue, trigger: "scheduled", attempt: 3, status: "failed")

    assert_equal "failed", issue.source_state(sources(:hn))
    issue.finalize_if_done!
    assert issue.reload.generating?, "其余源还没有结果，不该结束这一期"
  end

  test "三次都失败后不再排队，期按其余源发布" do
    stub_all(Adapters::GithubTrending => [ Adapters::Entry.new(title: "g/g", url: "https://g/1") ],
             Adapters::Rss => [ Adapters::Entry.new(title: "r", url: "https://r/1") ])
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    issue = Issue.generate_daily!("2026-09-13")

    perform_enqueued_jobs
    assert issue.reload.generating?

    perform_enqueued_jobs
    assert issue.reload.generating?

    assert_raises(Adapters::Http::Error) { perform_enqueued_jobs }

    assert issue.reload.published?
    assert_equal "failed", issue.source_state(sources(:hn))
    assert_not FetchRun.exists?(source: sources(:hn), issue: issue, attempt: 4)
    assert sources(:hn).fetch_runs.where(issue: issue, status: "queued").none?
  end

  test "生成中的期重抓不提前发布" do
    issue = Issue.generate_daily!("2026-09-12")
    Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "h", url: "https://h/1") ])

    Issue.regenerate_source!(issue, sources(:hn))

    assert issue.reload.generating?
    assert_nil issue.revised_at
    assert_nil issue.published_at
    assert_equal 1, issue.items.where(source: sources(:hn)).count
  end

  test "重抓成功整栏替换并写修订时间" do
    issue = issues(:daily_0908)
    kept = Item.create!(source: sources(:github), issue: issue, title: "g", url: "https://g/1",
                        url_hash: UrlNormalizer.hash("https://g/1"), fetched_at: Time.current)
    Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "新", url: "https://h/new") ])

    Issue.regenerate_source!(issue, sources(:hn))

    assert_equal [ "新" ], issue.items.where(source: sources(:hn)).pluck(:title)
    assert_equal [ kept.id ], issue.items.where(source: sources(:github)).pluck(:id)
    assert issue.reload.revised_at.present?
  end

  test "重抓失败保留旧内容且不写修订时间" do
    issue = issues(:daily_0908)
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")

    assert_raises(Adapters::Http::Blocked) { Issue.regenerate_source!(issue, sources(:hn)) }

    assert_equal [ items(:hn_one).id ], issue.items.where(source: sources(:hn)).pluck(:id)
    assert_nil issue.reload.revised_at
  end
end
