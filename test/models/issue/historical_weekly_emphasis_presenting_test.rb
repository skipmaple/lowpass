require "test_helper"

class Issue::HistoricalWeeklyEmphasisPresentingTest < ActiveSupport::TestCase
  test "历史强调只进入周刊阅读副本，已发布条目不变" do
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    item = items(:hn_one).dup
    item.update!(issue: issue, source: source, content: "介绍\n标题\n说明",
      meta: { issue_no: 416, image_urls: [ "https://cdn.example.com/cover.png" ] })
    image_index = Object.new
    emphasis_index = Object.new
    target_id = item.id
    image_index.define_singleton_method(:positions_for) { |item:, issue:, source:| item.id == target_id ? [ 1 ] : nil }
    emphasis_index.define_singleton_method(:positions_for) do |item:, issue:, source:, verified_image_positions:|
      item.id == target_id && verified_image_positions == [ 1 ] ? [ 1 ] : nil
    end
    HistoricalImagePositions.stubs(:current).returns(image_index)
    HistoricalWeeklyEmphasis.stubs(:current).returns(emphasis_index)
    ImageDimension.stubs(:enqueue_for)
    rows = nil

    assert_no_changes -> { [ item.reload.attributes, issue.reload.attributes, Favorite.count ] } do
      rows = issue.weekly_section_props.flat_map { |section| section[:groups].flat_map { |group| group[:items] } }
    end
    props = rows.find { |row| row[:id] == item.id }
    assert_equal [ 1 ], props[:meta]["emphasis_positions"]
    assert_equal [ 1 ], props[:meta]["image_positions"]
    assert_not item.reload.meta.key?("emphasis_positions")
  end
end
