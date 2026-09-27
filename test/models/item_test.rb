require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "同源同期同地址唯一" do
    existing = items(:hn_one)
    dup = existing.dup
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "标题超过 300 字符被数据库拒绝" do
    item = items(:hn_one)
    assert_raises(ActiveRecord::StatementInvalid) do
      item.update_column(:title, "x" * 301)
    end
  end

  test "标题译文最多 300 字符：模型校验与数据库约束两道" do
    item = items(:hn_one)
    item.title_zh = "译" * 300
    assert item.valid?
    item.title_zh = "译" * 301
    assert_not item.valid?

    # 数据库拒绝之后这个事务就废了，放在最后
    assert_raises(ActiveRecord::StatementInvalid) { item.update_column(:title_zh, "译" * 301) }
  end

  # D25：日刊里 HN 与 RSS 源（Hackaday）的标题要译；仓库名、本来就是中文的标题、周刊都不译
  test "HN 与 Hackaday 的英文标题要译" do
    assert items(:hn_one).translate_title?
    assert Item.new(source: sources(:hackaday), title: "A 3D-printed rotary phone").translate_title?

    assert_not Item.new(source: sources(:hn), title: "中文互联网正在消失").translate_title?
    assert_not Item.new(source: sources(:hackaday), title: "用 ESP32 做的旋转拨号电话").translate_title?
    assert_not Item.new(source: sources(:github), title: "octo/tool").translate_title?
    assert_not Item.new(source: sources(:ruanyf), title: "Rust 写的终端工具").translate_title?
    weekly_feed = Source.new(name: "Weekly feed", adapter: "rss", publication: "weekly")
    assert_not Item.new(source: weekly_feed, title: "This week in Rust").translate_title?
  end

  # D25：GitHub Trending 的标题是仓库名，译的是仓库简介；没有简介、简介本来就是中文的不译，别的源的摘要也不译
  test "GitHub Trending 的英文简介要译" do
    assert Item.new(source: sources(:github), title: "octo/tool", summary: "A tiny CLI tool").translate_summary?

    assert_not Item.new(source: sources(:github), title: "octo/tool", summary: nil).translate_summary?
    assert_not Item.new(source: sources(:github), title: "octo/tool", summary: "").translate_summary?
    assert_not Item.new(source: sources(:github), title: "octo/tool", summary: "一个命令行小工具").translate_summary?
    assert_not Item.new(source: sources(:hackaday), title: "A 3D-printed rotary phone", summary: "It works.").translate_summary?
    assert_not items(:hn_one).translate_summary?
  end

  test "简介译文最多 500 字符：模型校验与数据库约束两道" do
    item = items(:hn_one)
    item.summary_zh = "译" * 500
    assert item.valid?
    item.summary_zh = "译" * 501
    assert_not item.valid?

    # 数据库拒绝之后这个事务就废了，放在最后
    assert_raises(ActiveRecord::StatementInvalid) { item.update_column(:summary_zh, "译" * 501) }
  end

  test "url 必须是 http 或 https，且不能带空白" do
    item = items(:hn_one)

    item.url = "ftp://a.b"
    assert_not item.valid?

    item.url = "https://a.b/x y"
    assert_not item.valid?

    item.url = "https://a.b/x"
    assert item.valid?
  end

  # 周刊页板块锚点与搜索结果的所在期链接共用这一处（设计 6.3）
  test "锚点：阮一峰按期号加板块 slug，没有板块的源落到源节头" do
    item = items(:hn_one)
    assert_equal "source-#{sources(:hn).id}", item.anchor

    item.meta = { "issue_no" => 366, "anchor" => "工具" }
    assert_equal "issue-366-工具", item.anchor

    item.meta = { "anchor" => "工具" }
    assert_equal "工具", item.anchor
  end
end
