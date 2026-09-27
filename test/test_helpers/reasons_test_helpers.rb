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

  # title_zh 只有要译标题的条目（D25）才会被要；不给就不出现在回复里，跟不译标题的回复一个样
  def model_reply(reason:, interest_tag:, title_zh: nil, prompt_tokens: 100, completion_tokens: 40)
    content = { reason: reason, interest_tag: interest_tag, title_zh: title_zh }.compact.to_json
    { choices: [ { message: { role: "assistant", content: content } } ],
      usage: { prompt_tokens: prompt_tokens, completion_tokens: completion_tokens } }.to_json
  end
end
