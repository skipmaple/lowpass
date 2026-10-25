require "test_helper"

class GenerateTranslationsJobTest < ActiveJob::TestCase
  test "Busy重排同一操作与冻结目标，期限不会刷新" do
    issue = issues(:daily_0908)
    payload = { "operation" => ModelRequests.operation, "targets" => [ items(:hn_one).translation_target ], "reassess" => false }
    Translations::Generator.expects(:generate!).with(issue, targets: payload["targets"], operation: payload["operation"], reassess: false).raises(ModelRequests::Busy)
    assert_enqueued_with(job: GenerateTranslationsJob, args: [ issue, payload ]) { GenerateTranslationsJob.perform_now(issue, payload) }
    expired = payload.deep_dup
    expired["operation"] = ModelRequests.operation(issued_at: 7.days.ago)
    Translations::Generator.expects(:generate!).never
    assert_no_enqueued_jobs { GenerateTranslationsJob.perform_now(issue, expired) }
  end

  test "普通失败不重排且系统摘要不带当前网页身份" do
    issue = issues(:daily_0908)
    payload = { "operation" => ModelRequests.operation, "targets" => [], "reassess" => false }
    result = Translations::Generator::Outcome.new(translated: 0, reused: 0, preserved: 0, failed: 1, skipped: 0, stop_reason: nil)
    Translations::Generator.expects(:generate!).returns(result)
    assert_no_enqueued_jobs { GenerateTranslationsJob.perform_now(issue, payload) }
    assert_equal 0, AuditLog.count
  end
end
