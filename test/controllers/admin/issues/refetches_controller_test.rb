require "test_helper"

# R-3.10 某期某源重抓：入队一个手动任务，进行中的不重复入队
class Admin::Issues::RefetchesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "入队、审计、flash" do
    assert_enqueued_with(job: FetchSourceJob, args: [ sources(:hn), issues(:daily_0908), "manual", false ]) do
      post admin_issue_refetch_path("2026-09-08"), params: { source_id: sources(:hn).id }, headers: { "Referer" => admin_issues_path }
    end

    assert_redirected_to admin_issues_path
    assert_equal "正在重抓 Hacker News…", flash[:notice]
    log = AuditLog.sole
    assert_equal "issue.refetch", log.action
    assert_equal "Issue#2026-09-08", log.target
    assert_equal({ "source_id" => sources(:hn).id, "source_name" => "Hacker News" }, log.payload)
  end

  test "已在进行中就不再入队" do
    sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "running", started_at: Time.current)

    assert_no_enqueued_jobs do
      post admin_issue_refetch_path("2026-09-08"), params: { source_id: sources(:hn).id }
    end

    assert_redirected_to admin_issues_path
    assert_equal "正在重抓 Hacker News…", flash[:notice]
    assert_equal 0, AuditLog.count
  end

  test "周刊期也能重抓" do
    assert_enqueued_with(job: FetchSourceJob, args: [ sources(:ruanyf), issues(:weekly_w36), "manual", false ]) do
      post admin_issue_refetch_path("2026-W36"), params: { source_id: sources(:ruanyf).id }
    end
  end

  test "不属于这一期的源 404" do
    post admin_issue_refetch_path("2026-09-08"), params: { source_id: sources(:ruanyf).id }

    assert_response :not_found
  end

  test "没有这一期 404" do
    post admin_issue_refetch_path("2026-09-01"), params: { source_id: sources(:hn).id }

    assert_response :not_found
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    post admin_issue_refetch_path("2026-09-08"), params: { source_id: sources(:hn).id }
    assert_response :forbidden
  end
end
