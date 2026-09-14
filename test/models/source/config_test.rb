require "test_helper"

# R-3.2 每种适配器的配置项：归一化把表单字符串转成该有的类型，校验给中文错误
class Source::ConfigTest < ActiveSupport::TestCase
  def errors_for(adapter, publication, raw)
    schema = Source::Config.for(adapter)
    errors = ActiveModel::Errors.new(Source.new)
    config = schema.normalize(raw, publication)
    schema.validate(config, publication, errors)
    [ config, errors.to_hash ]
  end

  test "HN：默认值补齐，整数转型" do
    config, errors = errors_for("hacker_news", "daily", { "count" => "20" })

    assert_equal({ "list" => "top", "count" => 20, "min_score" => 0 }, config)
    assert_empty errors
  end

  test "HN：榜单只能 top 或 best，条数 1 到 100" do
    _, errors = errors_for("hacker_news", "daily", { "list" => "new", "count" => "0", "min_score" => "-1" })

    assert_equal [ "只能是 top 或 best" ], errors[:"config.list"]
    assert_equal [ "1 到 100" ], errors[:"config.count"]
    assert_equal [ "不小于 0" ], errors[:"config.min_score"]
  end

  test "GitHub：语言列表按逗号拆、去空白，最多 3 个，名字合法" do
    config, errors = errors_for("github_trending", "daily", { "languages" => "Rust, TypeScript ,c++", "count" => "5" })
    assert_equal [ "Rust", "TypeScript", "c++" ], config["languages"]
    assert_empty errors

    _, errors = errors_for("github_trending", "daily", { "languages" => "a,b,c,d", "count" => "30" })
    assert_equal [ "最多 3 个" ], errors[:"config.languages"]
    assert_equal [ "1 到 25" ], errors[:"config.count"]

    _, errors = errors_for("github_trending", "daily", { "languages" => "Ru;st" })
    assert_equal [ "语言名只能有字母、数字与 + # . -" ], errors[:"config.languages"]
  end

  test "GitHub：数组形式的语言列表也接受" do
    config, = errors_for("github_trending", "daily", { "languages" => [ "Rust", "" ] })

    assert_equal [ "Rust" ], config["languages"]
  end

  test "RSS：feed 地址必填且是 http(s)，日刊才有时间窗口" do
    config, errors = errors_for("rss", "daily", { "feed_url" => " https://hackaday.com/feed/ " })
    assert_equal({ "feed_url" => "https://hackaday.com/feed/", "count" => 10, "window_hours" => 24 }, config)
    assert_empty errors

    config, errors = errors_for("rss", "weekly", { "feed_url" => "https://w.example/feed", "window_hours" => "999" })
    assert_equal({ "feed_url" => "https://w.example/feed", "count" => 10 }, config)
    assert_empty errors

    _, errors = errors_for("rss", "daily", { "feed_url" => "", "count" => "51", "window_hours" => "73" })
    assert_equal [ "必填" ], errors[:"config.feed_url"]
    assert_equal [ "1 到 50" ], errors[:"config.count"]
    assert_equal [ "1 到 72" ], errors[:"config.window_hours"]

    _, errors = errors_for("rss", "daily", { "feed_url" => "ftp://x/y" })
    assert_equal [ "要是 http(s) 地址" ], errors[:"config.feed_url"]
  end

  test "阮一峰：最少条目阈值 ≥ 1" do
    _, errors = errors_for("ruanyf_weekly", "weekly", { "min_items" => "0" })

    assert_equal [ "不小于 1" ], errors[:"config.min_items"]
  end

  test "非整数当缺失、走默认值" do
    config, errors = errors_for("hacker_news", "daily", { "count" => "abc" })

    assert_equal 10, config["count"]
    assert_empty errors
  end

  test "刊物与适配器绑定" do
    assert_equal %w[ daily ], Source::Config.for("hacker_news").publications
    assert_equal %w[ daily weekly ], Source::Config.for("rss").publications
    assert_equal %w[ weekly ], Source::Config.for("ruanyf_weekly").publications
  end
end
