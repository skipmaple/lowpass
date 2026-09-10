require "test_helper"

# 查询解析（R-4.1、R-4.5、设计 5.1）：拆词、门槛、截断、去重、筛选参数的合法性
class Search::QueryTest < ActiveSupport::TestCase
  def terms(q) = Search::Query.parse(q: q).terms.map { |term| [ term.text, term.kind ] }

  test "拉丁词按空白切开、小写；标点与全半角差异忽略" do
    assert_equal [ [ "kuber", :latin ], [ "rust", :latin ] ], terms("Kuber  Rust")
    assert_equal [ [ "kuber", :latin ], [ "rust", :latin ] ], terms("Ｋｕｂｅｒ，ｒｕｓｔ。")
    assert_equal [ [ "node", :latin ], [ "js", :latin ] ], terms("node.js")
  end

  test "中文串拆二元组，长度 1 的串本身是一个词，空格分开的各自成词" do
    assert_equal [ [ "终端", :cjk ], [ "端工", :cjk ], [ "工具", :cjk ] ], terms("终端工具")
    assert_equal [ [ "终端", :cjk ], [ "工具", :cjk ] ], terms("终端 工具")
    assert_equal [ [ "端", :cjk ] ], terms("端")
  end

  test "混合片段按脚本拆开" do
    assert_equal [ [ "rust", :latin ], [ "语言", :cjk ] ], terms("Rust语言")
  end

  test "R-4.1 长度门槛：拉丁词至少 2 字符" do
    assert_equal [ [ "b2", :latin ] ], terms("a 1 b2")
  end

  test "空查询、只有空白与标点都是 blank，不搜索" do
    assert Search::Query.parse(q: "").blank?
    assert Search::Query.parse(q: "  ").blank?
    assert Search::Query.parse(q: "，。 ,,").blank?
    assert Search::Query.parse({}).blank?
  end

  test "超过 100 字符截断并标记" do
    query = Search::Query.parse(q: "k" * 120)

    assert query.truncated?
    assert_equal 100, query.q.length
    assert_not Search::Query.parse(q: "k" * 100).truncated?
  end

  test "q 保留读者的原文（去首尾空白），归一化只用于拆词" do
    assert_equal "Ｋｕｂｅｒ", Search::Query.parse(q: " Ｋｕｂｅｒ ").q
  end

  test "词去重，最多保留 8 个" do
    assert_equal [ [ "go", :latin ], [ "rust", :latin ] ], terms("go go rust rust")
    assert_equal 8, Search::Query.parse(q: (1..9).map { |i| "w#{i}" }.join(" ")).terms.size
  end

  test "type 只认 daily / weekly" do
    assert_equal "weekly", Search::Query.parse(q: "x", type: "weekly").type
    assert_nil Search::Query.parse(q: "x", type: "monthly").type
    assert_nil Search::Query.parse(q: "x").type
  end

  test "source 是逗号分隔的源 id，只保留库里存在的，顺序照给" do
    ids = "#{sources(:ruanyf).id},nope,#{sources(:hn).id}"
    assert_equal [ sources(:ruanyf).id, sources(:hn).id ], Search::Query.parse(q: "x", source: ids).sources
    assert_equal [], Search::Query.parse(q: "x").sources
  end

  test "from / to 只认合法的 YYYY-MM-DD，from 晚于 to 时互换" do
    query = Search::Query.parse(q: "x", from: "2026-09-30", to: "2026-09-01")
    assert_equal Date.new(2026, 9, 1), query.from
    assert_equal Date.new(2026, 9, 30), query.to

    assert_nil Search::Query.parse(q: "x", from: "2026-13-45").from
    assert_nil Search::Query.parse(q: "x", from: "yesterday").from
  end

  test "range 只认四个预设；没给时有日期就是 custom，否则 all" do
    assert_equal "7d", Search::Query.parse(q: "x", range: "7d").range
    assert_equal "custom", Search::Query.parse(q: "x", from: "2026-09-01").range
    assert_equal "all", Search::Query.parse(q: "x", range: "1y").range
    assert_equal "all", Search::Query.parse(q: "x").range
  end

  test "page 只认 1 到 50，其余当 1" do
    assert_equal 7, Search::Query.parse(q: "x", page: "7").page
    assert_equal 1, Search::Query.parse(q: "x", page: "0").page
    assert_equal 1, Search::Query.parse(q: "x", page: "51").page
    assert_equal 1, Search::Query.parse(q: "x", page: "two").page
    assert_equal 1, Search::Query.parse(q: "x").page
  end

  test "sort 只认 relevance / date，默认 relevance" do
    assert_equal "date", Search::Query.parse(q: "x", sort: "date").sort
    assert_equal "relevance", Search::Query.parse(q: "x", sort: "score").sort
    assert_equal "relevance", Search::Query.parse(q: "x").sort
  end

  # ?q[]=… 这类参数让值变成数组或哈希：不是字符串就当没给
  test "数组参数当没给" do
    assert Search::Query.parse(q: [ "kuber" ]).blank?
    assert_equal 1, Search::Query.parse(q: "x", page: [ "2" ]).page
  end

  test "filters 与 log_filters 的形状" do
    query = Search::Query.parse(q: "x", type: "daily", source: sources(:hn).id, from: "2026-09-01", sort: "date", page: "2")

    assert_equal({ type: "daily", sources: [ sources(:hn).id ], from: "2026-09-01", to: nil, range: "custom", sort: "date" }, query.filters)
    assert_equal({ "type" => "daily", "source" => [ sources(:hn).id ], "from" => "2026-09-01", "to" => nil, "sort" => "date" }, query.log_filters)
    assert query.frozen?
  end
end
