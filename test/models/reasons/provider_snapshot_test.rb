require "test_helper"

class Reasons::ProviderSnapshotTest < ActiveSupport::TestCase
  test "冻结端点模型密钥后配置变化不改变本次目的地" do
    with_model_provider do
      config = Reasons::Provider.configuration
      Setting.set("model_base_url", "https://changed.example/v1")
      Setting.set("model_name", "changed")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).with do |request|
        JSON.parse(request.body).fetch("model") == "test-model" && request.headers["Authorization"] == "Bearer test-key"
      end.to_return(status: 200, body: abstained_reply)
      assert_equal '{"decision":"insufficient_evidence"}', Reasons::Provider.chat([], configuration: config).text
      assert_requested stub, times: 1
    end
  end

  test "整个请求截止时间会中止持续等待而非仅限制单次read" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do
        sleep 0.1
        { status: 200, body: abstained_reply }
      end
      stub_const(Reasons::Provider, :REQUEST_TIMEOUT, 0.02) do
        assert_raises(Reasons::Provider::TimedOut) { Reasons::Provider.chat([]) }
      end
    end
  end
end
