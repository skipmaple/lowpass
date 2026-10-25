require "test_helper"

class GenerateTranslationsJobTest < ActiveJob::TestCase
  test "Busy重排同一操作与冻结目标，期限不会刷新" do
    issue = issues(:daily_0908)
    payload = { "operation" => ModelRequests.operation, "targets" => [ items(:hn_one).translation_target ], "reassess" => false }
    Translations::Generator.expects(:generate!).with(issue, targets: payload["targets"], operation: payload["operation"], reassess: false).raises(ModelRequests::Busy)
    assert_enqueued_with(job: GenerateTranslationsJob, args: [ issue, payload ]) { GenerateTranslationsJob.perform_now(issue, payload) }
  end

  test "普通失败不重排且系统摘要不带当前网页身份" do
    issue = issues(:daily_0908)
    payload = { "operation" => ModelRequests.operation, "targets" => [], "reassess" => false }
    result = Translations::Generator::Outcome.new(translated: 0, reused: 0, preserved: 0, failed: 1, skipped: 0, stop_reason: nil)
    Translations::Generator.expects(:generate!).returns(result)
    assert_no_enqueued_jobs { GenerateTranslationsJob.perform_now(issue, payload) }
    assert_equal 0, AuditLog.count
  end

  test "已到期任务仍有明确摘要且不请求不重排" do
    issue = issues(:daily_0908)
    payload = { "operation" => ModelRequests.operation(issued_at: 8.days.ago), "targets" => [ items(:hn_one).translation_target ], "reassess" => false }
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    assert_no_difference("ModelCall.count") do
      assert_no_enqueued_jobs { GenerateTranslationsJob.perform_now(issue, payload) }
    end
    assert_match(/translations .*stop_reason.*expired/, output.string)
    assert_nil items(:hn_one).reload.title_zh
  ensure
    Rails.logger = original_logger
  end
end
