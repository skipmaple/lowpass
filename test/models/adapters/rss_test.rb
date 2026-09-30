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

  # rss 的 Parser.parse 见到不含 < 的字符串，就当成地址（open-uri）或本地文件路径去读：源站只回一行地址，
  # 服务器就会绕过 surfguard 再请求一次，内网、云元数据地址都够得着
  test "正文是一个地址时报解析失败，不去请求它" do
    stub_request(:get, "https://example.com/atom").to_return(body: "http://internal.test/feed")
    internal = stub_request(:get, "http://internal.test/feed").to_return(body: file_fixture("rss/atom_sample.xml").read)
    source = Source.new(name: "x", adapter: "rss", publication: "daily", config: { feed_url: "https://example.com/atom", count: 10, window_hours: 24 * 365 * 10 })

    assert_raises(Adapters::Rss::ParseError) { Adapters::Rss.new(source).fetch }
    assert_not_requested internal
  end

  test "正文是一个本地文件路径时报解析失败，不去读它" do
    stub_request(:get, "https://example.com/atom").to_return(body: file_fixture("rss/atom_sample.xml").to_s)
    source = Source.new(name: "x", adapter: "rss", publication: "daily", config: { feed_url: "https://example.com/atom", count: 10, window_hours: 24 * 365 * 10 })

    assert_raises(Adapters::Rss::ParseError) { Adapters::Rss.new(source).fetch }
  end

  test "feed 标题给新建表单默认名称用" do
    adapter = Adapters::Rss.new(sources(:hackaday))
    assert_nil adapter.feed_title
    adapter.fetch
    assert_equal "Hackaday", adapter.feed_title

    atom = Adapters::Rss.new(Source.new(name: "x", adapter: "rss", publication: "daily", config: { feed_url: "https://example.com/atom", count: 10, window_hours: 24 * 365 * 10 }))
    atom.fetch
    assert_equal "Example Atom Feed", atom.feed_title
  end

  # 7.7 回填「有限」：feed 里还有那一天的条目就取，没有就是 0 条
  test "backfill 取发布日等于该日的条目" do
    dates = RSS::Parser.parse(file_fixture("rss/hackaday.xml").read, false).items.map { |item| item.pubDate.in_time_zone(PeriodKey::ZONE).to_date }
    day = dates.tally.max_by { |_, n| n }.first

    entries = Adapters::Rss.new(sources(:hackaday)).backfill(day)

    assert_equal dates.count(day).clamp(0, 10), entries.size
    assert entries.all? { |e| e.published_at.in_time_zone(PeriodKey::ZONE).to_date == day }
    assert_equal entries.map(&:published_at), entries.map(&:published_at).sort.reverse
    assert_empty Adapters::Rss.new(sources(:hackaday)).backfill(Date.new(2000, 1, 1))
    assert Adapters::Rss.backfill?
  end
end
