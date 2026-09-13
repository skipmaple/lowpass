require "test_helper"

# R-4.8 期发布或修订后 1 分钟内可搜：装订走 insert_all!，索引在同一个事务里写好，发布即可搜。
# 只有适配器出网那一层是替身，其余（job、装订、定稿、索引、控制器）都是正式代码路径。
class SearchFreshnessTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:drew))
    Rails.cache.clear
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
  end

  test "装订出的条目发布后立刻可搜，修订后搜到的是新条目" do
    Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "Kubernetes operator in Rust", url: "https://h.example/1", rank: 1) ])
    Adapters::GithubTrending.any_instance.stubs(:fetch).returns([])
    Adapters::Rss.any_instance.stubs(:fetch).returns([])
    issue = Issue.generate_daily!("2026-09-12")
    perform_enqueued_jobs
    assert issue.reload.published?

    get search_path(q: "kuber rust")

    assert_equal "results", page_props["state"]
    assert_equal daily_issue_path("2026-09-12", source: sources(:hn).id, anchor: "item-#{issue.items.sole.id}"), page_props["results"].sole["where"]["href"]

    # R-1.5 修订：整栏替换后旧条目不再可搜，新条目可搜
    issue.replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Revised: a soldering iron teardown", url: "https://h.example/2", rank: 1) ])

    get search_path(q: "kuber rust")
    assert_equal "empty", page_props["state"]

    get search_path(q: "soldering")
    assert_equal "results", page_props["state"]
  end
end
