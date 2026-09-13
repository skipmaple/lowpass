require "test_helper"

# D12：明文查询词、不关联用户、30 天
class Search::LogTest < ActiveSupport::TestCase
  test "记一次搜索：查询词、筛选、结果数、延迟、页码" do
    query = Search::Query.parse(q: "kuber", type: "daily", page: "2")
    result = Search::Result.new(entries: [], total: 3, page: 2, latency_ms: 12, status: "ok")

    log = Search::Log.record(query, result)

    assert_equal "kuber", log.query
    assert_equal({ "type" => "daily", "source" => [], "from" => nil, "to" => nil, "sort" => "relevance" }, log.filters)
    assert_equal 3, log.result_count
    assert_equal 12, log.latency_ms
    assert_equal 2, log.page
    assert log.created_at
  end

  test "不可用态也记，result_count 为空" do
    result = Search::Result.new(entries: [], total: 0, page: 1, latency_ms: 501, status: "timeout")

    assert_nil Search::Log.record(Search::Query.parse(q: "kuber"), result).result_count
  end

  test "cleanup 删掉 30 天前的日志，分批" do
    result = Search::Result.new(entries: [], total: 0, page: 1, latency_ms: 1, status: "ok")
    travel_to(31.days.ago) { 3.times { Search::Log.record(Search::Query.parse(q: "old"), result) } }
    travel_to(29.days.ago) { Search::Log.record(Search::Query.parse(q: "recent"), result) }

    Search::Log.cleanup(batch_size: 2)

    assert_equal [ "recent" ], Search::Log.pluck(:query)
  end
end
