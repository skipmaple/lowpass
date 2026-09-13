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

  test "保存前归一化配置并按适配器校验" do
    source = Source.new(name: "HN best", adapter: "hacker_news", publication: "daily", config: { "list" => "best", "count" => "5" })

    assert source.valid?
    assert_equal({ "list" => "best", "count" => 5, "min_score" => 0 }, source.config)
  end

  test "配置错误挂在 config.<字段> 上" do
    source = Source.new(name: "HN bad", adapter: "hacker_news", publication: "daily", config: { "count" => "0" })

    assert_not source.valid?
    assert_equal [ "1 到 100" ], source.errors[:"config.count"]
  end

  test "AC-3.6 同名源被拒绝" do
    source = Source.new(name: "Hacker News", adapter: "rss", publication: "daily", config: { "feed_url" => "https://x.example/feed" })

    assert_not source.valid?
    assert_equal [ "名称已存在" ], source.errors[:name]
  end

  test "刊物与适配器不符" do
    source = Source.new(name: "HN weekly", adapter: "hacker_news", publication: "weekly", config: {})

    assert_not source.valid?
    assert_equal [ "这个适配器只能是日刊" ], source.errors[:publication]
  end

  # R-3.8 同一刊物内 feed 地址唯一：校验先给可读提示，数据库表达式索引兜底
  test "同刊物里重复的 feed 地址被拒绝，另一刊物可以" do
    dup = Source.new(name: "Hackaday 2", adapter: "rss", publication: "daily", config: { "feed_url" => "https://hackaday.com/feed/" })
    assert_not dup.valid?
    assert_equal [ "这个 feed 地址已经在同一刊物里" ], dup.errors[:"config.feed_url"]

    weekly = Source.new(name: "Hackaday weekly", adapter: "rss", publication: "weekly", config: { "feed_url" => "https://hackaday.com/feed/" })
    assert weekly.valid?

    assert_raises(ActiveRecord::RecordNotUnique) do
      # insert_all（不带 !）在唯一索引冲突时默认 ON CONFLICT DO NOTHING、静默跳过；
      # 要证明数据库表达式索引真的兜底会拒绝，得用 insert_all! 让冲突原样抛出。
      Source.insert_all!([ { id: Lowpass::Uuid.generate, name: "raw", adapter: "rss", publication: "daily", config: { feed_url: "https://hackaday.com/feed/" }, sort_order: 9, enabled: true, created_at: Time.current, updated_at: Time.current } ])
    end
  end

  test "排序值是非负整数" do
    source = sources(:hn)
    source.sort_order = -1

    assert_not source.valid?
  end
end
