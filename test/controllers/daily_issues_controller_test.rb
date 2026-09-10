require "test_helper"

class DailyIssuesControllerTest < ActionDispatch::IntegrationTest
  test "首页渲染最新一期" do
    get root_path
    follow_redirect!

    assert_response :success
    assert_includes response.body, "2026-09-08"
    assert_equal "2026-09-08", page_props.dig("issue", "period_key")
  end

  test "按周期键打开一期" do
    get daily_issue_path("2026-09-08")

    assert_response :success
    assert_includes response.body, "Show HN: A terminal log viewer written in Rust"
  end

  test "缺期显示本期未生成而不是 404" do
    get daily_issue_path("2026-09-03")

    assert_response :success
    assert_includes response.body, "本期未生成"
    assert page_props["missing"]
    # 期头小签与列表区那句事实句读的是同一个 status（附录 B 一句话两处用）
    assert_equal "本期未生成", page_props.dig("issue", "status")
    assert_nil page_props.dig("issue", "state")
  end

  test "非法周期键 404" do
    get daily_issue_path("nope")

    assert_response :not_found
  end

  # 形状对得上 PeriodKey::DAILY，但 2026 年没有 13 月 45 日：Date.iso8601 抛 Date::Error
  test "不存在的日期 404" do
    get daily_issue_path("2026-13-45")

    assert_response :not_found
  end

  test "source 深链决定默认来源" do
    get daily_issue_path("2026-09-08", source: sources(:github).id)

    assert_response :success
    assert_equal sources(:github).id, page_props["active_source_id"]
  end

  test "来源不在本期时回落到排序第一的源" do
    get daily_issue_path("2026-09-08", source: sources(:ruanyf).id)

    assert_equal sources(:hn).id, page_props["active_source_id"]
  end

  test "来源摘要带栏尾外链地址与上次成功时间" do
    get daily_issue_path("2026-09-08")

    summaries = page_props["sources"].index_by { |s| s["id"] }
    assert_equal %w[ ok failed failed ], page_props["sources"].map { |s| s["state"] }
    assert_equal "https://news.ycombinator.com/", summaries[sources(:hn).id]["home_url"]
    assert_equal "https://github.com/trending", summaries[sources(:github).id]["home_url"]
    assert_equal "https://hackaday.com/", summaries[sources(:hackaday).id]["home_url"]
    # fetch_runs(:hn_ok) 起于 2026-09-07 22:00 UTC，即上海 2026-09-08 06:00
    assert_equal "9月8日 06:00", summaries[sources(:hn).id]["last_ok_label"]
    assert_nil summaries[sources(:github).id]["last_ok_label"]
  end

  test "期头把附录 B 的状态文案算在服务端" do
    issues(:daily_0908).update!(revised_at: Time.utc(2026, 9, 7, 22, 42))

    get daily_issue_path("2026-09-08")

    issue = page_props["issue"]
    assert_equal "9月8日", issue["date_label"]
    assert_equal "星期二", issue["weekday"]
    assert_equal "06:12 发布", issue["time_label"]
    assert_equal "已于 06:42 修订", issue["status"]
    assert_equal "06:00", issue["daily_time"]
  end

  # PRD 5.1：HN 的评论数要链到讨论页，地址得先进 props（没有开 SSR）
  test "HN 条目的元数据带评论区地址" do
    get daily_issue_path("2026-09-08")

    row = page_props["items_by_source"].fetch(sources(:hn).id).first
    assert_equal "https://news.ycombinator.com/item?id=41000001", row.dig("meta", "comments_url")
  end

  test "条目按 rank 分到各自的来源，摘要截到 200 字" do
    long = "x" * 400
    items(:hn_one).update!(summary: long)

    get daily_issue_path("2026-09-08")

    rows = page_props["items_by_source"].fetch(sources(:hn).id)
    assert_equal [ "Show HN: A terminal log viewer written in Rust" ], rows.map { |r| r["title"] }
    assert_equal 200, rows.first["summary"].length
    assert_equal 312, rows.first.dig("meta", "score")
  end

  private
    # inertia_rails 的 use_script_element_for_initial_page 把整个 payload 渲染成
    # <script data-page="app" type="application/json"> 的文本内容（page.to_json.html_safe，没有 HTML 转义），
    # 没有开 SSR，所以页面上能读到的每个字符串都必须先出现在 props 里。
    def page_props
      JSON.parse(response.body[%r{<script data-page="app"[^>]*>(.*?)</script>}m, 1]).fetch("props")
    end
end
