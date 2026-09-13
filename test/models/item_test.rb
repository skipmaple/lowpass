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
