require "test_helper"
require "digest"
require "json"

class HistoricalWeeklyQuotesTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:weekly_w36)
    @source = sources(:ruanyf)
    @item = Item.new(id: Lowpass::Uuid.generate, issue: @issue, source: @source, rank: 2,
      title: "文章", url: "https://example.com/story", section: "文章",
      content: "介绍。\n> 引用。\n>\n> 下一段。", meta: { "issue_no" => 415, "image_urls" => [ "https://example.com/a.webp" ] })
    identity = [ @issue.period_key, @source.adapter, 415, @issue.id, @source.id, @item.id, @item.rank, @item.title,
      @item.url, @item.section, Digest::SHA256.hexdigest(@item.content), Digest::SHA256.hexdigest(JSON.generate(@item.meta["image_urls"])) ]
    @index = HistoricalWeeklyQuotes.new(entries: { Digest::SHA256.hexdigest(JSON.generate(identity)) => [ [ 1, 4 ] ] })
  end

  test "完全匹配时仅返回引用位置，不更改记录" do
    before = @item.attributes.deep_dup
    assert_no_changes -> { [ Item.count, Issue.count, Favorite.count ] } do
      assert_equal [ [ 1, 4 ] ], @index.ranges_for(item: @item, issue: @issue, source: @source)
    end
    assert_equal before, @item.attributes
  end

  test "正文、身份、图片或已有引用元数据变化时回退" do
    { "id" => Lowpass::Uuid.generate, "title" => "另一篇", "content" => "改变正文", "url" => "https://example.com/other" }.each do |attribute, value|
      original = @item.public_send(attribute)
      @item.public_send("#{attribute}=", value)
      assert_nil @index.ranges_for(item: @item, issue: @issue, source: @source), attribute
      @item.public_send("#{attribute}=", original)
    end
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/other.webp" ])
    assert_nil @index.ranges_for(item: @item, issue: @issue, source: @source)
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/a.webp" ], "quote_ranges" => nil)
    assert_nil @index.ranges_for(item: @item, issue: @issue, source: @source)
    @item.meta = @item.meta.except("quote_ranges")
    @issue.state = "generating"
    assert_nil @index.ranges_for(item: @item, issue: @issue, source: @source)
  end
end
