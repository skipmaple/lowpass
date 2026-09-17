require "test_helper"

class Admin::IssuesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "期列表：当月、汇总、今日日刊是否已存在、轮询数据" do
    travel_to Time.utc(2026, 9, 9, 4) do
      get admin_issues_path
    end

    assert_equal "Admin/Issues/Index", page_component
    assert_equal "2026 年 9 月", page_props["month_label"]
    assert_equal "all", page_props["kind"]
    assert page_props["rows"].any? { |r| r["period_key"] == "2026-09-08" && r["state"] == "published" }
    assert page_props["rows"].any? { |r| r["period_key"] == "2026-W36" }
    assert_equal "2026-09-09", page_props["today_period_key"]
    assert_equal false, page_props["today_issue_exists"]
    assert_equal [], page_props["active_runs"]
  end

  test "浏览历史月份仍报告今天的生成状态" do
    Issue.create!(kind: "daily", period_key: "2026-08-31", state: "empty", generation_started_at: Time.utc(2026, 8, 31))
    issues(:daily_0908).update_columns(state: "generating", published_at: nil)
    travel_to Time.utc(2026, 9, 8, 4) do
      get admin_issues_path(month: "2026-08")
    end

    assert_equal "generating", page_props["today_issue_state"]
    assert_equal true, page_props["today_issue_exists"]
    assert page_props["rows"].none? { |row| row["period_key"] == "2026-09-08" }
  end

  test "筛选与翻月" do
    travel_to Time.utc(2026, 9, 9, 4) do
      get admin_issues_path(kind: "weekly", month: "2026-09")
    end

    assert page_props["rows"].all? { |r| r["kind"] == "weekly" }
    assert_equal "weekly", page_props["kind"]
  end

  test "历史月份和刊物类型同时保留在列表上下文" do
    Issue.daily.create!(period_key: "2025-12-31", state: "published", published_at: Time.utc(2025, 12, 30, 22), generation_started_at: Time.utc(2025, 12, 30, 21))

    travel_to Time.utc(2026, 9, 9, 4) do
      %w[ all daily weekly ].each do |kind|
        get admin_issues_path(kind: kind, month: "2025-12")
        assert_response :success
        assert_equal "2025-12", page_props["month"]
        assert_equal "2025 年 12 月", page_props["month_label"]
        assert_equal kind, page_props["kind"]
      end
    end
  end

  test "越界的月份 404" do
    travel_to Time.utc(2026, 9, 9, 4) do
      get admin_issues_path(month: "2027-01")
    end

    assert_response :not_found
    assert_equal "Errors/NotFound", page_component
  end

  # ?month[]=… 让 params[:month] 变成 Array，Date.strptime 会抛 TypeError 而不是 Date::Error
  # （日刊归档同样挡过这一手，见 DailyIssuesController#requested_month）
  test "月份参数不是字符串也只是 404" do
    get admin_issues_path(month: [ "2026-09" ])

    assert_response :not_found
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    get admin_issues_path
    assert_response :forbidden
  end
end
