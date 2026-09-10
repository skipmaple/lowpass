require "test_helper"

class Source::FetchingTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ]) }

  test "成功时写入条目、记录成功、整栏替换旧条目" do
    issue = issues(:daily_0908)
    entries = [ Adapters::Entry.new(title: "A", url: "https://a.b/1", rank: 1), Adapters::Entry.new(title: "B", url: "https://a.b/2", rank: 2) ]
    Adapters::HackerNews.any_instance.stubs(:fetch).returns(entries)

    run = sources(:hn).fetch_now(issue, trigger: "manual")

    assert_equal "succeeded", run.status
    assert_equal 2, run.item_count
    assert_equal %w[ A B ], issue.items.where(source: sources(:hn)).ranked.pluck(:title)
    assert_kind_of Hash, issue.items.where(source: sources(:hn)).first.meta
  end

  test "缺链接的条目被丢弃并计数" do
    entries = [ Adapters::Entry.new(title: "A", url: nil), Adapters::Entry.new(title: "B", url: "https://a.b/2") ]
    Adapters::HackerNews.any_instance.stubs(:fetch).returns(entries)
    run = sources(:hn).fetch_now(issues(:daily_0908), trigger: "manual")
    assert_equal 1, run.item_count
    assert_equal 1, run.dropped_count
  end

  test "失败时记录失败与错误摘要" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "boom")
    error = assert_raises(Adapters::Http::Error) { sources(:hn).fetch_now(issues(:daily_0908), trigger: "manual") }
    assert_equal "boom", error.message
    run = sources(:hn).fetch_runs.ordered.first
    assert_equal "failed", run.status
    assert_equal "boom", run.error_summary
  end

  test "健康度由最近记录推导" do
    source = sources(:hn)
    3.times { source.fetch_runs.create!(trigger: "scheduled", status: "failed", attempt: 1) }
    assert_equal "consecutive_failures", source.health
    source.fetch_runs.create!(trigger: "scheduled", status: "succeeded", attempt: 1)
    assert_equal "ok", source.health
  end

  test "日刊不传周期键，周刊传 ISO 周键" do
    Adapters::Rss.any_instance.expects(:fetch).with(period_key: nil).returns([])
    sources(:hackaday).fetch_now(issues(:daily_0908), trigger: "manual")

    Adapters::RuanyfWeekly.any_instance.expects(:fetch).with(period_key: "2026-W36").returns([])
    sources(:ruanyf).fetch_now(issues(:weekly_w36), trigger: "manual")
  end

  test "期定稿后调度抓取不再写入" do
    Adapters::HackerNews.any_instance.expects(:fetch).never

    run = sources(:hn).fetch_now(issues(:daily_0908), trigger: "scheduled")

    assert_equal "failed", run.status
    assert_equal "期已定稿，放弃写入", run.error_summary
    assert Item.exists?(items(:hn_one).id)
  end

  test "进行中的抓取不算失败" do
    source = sources(:hn)
    # hn_ok fixture exists as succeeded run
    source.fetch_runs.create!(trigger: "scheduled", status: "running", attempt: 1, started_at: Time.current)
    assert_equal "ok", source.health

    source.fetch_runs.create!(trigger: "scheduled", status: "failed", attempt: 1)
    assert_equal "recent_failure", source.health
  end
end
