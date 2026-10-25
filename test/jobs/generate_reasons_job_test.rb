require "test_helper"

class GenerateReasonsJobTest < ActiveJob::TestCase
  test "一期一个" do
    assert_equal 1, GenerateReasonsJob.concurrency_limit
    # concurrency_key 是 "GenerateReasonsJob/<id>"（solid_queue 按类名分组），跟
    # test/jobs/fetch_source_job_test.rb 的断言方式一样只认里面带没带这一期的 id
    assert_includes GenerateReasonsJob.new(issues(:daily_0908)).concurrency_key, issues(:daily_0908).id
  end

  test "调生成器，默认只补空的" do
    Reasons::Generator.expects(:generate!).with { |issue, only_missing:, operation:| issue == issues(:daily_0908) && only_missing && ModelRequests.valid_operation?(operation) }
    GenerateReasonsJob.perform_now(issues(:daily_0908))
    Reasons::Generator.expects(:generate!).with { |issue, only_missing:, operation:| issue == issues(:daily_0908) && !only_missing && ModelRequests.valid_operation?(operation) }
    GenerateReasonsJob.perform_now(issues(:daily_0908), false)
  end
  test "新消息冻结元数据，旧参数不启动历史翻译" do
    issue = issues(:daily_0908)
    job = GenerateReasonsJob.perform_later(issue, false)
    metadata = job.arguments.last
    assert_equal [], metadata.fetch("translation_targets")
    assert ModelRequests.valid_operation?(metadata.fetch("operation"))
    Translations::Generator.expects(:generate!).never
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: abstained_reply)
      GenerateReasonsJob.perform_now(issue)
    end
  end

  test "拒写或画像为空仍译，拒绝限流预算不落入翻译" do
    issue = issues(:daily_0908)
    with_model_provider do
      InterestArea.update_all(enabled: false)
      context = { "operation" => ModelRequests.operation, "translation_targets" => [ items(:hn_one).translation_target ] }
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: { choices: [ { message: { content: { decision: "translated", text: "独立中文译文" }.to_json } } ] }.to_json)
      GenerateReasonsJob.perform_now(issue, true, context)
      assert_equal "独立中文译文", items(:hn_one).reload.title_zh
      assert_requested stub, times: 1
    end
    %w[ rejected limited budget ].each do |stop|
      result = Reasons::Generator::Outcome.new(generated: 0, reused: 0, abstained: 0, failed: 1, skipped: false, stop_reason: stop)
      Reasons::Generator.expects(:generate!).returns(result)
      Translations::Generator.expects(:generate!).never
      GenerateReasonsJob.perform_now(issue, true, { "operation" => ModelRequests.operation, "translation_targets" => [ items(:hn_one).translation_target ] })
    end
  end
  test "旧消息与Busy重排保留原始期限及操作键" do
    issue = issues(:daily_0908)
    job = GenerateReasonsJob.new(issue)
    serialized = job.serialize
    serialized["enqueued_at"] = 8.days.ago.iso8601(6)
    Reasons::Generator.expects(:generate!).never
    assert_no_enqueued_jobs { GenerateReasonsJob.deserialize(serialized).perform_now }
    Reasons::Generator.unstub(:generate!)
    serialized["enqueued_at"] = 1.day.ago.iso8601(6)
    Reasons::Generator.expects(:generate!).with { |_, operation:, **|
      operation.fetch("key") == job.job_id && Time.iso8601(operation.fetch("issued_at")) == Time.iso8601(serialized.fetch("enqueued_at"))
    }.raises(ModelRequests::Busy)
    assert_enqueued_with(job: GenerateReasonsJob, args: ->(args) { args.last.fetch("operation").fetch("key") == job.job_id && args.last.fetch("translation_targets").empty? }) do
      GenerateReasonsJob.deserialize(serialized).perform_now
    end
  end

  test "理由三次不合规或合法拒写后仍单独译且失败回复译文从未保存" do
    issue = issues(:daily_0908)
    with_model_provider do
      [ :invalid, :abstained ].each do |mode|
        ModelCall.delete_all
        items(:hn_one).update!(title_zh: nil)
        ReasonAbstention.delete_all
        WebMock.reset!
        reason_response = mode == :invalid ? model_reply(reason: "短", interest_tag: "AI / LLM", title_zh: "失败不得保存") : abstained_reply
        content = { choices: [ { message: { content: { decision: "translated", text: "另一次独立合规译文" }.to_json } } ] }.to_json
        responses = Array.new(mode == :invalid ? 3 : 1) { { status: 200, body: reason_response } } + [ { status: 200, body: content } ]
        stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(*responses)
        GenerateReasonsJob.perform_now(issue, true, { "operation" => ModelRequests.operation, "translation_targets" => [ items(:hn_one).translation_target ] })
        assert_nil items(:hn_one).reload.reason
        assert_equal "另一次独立合规译文", items(:hn_one).title_zh
        assert_equal mode == :abstained, items(:hn_one).reason_abstention.present?
        assert_requested stub, times: mode == :invalid ? 4 : 2
        assert_equal 1, ModelCall.where(purpose: "translation").count
      end
    end
  end
end
