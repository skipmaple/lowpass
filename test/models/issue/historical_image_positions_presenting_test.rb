require "test_helper"

class Issue::HistoricalImagePositionsPresentingTest < ActiveSupport::TestCase
  test "历史位置只进入周刊页面副本，不修改发布记录" do
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    item = items(:hn_one).dup
    item.update!(issue: issue, source: source, content: "介绍\n说明",
      meta: { issue_no: 416, image_urls: [ "https://cdn.example.com/cover.png" ] })
    index = Object.new
    target_id = item.id
    index.define_singleton_method(:positions_for) { |item:, issue:, source:| item.id == target_id ? [ 1 ] : nil }
    HistoricalImagePositions.stubs(:current).returns(index)
    ImageDimension.stubs(:enqueue_for)
    rows = nil

    assert_no_changes -> { [ item.reload.attributes, issue.reload.attributes, Favorite.count ] } do
      rows = issue.weekly_section_props.flat_map { |section| section[:groups].flat_map { |group| group[:items] } }
    end

    assert_equal [ 1 ], rows.find { |row| row[:id] == item.id }[:meta]["image_positions"]
    assert_not item.reload.meta.key?("image_positions")
  end
end
