require "test_helper"

class Reasons::EvidenceGenerationTest < ActiveSupport::TestCase
  test "no summary and no usable body never send a title-only model request" do
    with_model_provider do
      Reasons::Evidence.stubs(:fetch).returns(Reasons::Evidence::Result.new(text: nil, url: items(:hn_one).url, error: "原文资料不足：未提取到可用正文"))
      item = items(:hn_one)
      original = item.attributes
      operation = ModelRequests.operation
      2.times { assert_equal :abstained, Reasons::Generator.generate_item!(item, operation: operation) }
      assert_not_requested :post, ReasonsTestHelpers::MODEL_ENDPOINT
      assert_equal original, item.reload.attributes
      assert item.reason_abstention
      assert_equal 1, ModelCall.count
      assert_equal 0, ModelCall.last.prompt_tokens
      assert_not ModelCall.last.request_made
      assert_equal 0, Reasons::Budget.month_calls
    end
  end

  test "a fetched body supports a short source entry without rewriting the source" do
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).with do |request|
        JSON.parse(request.body)["messages"].last["content"].include?("工具在本地流式读取日志")
      end.to_return(body: model_reply(reason: "流式读取日志并按级别筛选，便于检查大文件中的错误记录。", interest_tag: "前端开发"))
      assert_equal :generated, Reasons::Generator.generate_item!(items(:hn_one))
      assert_nil items(:hn_one).reload.summary
      assert_requested stub, times: 1
    end
  end

  test "a stop arriving during evidence acquisition prevents the model request" do
    with_model_provider do
      operation = ModelRequests.operation
      Reasons::Evidence.stubs(:fetch).returns(Reasons::Evidence::Result.new(text: "正文", url: "https://example.com", error: nil))
      ModelRequests.stubs(:stop_reason).with(operation).returns(nil, "stopped")
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation)
      assert_not_requested :post, ReasonsTestHelpers::MODEL_ENDPOINT
      assert_equal 0, ModelCall.count
    end
  end
  test "temporary source failure stays pending and later recovery can generate" do
    with_model_provider do
      Reasons::Evidence.stubs(:fetch).returns(Reasons::Evidence::Result.new(text: nil, url: items(:hn_one).url, error: "原文获取失败：连接超时"))
      item = items(:hn_one)
      assert_equal :failed, Reasons::Generator.generate_item!(item)
      assert_nil item.reload.reason_abstention
      assert Item.pending_reasons.exists?(id: item.id)
      assert_not_requested :post, ReasonsTestHelpers::MODEL_ENDPOINT
      Reasons::Evidence.stubs(:fetch).returns(Reasons::Evidence::Result.new(text: "流式日志检索与导出。", url: item.url, error: nil))
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(body: model_reply(reason: "流式读取日志并按级别筛选，便于检查大文件中的错误记录。", interest_tag: "前端开发"))
      assert_equal :generated, Reasons::Generator.generate_item!(item)
      assert_equal 1, Reasons::Budget.month_calls
    end
  end

  test "expiration or a lower budget during body fetch prevents a paid request" do
    with_model_provider do
      ModelRequests.stubs(:valid_operation?).returns(true, true, false)
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one))
      ModelRequests.unstub(:valid_operation?)
      Reasons::Budget.stubs(:exhausted?).returns(false, true)
      operation = ModelRequests.operation
      assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation)
      assert_equal "budget", ModelRequests.stop_reason(operation)
      assert_not_requested :post, ReasonsTestHelpers::MODEL_ENDPOINT
    end
  end
end
