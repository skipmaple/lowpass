require "test_helper"

class Adapters::HackerNewsTest < ActiveSupport::TestCase
  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    ids = JSON.parse(file_fixture("hacker_news/topstories.json").read)
    stub_request(:get, "https://hacker-news.firebaseio.com/v0/topstories.json").to_return(body: ids.to_json)
    ids.each do |id|
      stub_request(:get, "https://hacker-news.firebaseio.com/v0/item/#{id}.json").to_return(body: file_fixture("hacker_news/item_#{id}.json").read)
    end
  end

  test "取前 10 条 story，跳过 job，带分数与评论" do
    entries = Adapters::HackerNews.new(sources(:hn)).fetch
    assert_equal 10, entries.size
    assert entries.all?(&:valid?)
    assert_equal (1..10).to_a, entries.map(&:rank)
    first = entries.first
    assert_kind_of Integer, first.meta[:score]
    assert_match %r{news\.ycombinator\.com/item\?id=}, first.meta[:comments_url]
    # Verify first entry matches the first story in topstories.json
    ids = JSON.parse(file_fixture("hacker_news/topstories.json").read)
    first_story_id = ids.find { |id| JSON.parse(file_fixture("hacker_news/item_#{id}.json").read)["type"] == "story" }
    assert first.meta[:comments_url].end_with?("item?id=#{first_story_id}"), "First entry should be the first story in topstories.json"
  end

  test "无外链的帖子指向讨论页" do
    entries = Adapters::HackerNews.new(sources(:hn)).fetch
    ask = entries.find { |e| e.title.start_with?("Ask HN") }
    assert ask, "样本必须含一条 Ask HN 帖"
    assert_match %r{news\.ycombinator\.com/item\?id=}, ask.url
  end

  test "跳过 job 类型" do
    # Move job id to the front so the adapter must evaluate type filter to skip it
    ids = JSON.parse(file_fixture("hacker_news/topstories.json").read)
    reordered_ids = [ 49625110 ] + ids.reject { |id| id == 49625110 }
    stub_request(:get, "https://hacker-news.firebaseio.com/v0/topstories.json").to_return(body: reordered_ids.to_json)

    entries = Adapters::HackerNews.new(sources(:hn)).fetch
    assert_equal 10, entries.size
    comments_urls = entries.map { |e| e.meta[:comments_url] }
    assert_not comments_urls.include?("https://news.ycombinator.com/item?id=49625110")
    # Prove the filter was reached: the entry at rank 1 is NOT the job item
    assert_not entries.first.meta[:comments_url].end_with?("id=49625110")
  end

  test "条目接口返回 null 时跳过" do
    ids = JSON.parse(file_fixture("hacker_news/topstories.json").read)
    # Pick first id unless it's the job, then pick second
    null_id = ids.first == 49625110 ? ids.second : ids.first
    # Stub this id to return null (purged item)
    stub_request(:get, "https://hacker-news.firebaseio.com/v0/item/#{null_id}.json").to_return(body: "null")

    entries = Adapters::HackerNews.new(sources(:hn)).fetch
    assert_equal 10, entries.size
    comments_urls = entries.map { |e| e.meta[:comments_url] }
    assert_not comments_urls.any? { |url| url.end_with?("item?id=#{null_id}") }, "No entry should have the null item id"
  end

  # 7.7 回填：Algolia 按该上海日的 UTC 秒区间查 front_page，按分数降序取 count 条，跳过低于最低分数的
  test "backfill 用 Algolia 按日期查，分数降序、过滤最低分数、无外链指向讨论页" do
    from = Date.new(2026, 9, 3).in_time_zone(PeriodKey::ZONE).beginning_of_day.to_i
    stub_request(:get, "https://hn.algolia.com/api/v1/search")
      .with(query: { "tags" => "front_page", "numericFilters" => "created_at_i>=#{from},created_at_i<#{from + 86_400}", "hitsPerPage" => "30" })
      .to_return(body: file_fixture("hacker_news/algolia_front_page.json").read)
    source = Source.new(name: "HN", adapter: "hacker_news", publication: "daily", config: { "list" => "top", "count" => 10, "min_score" => 10 })

    entries = Adapters::HackerNews.new(source).backfill(Date.new(2026, 9, 3))

    assert_equal [ "A tiny Rust operator for Kubernetes", "ESP32 weather station survives its first typhoon", "Ask HN: How do you archive personal notes?" ], entries.map(&:title)
    assert_equal [ 1, 2, 3 ], entries.map(&:rank)
    assert_equal "https://news.ycombinator.com/item?id=45601002", entries.last.url
    assert_equal 312, entries.first.meta[:score]
    assert_equal 145, entries.first.meta[:comments]
    assert entries.all? { |e| e.published_at.in_time_zone(PeriodKey::ZONE).to_date == Date.new(2026, 9, 3) }
    assert entries.all?(&:valid?)
    assert Adapters::HackerNews.backfill?
  end
end
