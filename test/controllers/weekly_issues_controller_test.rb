require "test_helper"

# 周刊详情（PRD 5.2、R-2.5 到 R-2.7）。fixture 的 2026-W36 是 8月31日 至 9月6日 那一周。
class WeeklyIssuesControllerTest < ActionDispatch::IntegrationTest
  def ruanyf_item(title, section:, issue_no: 366, rank: 1, degraded: false, url: nil)
    issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: title, section: section, rank: rank, fetched_at: Time.current,
      url: url || "https://r.example/#{issue_no}/#{rank}", url_hash: Digest::SHA256.hexdigest("#{issue_no}/#{rank}"),
      meta: { issue_no: issue_no, issue_title: "慢下来的理由", degraded: degraded }
    )
  end

  test "周刊页按板块分节" do
    ruanyf_item("慢下来的理由", section: "本周话题")
    ruanyf_item("一个终端下的日志工具", section: "工具", rank: 2)

    get weekly_issue_path("2026-W36")

    assert_response :success
    assert_includes response.body, "本周话题"
    assert_includes response.body, "第 366 期"
    assert_equal [ "本周话题", "工具" ], page_props["sections"].sole["groups"].map { |group| group["name"] }
  end

  test "期头给出周次、年份与日期范围" do
    get weekly_issue_path("2026-W36")

    issue = page_props["issue"]
    assert_equal "第 36 周", issue["week_label"]
    assert_equal "8月31日 至 9月6日", issue["range_label"]
    assert_equal 2026, issue["year"]
    assert_equal "published", issue["state"]
  end

  test "源节头带源信息与原文地址" do
    ruanyf_item("慢下来的理由", section: "本周话题")

    get weekly_issue_path("2026-W36")

    section = page_props["sections"].sole
    assert_equal sources(:ruanyf).name, section.dig("source", "name")
    assert_equal 366, section["issue_no"]
    assert_equal "第 366 期 · 慢下来的理由", section["issue_label"]
    assert_equal "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md", section["original_url"]
    assert_not section["degraded"]
  end

  # R-2.3 降级：整期一条，页面给附录 B 那句加原文链接
  test "降级节标成 degraded" do
    ruanyf_item("科技爱好者周刊（第 366 期）：慢下来的理由", section: nil, degraded: true)

    get weekly_issue_path("2026-W36")

    assert page_props["sections"].sole["degraded"]
  end

  # R-2.7 那一周没有期不是 404：页头照常，正文只有一句
  test "没有期的周显示本周无内容" do
    get weekly_issue_path("2026-W01")

    assert_response :success
    assert_includes response.body, "本周无内容"
    assert_nil page_props.dig("issue", "state")
    assert_empty page_props["sections"]
  end

  test "非法周期键 404" do
    get weekly_issue_path("nope")

    assert_response :not_found
  end

  # 形状对得上 PeriodKey::WEEKLY，但没有第 99 周：Date.commercial 抛 Date::Error
  test "不存在的周 404" do
    get weekly_issue_path("2026-W99")

    assert_response :not_found
  end

  test "前后期取相邻的周刊期" do
    Issue.create!(kind: "weekly", period_key: "2026-W35", state: "published",
                  generation_started_at: Time.utc(2026, 8, 28, 1), published_at: Time.utc(2026, 8, 28, 1))

    get weekly_issue_path("2026-W36")

    assert_equal "2026-W35", page_props.dig("issue", "prev_key")
    assert_nil page_props.dig("issue", "next_key")
  end
end

# 周刊归档：按年一页，每周一行（PRD 6.2、R-2.7）。上海 2026-09-10 12:00 时本周是 2026-W37。
class WeeklyArchiveTest < ActionDispatch::IntegrationTest
  NOW = Time.utc(2026, 9, 10, 4)

  test "周刊归档标出无内容的周" do
    travel_to NOW do
      get weekly_issues_path

      assert_response :success
      assert_includes response.body, "本周无内容"
      assert_equal "2026 年", page_props["year_label"]
      assert_equal %w[ 2026-W37 2026-W36 ], page_props["weeks"].map { |week| week["period_key"] }
    end
  end

  test "早于最早一期的年份 404" do
    travel_to NOW do
      get weekly_issues_path(year: "2025")

      assert_response :not_found
    end
  end

  test "非法年份 404" do
    get weekly_issues_path(year: "nope")

    assert_response :not_found
  end
end
