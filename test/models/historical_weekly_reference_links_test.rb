require "test_helper"
require "digest"
require "json"

class HistoricalWeeklyReferenceLinksTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:weekly_w36)
    @source = sources(:ruanyf)
    @item = Item.new(id: Lowpass::Uuid.generate, issue: @issue, source: @source, rank: 2,
      title: "文章", url: "https://example.com/story", section: "文章",
      content: "查看代码。", meta: { "issue_no" => 415, "image_urls" => [ "https://example.com/a.webp" ] })
    identity = [ @issue.period_key, @source.adapter, 415, @issue.id, @source.id, @item.id, @item.rank, @item.title,
      @item.url, @item.section, Digest::SHA256.hexdigest(@item.content), Digest::SHA256.hexdigest(JSON.generate(@item.meta["image_urls"])) ]
    @index = HistoricalWeeklyReferenceLinks.new(entries: { Digest::SHA256.hexdigest(JSON.generate(identity)) => [ [ 0, 2, 4, "https://example.com/code" ] ] })
  end

  test "身份和正文完全匹配才提供链接，不更改原记录" do
    original = @item.attributes.deep_dup
    returned = @index.links_for(item: @item, issue: @issue, source: @source)
    assert_equal [ [ 0, 2, 4, "https://example.com/code" ] ], returned
    returned.first.last.replace("https://example.com/changed")
    assert_equal "https://example.com/code", @index.links_for(item: @item, issue: @issue, source: @source).first.last
    assert_equal original, @item.attributes
    @item.content = "查看正文。"
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
  end

  test "来源、图片或既有链接位置发生变化则回退" do
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/other.webp" ])
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/a.webp" ], "reference_links" => nil)
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
    @item.meta = @item.meta.except("reference_links")
    @issue.state = "generating"
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
  end
end
