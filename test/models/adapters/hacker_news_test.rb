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
end
