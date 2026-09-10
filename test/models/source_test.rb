require "test_helper"

class SourceTest < ActiveSupport::TestCase
  test "enabled.daily.ordered 按 sort_order 返回三个日刊源，排除周刊源" do
    assert_equal [ sources(:hn), sources(:github), sources(:hackaday) ], Source.enabled.daily.ordered.to_a
  end

  test "RSS 源的栏尾外链回到 feed 的站点根" do
    assert_equal "https://hackaday.com/", sources(:hackaday).home_url
  end

  test "feed 地址不是 http(s) 时没有栏尾外链可去" do
    source = Source.new(name: "Bad Feed", adapter: "rss", publication: "daily", config: { "feed_url" => "not a url" })

    assert_nil source.home_url
  end

  test "adapter 不在白名单内则无效" do
    source = Source.new(name: "Unknown Source", adapter: "unknown", publication: "daily")
    assert_not source.valid?
  end
end
