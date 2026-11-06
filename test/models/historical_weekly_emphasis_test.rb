require "test_helper"
require "digest"

class HistoricalWeeklyEmphasisTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:weekly_w36)
    @source = sources(:ruanyf)
    @item = Item.new(id: Lowpass::Uuid.generate, issue: @issue, source: @source, rank: 2,
      title: "文章", url: "https://example.com/story", section: "文章",
      content: "开场。\n标题。\n说明。", meta: { "issue_no" => 416, "image_urls" => [ "https://example.com/a.webp" ] })
    key = [ @issue.period_key, 416, 2, Digest::SHA256.hexdigest(@item.content), [ 1 ] ]
    @index = HistoricalWeeklyEmphasis.new(entries: { key => [ 1 ] })
  end

  test "只在严格核对图片身份和正文后返回强调位置，不更改任何记录" do
    before = @item.attributes.deep_dup
    assert_no_changes -> { [ Item.count, Issue.count, Favorite.count ] } do
      assert_equal [ 1 ], @index.positions_for(item: @item, issue: @issue, source: @source, verified_image_positions: [ 1 ])
    end
    assert_equal before, @item.attributes
  end

  test "身份、正文、原图证明或已有强调位置变化时回退" do
    assert_nil @index.positions_for(item: @item, issue: @issue, source: @source, verified_image_positions: nil)
    assert_nil @index.positions_for(item: @item, issue: @issue, source: @source, verified_image_positions: [ 0 ])
    @item.content = "开场。\n别的标题。\n说明。"
    assert_nil @index.positions_for(item: @item, issue: @issue, source: @source, verified_image_positions: [ 1 ])
    @item.content = "开场。\n标题。\n说明。"
    @item.meta = @item.meta.merge("emphasis_positions" => nil)
    assert_nil @index.positions_for(item: @item, issue: @issue, source: @source, verified_image_positions: [ 1 ])
    @item.meta = @item.meta.except("emphasis_positions")
    @source.adapter = "rss"
    assert_nil @index.positions_for(item: @item, issue: @issue, source: @source, verified_image_positions: [ 1 ])
    @source.adapter = "ruanyf_weekly"
    @issue.state = "generating"
    assert_nil @index.positions_for(item: @item, issue: @issue, source: @source, verified_image_positions: [ 1 ])
  end
end
