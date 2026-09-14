require "test_helper"

# R-1.6 补生成缺期
class Admin::Issues::BackfillsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "过去的日子走回填" do
    Issue.expects(:backfill_daily!).with("2026-09-03").returns(Issue.new(period_key: "2026-09-03"))

    travel_to Time.utc(2026, 9, 9, 4) do
      post admin_issue_backfill_path("2026-09-03")
    end

    assert_redirected_to admin_issues_path
    assert_equal "已补生成 2026-09-03，正在抓取", flash[:notice]
    assert_equal "issue.backfill", AuditLog.sole.action
  end

  test "今天走立即生成" do
    Issue.expects(:generate_daily!).with("2026-09-09", late: true, trigger: "manual").returns(Issue.new(period_key: "2026-09-09"))

    travel_to Time.utc(2026, 9, 9, 4) do   # 上海 12:00，已过 06:00
      post admin_issue_backfill_path("2026-09-09")
    end

    assert_equal "已开始生成今日日刊", flash[:notice]
  end

  test "已有期与未来的日子被拒绝" do
    travel_to Time.utc(2026, 9, 9, 4) do
      post admin_issue_backfill_path("2026-09-08")
      assert_equal "这一天已有期", flash[:alert]

      post admin_issue_backfill_path("2026-09-10")
      assert_equal "还没到这一天", flash[:alert]
    end
    assert_equal 0, AuditLog.count
  end

  test "还没到生成时间的今天不标延迟" do
    Issue.expects(:generate_daily!).with("2026-09-09", late: false, trigger: "manual").returns(Issue.new(period_key: "2026-09-09"))

    travel_to Time.utc(2026, 9, 8, 20, 30) do   # 上海 9月9日 04:30，还没到 06:00
      post admin_issue_backfill_path("2026-09-09")
    end

    assert_equal "已开始生成今日日刊", flash[:notice]
  end

  # 缺期几乎总在过去的月份页上：补生成之后该回那一页，不是弹回本月
  test "回到来路" do
    Issue.expects(:backfill_daily!).with("2026-08-20").returns(Issue.new(period_key: "2026-08-20"))

    travel_to Time.utc(2026, 9, 9, 4) do
      post admin_issue_backfill_path("2026-08-20"), headers: { "Referer" => admin_issues_path(month: "2026-08") }
    end

    assert_redirected_to admin_issues_path(month: "2026-08")
  end

  test "周刊键 404" do
    post admin_issue_backfill_path("2026-W40")

    assert_response :not_found
    assert_equal "Errors/NotFound", page_component
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    post admin_issue_backfill_path("2026-09-03")
    assert_response :forbidden
  end
end
