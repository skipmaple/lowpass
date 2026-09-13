require "test_helper"

# R-3.3 测试抓取：30 秒内前 5 条预览、解析警告、可读的失败原因（P2 退出条件）
class Source::TestFetchTest < ActiveSupport::TestCase
  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "https://hackaday.com/feed/").to_return(body: file_fixture("rss/hackaday.xml").read)
  end

  def rss_attrs(overrides = {})
    { name: "Hackaday", adapter: "rss", publication: "daily", config: { "feed_url" => "https://hackaday.com/feed/", "count" => "10", "window_hours" => "24" } }.merge(overrides)
  end

  test "成功：前 5 条预览、总数、用时、feed 标题" do
    newest = RSS::Parser.parse(file_fixture("rss/hackaday.xml").read, false).items.map(&:pubDate).max
    travel_to newest + 1.hour do
      result = nil
      # fixture 里已经有一条 fetch_runs（hn_ok），这里断言的是「没多记一条」，不是「表是空的」
      assert_no_difference -> { FetchRun.count } do
        result = Source::TestFetch.call(rss_attrs)
      end

      assert result.ok
      assert_equal 5, result.entries.size
      assert_operator result.parsed, :>=, 5
      assert_equal 0, result.dropped
      assert_kind_of Integer, result.duration_ms
      assert_equal "Hackaday", result.feed_title
      first = result.entries.first
      assert first[:title].present?
      assert_match %r{\Ahttps?://}, first[:url]
      assert_match(/\A\d{2}-\d{2} \d{2}:\d{2}\z/, first[:published_label])
      assert_nil result.error
    end
  end

  # feed_url_unique（Source）给这个地址挂 :duplicate：那是保存时的事，表单在保存时报；
  # 试抓只答「这个地址能不能抓到东西」，不因为撞了别的源就不让点（下面用同一个 fixture 的地址来撞）
  test "新源的 feed 地址与现有源重复：试抓照样进行，重复留给保存时报" do
    newest = RSS::Parser.parse(file_fixture("rss/hackaday.xml").read, false).items.map(&:pubDate).max
    travel_to newest + 1.hour do
      result = Source::TestFetch.call(rss_attrs)

      assert result.ok
      assert_nil result.error
      assert_equal "Hackaday", result.feed_title
    end
  end

  test "已保存的源记一条 trigger=test 的抓取记录" do
    travel_to Time.utc(2030, 1, 1) do
      result = Source::TestFetch.call(rss_attrs(id: sources(:hackaday).id))

      assert result.ok
      run = sources(:hackaday).fetch_runs.sole
      assert_equal "test", run.trigger
      assert_nil run.issue
      assert_equal "succeeded", run.status
      assert_equal result.parsed, run.item_count
    end
  end

  test "解析警告：无发布时间的条目" do
    stub_request(:get, "https://example.com/atom").to_return(body: file_fixture("rss/atom_sample.xml").read)

    result = Source::TestFetch.call(rss_attrs(config: { "feed_url" => "https://example.com/atom", "count" => "10", "window_hours" => "72" }))

    assert result.ok
    assert_includes result.warnings, "1 条无发布时间，已用抓取时间代替"
  end

  test "不是 feed：可读的错误句，源已保存时记失败" do
    stub_request(:get, "https://hackaday.com/feed/").to_return(body: "<html><body>nope</body></html>")

    result = Source::TestFetch.call(rss_attrs(id: sources(:hackaday).id))

    assert_not result.ok
    assert_equal "不是有效的 RSS/Atom，请检查地址。", result.error
    assert_equal [], result.entries
    assert_equal "failed", sources(:hackaday).fetch_runs.sole.status
  end

  test "超时" do
    Adapters::Rss.any_instance.stubs(:test_fetch).raises(Timeout::Error)

    result = Source::TestFetch.call(rss_attrs(id: sources(:hackaday).id))

    assert_equal "连接超时（30 秒），请检查地址或稍后重试。", result.error
    run = sources(:hackaday).fetch_runs.sole
    assert_equal "timed_out", run.status
    assert_kind_of Integer, run.duration_ms
    assert_operator run.duration_ms, :>=, 0
  end

  test "源站拒绝、解析不到公网地址、响应过大、其他错误各有一句" do
    { Adapters::Http::Blocked.new("403") => "源站拒绝了请求（429 / 403）。",
      Adapters::Http::Unresolvable.new("x") => "地址解析不到公网 IP。",
      Adapters::Http::TooLarge.new("x") => "响应超过 2 MB。",
      Adapters::Http::Error.new("500 Internal Server Error\nmore") => "抓取失败：500 Internal Server Error" }.each do |error, message|
      Adapters::Rss.any_instance.stubs(:test_fetch).raises(error)

      assert_equal message, Source::TestFetch.call(rss_attrs).error
    end
  end

  test "配置不合法就不发请求" do
    result = Source::TestFetch.call(rss_attrs(config: { "feed_url" => "" }))

    assert_not result.ok
    assert_equal "配置不完整：feed 地址必填", result.error
    assert_not_requested :get, "https://hackaday.com/feed/"
  end

  test "HN 的预览带分数与评论" do
    ids = JSON.parse(file_fixture("hacker_news/topstories.json").read)
    stub_request(:get, "https://hacker-news.firebaseio.com/v0/topstories.json").to_return(body: ids.to_json)
    ids.each { |id| stub_request(:get, "https://hacker-news.firebaseio.com/v0/item/#{id}.json").to_return(body: file_fixture("hacker_news/item_#{id}.json").read) }

    result = Source::TestFetch.call(name: "HN", adapter: "hacker_news", publication: "daily", config: { "list" => "top", "count" => "10", "min_score" => "0" })

    assert result.ok
    assert_kind_of Integer, result.entries.first[:meta][:score]
    assert_nil result.feed_title
  end
end
