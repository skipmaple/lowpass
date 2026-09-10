require "test_helper"

class Adapters::RssTest < ActiveSupport::TestCase
  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "https://hackaday.com/feed/").to_return(body: file_fixture("rss/hackaday.xml").read)
    stub_request(:get, "https://example.com/atom").to_return(body: file_fixture("rss/atom_sample.xml").read)
  end

  test "RSS 2.0：时间窗口内最新 10 条，倒序" do
    newest = RSS::Parser.parse(file_fixture("rss/hackaday.xml").read, false).items.map(&:pubDate).max
    travel_to newest + 1.hour do
      entries = Adapters::Rss.new(sources(:hackaday)).fetch
      assert entries.size <= 10
      assert entries.all?(&:valid?)
      assert_equal entries.map(&:published_at), entries.map(&:published_at).sort.reverse
      assert entries.all? { |e| e.published_at >= 24.hours.ago }
    end
  end

  test "Atom：缺发布时间用抓取时间并标记" do
    source = Source.new(name: "x", adapter: "rss", publication: "daily", config: { feed_url: "https://example.com/atom", count: 10, window_hours: 24 * 365 * 10 })
    entries = Adapters::Rss.new(source).fetch
    assert_equal 2, entries.size
    assert entries.any? { |e| e.meta[:time_from_fetch] }
    assert_equal "https://example.com/img/1.png", entries.find { |e| e.title == "Dated entry" }.meta[:image_url]
    assert_equal "Alice", entries.find { |e| e.title == "Dated entry" }.author
  end

  test "周刊用法按 ISO 周过滤" do
    source = Source.new(name: "w", adapter: "rss", publication: "weekly", config: { feed_url: "https://example.com/atom", count: 50 })
    entries = Adapters::Rss.new(source).fetch(period_key: "2026-W36")
    assert_equal 1, entries.size
    assert entries.all? { |e| PeriodKey.weekly(e.published_at) == "2026-W36" }
  end

  test "不是 feed 时报解析失败" do
    stub_request(:get, "https://example.com/atom").to_return(body: "<html><body>nothing</body></html>")
    source = Source.new(name: "x", adapter: "rss", publication: "daily", config: { feed_url: "https://example.com/atom", count: 10, window_hours: 24 * 365 * 10 })
    assert_raises(Adapters::Rss::ParseError) { Adapters::Rss.new(source).fetch }
  end
end
