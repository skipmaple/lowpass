# 模型接入的测试助手：地址与模型名在 settings，密钥只从环境读——测试里 stub 掉 api_key，不动 ENV
module ReasonsTestHelpers
  MODEL_ENDPOINT = "https://model.example/v1/chat/completions".freeze

  def with_model_provider(base_url: "https://model.example/v1", model: "test-model")
    Setting.set("model_base_url", base_url)
    Setting.set("model_name", model)
    Reasons::Provider.stubs(:api_key).returns("test-key")
    yield
  ensure
    Setting.set("model_base_url", "")
    Setting.set("model_name", "")
    Reasons::Provider.unstub(:api_key)
  end

  def model_reply(reason:, interest_tag:, prompt_tokens: 100, completion_tokens: 40)
    { choices: [ { message: { role: "assistant", content: { reason: reason, interest_tag: interest_tag }.to_json } } ],
      usage: { prompt_tokens: prompt_tokens, completion_tokens: completion_tokens } }.to_json
  end
end
