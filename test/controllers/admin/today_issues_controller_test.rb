require "test_helper"

# R-3.11 立即生成今日日刊：无期就生成；已有期要确认，然后对所有来源重抓
class Admin::TodayIssuesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "今天没有期：生成，标延迟" do
    travel_to Time.utc(2026, 9, 9, 4) do
      assert_difference -> { Issue.daily.count }, 1 do
        post admin_today_issue_path
      end
    end

    assert_redirected_to admin_issues_path
    assert_equal "已开始生成今日日刊", flash[:notice]
    issue = Issue.daily.find_by!(period_key: "2026-09-09")
    assert issue.generated_late
    assert_equal "issue.generate_today", AuditLog.sole.action
  end

  test "今天已有期：没确认只提示" do
    travel_to Time.utc(2026, 9, 7, 22, 30) do   # 上海 9月8日 06:30
      assert_no_enqueued_jobs do
        post admin_today_issue_path
      end
    end

    assert_equal "今日日刊已存在", flash[:alert]
  end

  test "今天已有期：确认后对所有来源重抓" do
    travel_to Time.utc(2026, 9, 7, 22, 30) do
      assert_enqueued_jobs 3, only: FetchSourceJob do
        post admin_today_issue_path, params: { confirm: "1" }
      end
    end

    assert_equal "正在重抓 3 个来源…", flash[:notice]
    assert_equal "issue.generate_today", AuditLog.sole.action
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    post admin_today_issue_path
    assert_response :forbidden
  end
end
