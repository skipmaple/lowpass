require "test_helper"

# 搜索页的 props 契约（设计 6.2）与 AC-4.5 / 4.6 / 4.7
class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:drew))
    Rails.cache.clear
    @item = index_item("Kubernetes operator in Rust", summary: "Build a Kubernetes operator with the Rust SDK")
  end

  test "空查询是 initial 态：筛选器、来源选项与最新日刊入口" do
    get search_path

    assert_response :success
    assert_equal "Search/Show", page_component
    assert_equal "initial", page_props["state"]
    assert_equal "", page_props["q"]
    assert_equal [], page_props["results"]
    assert_equal "2026-09-08", page_props["latest_daily_key"]
    assert_equal "9月8日", page_props["latest_daily_label"]
    assert_equal [ "Hacker News", "GitHub Trending", "Hackaday", "阮一峰科技爱好者周刊" ], page_props["source_options"].map { |option| option["name"] }
    assert_equal %w[ 7d 30d ], page_props["date_presets"].keys
    assert_equal "06:00", page_props["daily_time"]
    assert_nil page_props["latest_weekly_key"]
  end

  test "只有标点也不搜索、不写日志" do
    get search_path(q: "，。")

    assert_equal "initial", page_props["state"]
    assert_equal 0, Search::Log.count
  end

  test "有结果：条目带高亮 run、所在期链接、原文与刊物" do
    get search_path(q: "kuber rust")

    assert_equal "results", page_props["state"]
    assert_equal 1, page_props["total"]
    assert_equal 1, page_props["pages"]
    entry = page_props["results"].sole
    assert_equal @item.id, entry["item_id"]
    assert_equal 1, entry["rank"]
    assert_equal "daily", entry["publication"]
    assert_equal "Hacker News", entry["source_name"]
    assert_equal "9月8日", entry["where"]["label"]
    assert_equal daily_issue_path("2026-09-08", source: sources(:hn).id, anchor: "item-#{@item.id}"), entry["where"]["href"]
    assert_equal "9月8日", entry["published_label"]
    assert_equal @item.url, entry["url"]
    assert_equal [ [ "Kuber", true ], [ "netes operator in ", false ], [ "Rust", true ] ], entry["title_runs"].map { |run| [ run["text"], run["hit"] ] }
    assert entry["snippet_runs"].any? { |run| run["hit"] }
  end

  test "周刊条目的所在期落到周刊页的板块锚点" do
    weekly = index_item("Rust weekly note", issue: issues(:weekly_w36), source: sources(:ruanyf), section: "工具",
                        meta: { "issue_no" => 366, "anchor" => "工具" })

    get search_path(q: "rust", type: "weekly")

    entry = page_props["results"].sole
    assert_equal weekly.id, entry["item_id"]
    assert_equal "第 36 周 · 工具", entry["where"]["label"]
    assert_equal weekly_issue_path("2026-W36", anchor: "issue-366-工具"), entry["where"]["href"]
    assert_nil entry["snippet_runs"]
  end

  test "RSS 周刊条目的所在期落到源节头" do
    feed = Source.create!(name: "命令行周报", adapter: "rss", publication: "weekly", sort_order: 2, config: { feed_url: "https://w.example/feed" })
    weekly = index_item("Rust in a feed weekly", issue: issues(:weekly_w36), source: feed, published_at: Time.utc(2026, 9, 3, 4))

    get search_path(q: "rust", type: "weekly")

    entry = page_props["results"].sole
    assert_equal weekly.id, entry["item_id"]
    assert_equal "第 36 周", entry["where"]["label"]
    assert_equal weekly_issue_path("2026-W36", anchor: "source-#{feed.id}"), entry["where"]["href"]
  end

  test "AC-4.7 地址参数往返：关键词与全部筛选恢复" do
    get search_path(q: "kuber", type: "daily", source: sources(:hn).id, from: "2026-09-01", to: "2026-09-30", range: "custom", sort: "date", page: 1)

    assert_equal "kuber", page_props["q"]
    assert_equal({ "type" => "daily", "sources" => [ sources(:hn).id ], "from" => "2026-09-01", "to" => "2026-09-30", "range" => "custom", "sort" => "date" }, page_props["filters"])
    assert_equal "results", page_props["state"]
  end

  test "AC-4.5 无结果是 empty 态" do
    get search_path(q: "量子咖啡机")

    assert_equal "empty", page_props["state"]
    assert_equal 0, page_props["total"]
    assert_equal 0, page_props["pages"]
    assert_equal [], page_props["results"]
  end

  # R-4.7：页码合法但超过总页数（分享的地址、结果变少）时不渲染一页空结果，跳到最后一页，其余参数原样带上
  test "页码超过总页数时跳到最后一页" do
    25.times { |i| index_item("Rust item #{i}") }

    # script_name 是 url_for 的保留键：原样转发读者的参数就会拼出协议相对地址（开放跳转），所以这里故意带上它
    get "/search?q=rust&page=5&sort=date&script_name=%2F%2Fevil.example"

    # 地址由解析过的字段重建（range、sort 也带上），不是把读者给的参数原样转发
    assert_redirected_to search_path(q: "rust", range: "all", sort: "date", page: 2)
    follow_redirect!
    assert_equal "results", page_props["state"]
    assert_equal 2, page_props["page"]
    assert_equal 2, page_props["pages"]
  end

  test "超过 100 字截断并标记" do
    get search_path(q: "k" * 120)

    assert page_props["truncated"]
    assert_equal 100, page_props["q"].length
  end

  test "AC-4.6 一分钟内第 61 次请求限流：429 的 limited 态，不写日志，一分钟后恢复" do
    60.times { get search_path(q: "kuber") }
    assert_response :success

    get search_path(q: "kuber")

    assert_response :too_many_requests
    assert_equal "limited", page_props["state"]
    assert_equal "kuber", page_props["q"]
    assert_equal 60, Search::Log.count

    travel 61.seconds do
      get search_path(q: "kuber")
      assert_response :success
    end
  end

  # R-4.10 按用户计数：一个人用光了额度不影响另一个人
  test "限流按用户算，不按 IP" do
    60.times { get search_path(q: "kuber") }
    get search_path(q: "kuber")
    assert_response :too_many_requests

    delete session_path
    sign_in_as(users(:guest))
    get search_path(q: "kuber")

    assert_response :success
  end

  test "每次执行的搜索写一行日志" do
    get search_path(q: "kuber", type: "daily", page: 1)

    log = Search::Log.sole
    assert_equal "kuber", log.query
    assert_equal 1, log.result_count
    assert_equal({ "type" => "daily", "source" => [], "from" => nil, "to" => nil, "sort" => "relevance" }, log.filters)
    assert_equal 1, log.page
    assert_operator log.latency_ms, :>=, 0
  end

  test "搜索不可用时是 unavailable 态，仍是 200，日志的结果数为空" do
    Search::Runner.any_instance.stubs(:run).raises(ActiveRecord::QueryCanceled, "statement timeout")

    get search_path(q: "kuber")

    assert_response :success
    assert_equal "unavailable", page_props["state"]
    assert_nil Search::Log.sole.result_count
  end
end
