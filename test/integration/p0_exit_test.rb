require "test_helper"

# P0 出口：一期日刊从建期、三个源并行抓取、定稿，一路走到读者在页面上读得到。
# 只有适配器出网那一层是替身，其余（job、装订、定稿、props）都是正式代码路径。
class P0ExitTest < ActionDispatch::IntegrationTest
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ]) }

  test "生成一期日刊，三个源的条目都读得到" do
    Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "A terminal log viewer", url: "https://h.example/1", rank: 1) ])
    Adapters::GithubTrending.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "owner/repo", url: "https://g.example/1", rank: 1) ])
    Adapters::Rss.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "A soldering iron teardown", url: "https://r.example/1", rank: 1) ])

    issue = Issue.generate_daily!("2026-09-12")
    perform_enqueued_jobs

    assert issue.reload.published?

    get daily_issue_path("2026-09-12")

    assert_response :success
    assert_equal %w[ ok ok ok ], page_props["sources"].map { |source| source["state"] }

    items = page_props["items_by_source"]
    assert_equal [ "A terminal log viewer" ], items.fetch(sources(:hn).id).map { |item| item["title"] }
    assert_equal [ "owner/repo" ], items.fetch(sources(:github).id).map { |item| item["title"] }
    assert_equal [ "A soldering iron teardown" ], items.fetch(sources(:hackaday).id).map { |item| item["title"] }

    # 没有开 SSR：页面上读得到的每个字符串都得先出现在 payload 里
    assert_includes response.body, "A terminal log viewer"
  end

  test "四个适配器都有基于样本的测试" do
    Source::ADAPTERS.each do |adapter|
      assert File.exist?(Rails.root.join("test/models/adapters/#{adapter}_test.rb")), adapter
    end
    assert_operator Dir[Rails.root.join("test/fixtures/files/ruanyf/issue-*.md")].size, :>=, 20
  end
end
