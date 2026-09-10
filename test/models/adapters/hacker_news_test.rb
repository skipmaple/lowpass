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
end
