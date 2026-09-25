require "test_helper"

# 抓取失败对管理员说的原因：一句中文，不带异常类名与源站地址（附录 B「重抓失败：{reason}」）
class Adapters::FailureTest < ActiveSupport::TestCase
  test "已知的失败各有一句" do
    { Adapters::Rss::ParseError.new("not a feed") => "不是有效的 RSS/Atom",
      Adapters::GithubTrending::ParseError.new("no trending rows") => "页面结构变了，解析不到条目",
      Adapters::RuanyfWeekly::Degraded.new("issue 411 parsed 3 items") => "解析出的条目太少，原文结构可能变了",
      Timeout::Error.new("execution expired") => "连接超时",
      Adapters::Http::Blocked.new("403 for https://hacker-news.firebaseio.com/v0/topstories.json") => "源站拒绝了请求（429 / 403）",
      Adapters::Http::Unresolvable.new("hackaday.com") => "地址解析不到公网 IP",
      Adapters::Http::TooLarge.new("2097153") => "响应超过 2 MB",
      Adapters::NoBackfill.new("该来源无法回填") => "该来源无法回填" }.each do |error, reason|
      assert_equal reason, Adapters::Failure.reason(error), error.class.name
    end
  end

  test "其余 HTTP 失败只报状态码，连不上就说连不上" do
    assert_equal "源站返回 HTTP 502", Adapters::Failure.reason(Adapters::Http::Error.new("502 for https://news.example/feed"))
    assert_equal "连接源站失败", Adapters::Failure.reason(Adapters::Http::Error.new("Failed to open TCP connection to news.example:443"))
  end

  test "没料到的异常留第一行做线索" do
    assert_equal "抓取出错：unexpected token at '<html>'", Adapters::Failure.reason(JSON::ParserError.new("unexpected token at '<html>'\nmore"))
  end
end
