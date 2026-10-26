require "test_helper"

# 编辑参考与合成响应只证明协议、边界及保存；不是模型已经翻译正确的实网证据。
class Translations::AcceptedSamplesTest < ActiveSupport::TestCase
  test "四个缺译标题与否定计划问句引用混排纯名称沿用同一独立契约" do
    item = items(:hn_one)
    samples = JSON.parse(file_fixture("translations/accepted_samples.json").read)
    with_model_provider do
      samples.each do |sample|
        item.update!(title: sample.fetch("original"), title_zh: nil)
        TranslationPreservation.delete_all
        target = item.reload.translation_target
        response = sample.slice("decision", "text")
        stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).with { |request|
          JSON.parse(JSON.parse(request.body).fetch("messages").last.fetch("content")) == { "field" => "title", "text" => sample.fetch("original") }
        }.to_return(status: 200, body: { choices: [ { message: { content: response.to_json } } ] }.to_json)
        before = item.attributes.except("title_zh", "updated_at")
        result = Translations::Generator.generate!(item.issue, targets: [ target ], operation: ModelRequests.operation)
        assert_equal 1, sample.fetch("decision") == "translated" ? result.translated : result.preserved
        if sample["text"]
          assert_equal sample.fetch("text"), item.reload.title_zh
        else
          assert_nil item.reload.title_zh
        end
        assert_equal before, item.attributes.except("title_zh", "updated_at")
        assert_requested stub, times: 1
        WebMock.reset!
      end
    end
    assert_equal samples.size, ModelCall.where(purpose: "translation", status: "ok").count
  end
end
