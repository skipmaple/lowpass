require "test_helper"

class Admin::Issues::TranslationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "只读预览，重复POST同键入队且范围不扩大" do
    with_model_provider do
      assert_no_difference([ "ModelCall.count", "AuditLog.count" ]) { get new_admin_issue_translations_path("2026-09-08") }
      assert_response :success
      preview = response.parsed_body
      assert_equal 1, preview.fetch("target_count")
      extra = Item.create!(items(:hn_one).attributes.except("id").merge("url_hash" => "b" * 64, "title" => "New English item"))
      2.times { post admin_issue_translations_path("2026-09-08"), params: { token: preview.fetch("token") } }
      jobs = enqueued_jobs.select { |job| job[:job] == GenerateTranslationsJob }
      assert_equal 2, jobs.size
      assert_equal jobs.first[:args], jobs.last[:args]
      payload = ActiveJob::Arguments.deserialize(jobs.first[:args]).last
      assert_equal [ items(:hn_one).id ], payload.fetch("targets").map { |target| target.fetch("item_id") }
      assert_not_includes payload.fetch("targets").map { |target| target.fetch("item_id") }, extra.id
      assert_equal "已提交译文补全任务，刷新查看结果", flash[:notice]
      assert_equal [ "issue.complete_translations" ], AuditLog.distinct.pluck(:action)
      assert_equal 1, AuditLog.last.payload.fetch("target_count")
    end
  end

  test "伪造过期跨期成员周刊空刊与未配置均拒绝" do
    with_model_provider do
      get new_admin_issue_translations_path("2026-09-08")
      token = response.parsed_body.fetch("token")
      assert_no_enqueued_jobs { post admin_issue_translations_path("2026-09-08"), params: { token: token + "bad" } }
      assert_match(/预览已失效/, flash[:alert])
      travel 16.minutes do
        assert_no_enqueued_jobs { post admin_issue_translations_path("2026-09-08"), params: { token: token } }
      end
      get new_admin_issue_translations_path("2026-W36")
      assert_response :not_found
      issues(:daily_0908).update!(state: "empty")
      get new_admin_issue_translations_path("2026-09-08")
      assert_response :not_found
      sign_in_as(users(:guest))
      get new_admin_issue_translations_path("2026-09-08")
      assert_response :forbidden
      post admin_issue_translations_path("2026-09-08"), params: { token: token }
      assert_response :forbidden
    end
  end
end
