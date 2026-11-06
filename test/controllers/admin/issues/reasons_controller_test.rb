require "test_helper"

class Admin::Issues::ReasonsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "整期重生成：入队 only_missing=false、记审计、提示" do
    with_model_provider do
      assert_enqueued_with(job: GenerateReasonsJob, args: [ issues(:daily_0908), false ]) { post admin_issue_reasons_path("2026-09-08") }
    end
    assert_redirected_to admin_issues_path
    assert_equal "2026-09-08 · 理由任务已排队，进度会自动更新", flash[:notice]
    assert_equal "issue.regenerate_reasons", AuditLog.sole.action
  end

  test "同一期已有理由任务时不重复入队或重复记审计" do
    Reasons::Progress.stubs(:active?).with(issues(:daily_0908)).returns(true)
    with_model_provider do
      assert_no_enqueued_jobs { post admin_issue_reasons_path("2026-09-08") }
    end
    assert_equal "2026-09-08 · 理由任务已在处理中，请等待进度更新", flash[:notice]
    assert_equal 0, AuditLog.count
  end

  test "任务未入队时不宣称已经开始或已经在处理中" do
    GenerateReasonsJob.stubs(:perform_later).returns(false)
    with_model_provider { post admin_issue_reasons_path("2026-09-08") }
    assert_equal "理由任务未能入队，请重试。", flash[:alert]
    assert_equal 0, AuditLog.count
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
