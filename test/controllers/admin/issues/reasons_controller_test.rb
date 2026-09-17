require "test_helper"

class Admin::Issues::ReasonsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "整期重生成：入队 only_missing=false、记审计、提示" do
    with_model_provider do
      assert_enqueued_with(job: GenerateReasonsJob, args: [ issues(:daily_0908), false ]) { post admin_issue_reasons_path("2026-09-08") }
    end
    assert_redirected_to admin_issues_path
    assert_equal "2026-09-08 · 已开始重生成理由", flash[:notice]
    assert_equal "issue.regenerate_reasons", AuditLog.sole.action
  end

  test "没配供应商：提示未配置，不入队；周刊 404；成员 403" do
    assert_no_enqueued_jobs { post admin_issue_reasons_path("2026-09-08") }
    assert_equal "未配置模型供应商", flash[:alert]

    with_model_provider { post admin_issue_reasons_path("2026-W36") }
    assert_response :not_found

    sign_in_as(users(:guest))
    post admin_issue_reasons_path("2026-09-08")
    assert_response :forbidden
  end
end
