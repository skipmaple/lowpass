require "test_helper"

# 9.1 search_click：查询词快照、名次、条目；90 天
class Search::ClickTest < ActiveSupport::TestCase
  test "记一次点击" do
    click = Search::Click.record(item_id: items(:hn_one).id, rank: 3, query: "terminal")

    assert_equal items(:hn_one), click.item
    assert_equal 3, click.rank
    assert_equal "terminal", click.query
  end

  test "不存在的条目不记" do
    assert_nil Search::Click.record(item_id: "nope", rank: 1, query: "x")
    assert_equal 0, Search::Click.count
  end

  test "exists? 之后条目被删也不报错" do
    Item.stubs(:exists?).returns(true)

    assert_nil Search::Click.record(item_id: "gone", rank: 1, query: "x")
    assert_equal 0, Search::Click.count
  end

  test "条目删了点击随外键级联消失" do
    Search::Click.record(item_id: items(:hn_one).id, rank: 1, query: "x")
    items(:hn_one).delete

    assert_equal 0, Search::Click.count
  end

  test "cleanup 删掉 90 天前的点击" do
    travel_to(91.days.ago) { Search::Click.record(item_id: items(:hn_one).id, rank: 1, query: "old") }
    travel_to(89.days.ago) { Search::Click.record(item_id: items(:hn_one).id, rank: 1, query: "recent") }

    Search::Click.cleanup

    assert_equal [ "recent" ], Search::Click.pluck(:query)
  end
end
