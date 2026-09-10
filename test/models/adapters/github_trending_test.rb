require "test_helper"

class Adapters::GithubTrendingTest < ActiveSupport::TestCase
  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "https://github.com/trending?since=daily").to_return(body: file_fixture("github_trending/daily.html").read)
  end

  test "解析综合榜前 10" do
    entries = Adapters::GithubTrending.new(sources(:github)).fetch
    assert_equal 10, entries.size
    first = entries.first
    assert_match %r{\A[\w.-]+/[\w.-]+\z}, first.title
    assert_match %r{\Ahttps://github\.com/}, first.url
    assert_kind_of Integer, first.meta[:stars]
    assert_kind_of Integer, first.meta[:stars_today]
    assert_operator first.meta[:stars], :>, 0
    assert entries.any? { |e| e.meta[:language].present? }
    assert entries.any? { |e| e.summary.present? }
  end

  test "多语言各取 5 并连续编号" do
    source = sources(:github)
    source.config = source.config.merge("languages" => [ "rust", "go" ], "count" => 5)
    stub_request(:get, "https://github.com/trending/rust?since=daily").to_return(body: file_fixture("github_trending/daily.html").read)
    stub_request(:get, "https://github.com/trending/go?since=daily").to_return(body: file_fixture("github_trending/daily.html").read)

    entries = Adapters::GithubTrending.new(source).fetch

    assert_equal 10, entries.size
    assert_equal (1..10).to_a, entries.map(&:rank)
    assert_equal [ "rust" ], entries.first(5).map { |e| e.meta[:language] }.uniq
    assert_equal [ "go" ], entries.last(5).map { |e| e.meta[:language] }.uniq
  end

  test "页面结构变了要报解析失败而不是静默 0 条" do
    stub_request(:get, "https://github.com/trending?since=daily").to_return(body: "<html><body>nothing</body></html>")
    assert_raises(Adapters::GithubTrending::ParseError) { Adapters::GithubTrending.new(sources(:github)).fetch }
  end
end
