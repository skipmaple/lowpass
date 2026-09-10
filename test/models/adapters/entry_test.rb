require "test_helper"

class Adapters::EntryTest < ActiveSupport::TestCase
  test "缺标题或缺链接无效" do
    assert_not Adapters::Entry.new(title: "", url: "https://a.b").valid?
    assert_not Adapters::Entry.new(title: "t", url: nil).valid?
    assert Adapters::Entry.new(title: "t", url: "https://a.b").valid?
  end

  test "转成条目属性时清洗摘要并算哈希" do
    entry = Adapters::Entry.new(title: " 标题 ", url: "https://A.b/x/", summary: "<b>hi</b>")
    attrs = entry.to_item_attributes(source: sources(:hn), issue: issues(:daily_0908))
    assert_equal "标题", attrs[:title]
    assert_equal "hi", attrs[:summary]
    assert_equal UrlNormalizer.url_hash("https://A.b/x/"), attrs[:url_hash]
    assert_equal sources(:hn).id, attrs[:source_id]
  end

  test "链接不可解析或没有主机时无效" do
    assert_not Adapters::Entry.new(title: "t", url: "https://exa mple.com/x").valid?
    assert_not Adapters::Entry.new(title: "t", url: "https://").valid?
    assert_not Adapters::Entry.new(title: "t", url: "ftp://a.b/x").valid?
  end

  test "链接超过 2048 字符无效" do
    assert_not Adapters::Entry.new(title: "t", url: "https://a.b/" + "x" * 2048).valid?
  end
end
