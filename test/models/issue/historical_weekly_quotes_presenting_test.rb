require "test_helper"

class Issue::HistoricalWeeklyQuotesPresentingTest < ActiveSupport::TestCase
  test "历史引用仅进入周刊展示副本，正文和收藏不变" do
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    item = items(:hn_one).dup
    item.update!(issue: issue, source: source, content: "介绍\n> 引用\n>\n> 第二段",
      meta: { issue_no: 415, image_urls: [ "https://cdn.example.com/cover.png" ] })
    index = Object.new
    target_id = item.id
    index.define_singleton_method(:ranges_for) { |item:, issue:, source:| item.id == target_id ? [ [ 1, 4 ] ] : nil }
    HistoricalWeeklyQuotes.stubs(:current).returns(index)
    ImageDimension.stubs(:enqueue_for)
    rows = nil

    assert_no_changes -> { [ item.reload.attributes, issue.reload.attributes, Favorite.count ] } do
      rows = issue.weekly_section_props.flat_map { |section| section[:groups].flat_map { |group| group[:items] } }
    end
    assert_equal [ [ 1, 4 ] ], rows.find { |row| row[:id] == item.id }[:meta]["quote_ranges"]
    assert_not item.reload.meta.key?("quote_ranges")
  end

  test "正文分段重建后不沿用旧正文的引用与强调位置" do
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    item = items(:hn_one).dup
    item.update!(issue: issue, source: source, content: "甲 乙",
      meta: { issue_no: 415, quote_ranges: [ [ 0, 1 ] ], emphasis_positions: [ 0 ] })
    index = Object.new
    target_id = item.id
    index.define_singleton_method(:content_for) { |item:, issue:, source:, meta:| item.id == target_id ? "甲\n乙" : nil }
    HistoricalParagraphBoundaries.stubs(:current).returns(index)
    ImageDimension.stubs(:enqueue_for)
    rows = issue.weekly_section_props.flat_map { |section| section[:groups].flat_map { |group| group[:items] } }
    props = rows.find { |row| row[:id] == item.id }
    assert_equal "甲\n乙", props[:content]
    assert_not props[:meta].key?("quote_ranges")
    assert_not props[:meta].key?("emphasis_positions")
    assert item.reload.meta.key?("quote_ranges")
  end
end
