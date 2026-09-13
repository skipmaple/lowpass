require "test_helper"

class Search::ClicksControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "记一次点击并返回 204" do
    post search_clicks_path, params: { item_id: items(:hn_one).id, rank: 3, q: "terminal" }, as: :json

    assert_response :no_content
    click = Search::Click.sole
    assert_equal items(:hn_one), click.item
    assert_equal 3, click.rank
    assert_equal "terminal", click.query
  end

  test "不存在的条目不记也不报错" do
    post search_clicks_path, params: { item_id: "nope", rank: 1, q: "x" }, as: :json

    assert_response :no_content
    assert_equal 0, Search::Click.count
  end

  test "名次与查询词的非法值被收敛" do
    post search_clicks_path, params: { item_id: items(:hn_one).id, rank: "-5", q: "x" * 300 }, as: :json

    click = Search::Click.sole
    assert_equal 1, click.rank
    assert_equal 100, click.query.length
  end

  test "一分钟 60 次以上回 429" do
    60.times { post search_clicks_path, params: { item_id: "nope", rank: 1, q: "x" }, as: :json }
    post search_clicks_path, params: { item_id: "nope", rank: 1, q: "x" }, as: :json

    assert_response :too_many_requests
  end
end
