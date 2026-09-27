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

  # D25：只有英文标题的源要译；HN 上偶尔出现的中文标题不用译
  test "只有 HN 的非中文标题要译" do
    assert items(:hn_one).translate_title?
    assert_not Item.new(source: sources(:hn), title: "中文互联网正在消失").translate_title?
    assert_not Item.new(source: sources(:github), title: "octo/tool").translate_title?
    assert_not Item.new(source: sources(:hackaday), title: "A 3D-printed rotary phone").translate_title?
    assert_not Item.new(source: sources(:ruanyf), title: "Rust 写的终端工具").translate_title?
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
