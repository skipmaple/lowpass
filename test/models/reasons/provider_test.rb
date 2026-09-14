require "test_helper"

class Reasons::ProviderTest < ActiveSupport::TestCase
  test "地址、模型名、密钥三样齐了才算配置好" do
    assert_not Reasons::Provider.configured?
    with_model_provider { assert Reasons::Provider.configured? }
    with_model_provider(model: "") { assert_not Reasons::Provider.configured? }
    Setting.set("model_base_url", "https://model.example/v1")
    Setting.set("model_name", "m")
    assert_not Reasons::Provider.configured?   # 没有密钥
  end

  test "地址只认 https，本机允许 http" do
    assert Reasons::Provider.valid_base_url?("https://api.openai.com/v1")
    assert Reasons::Provider.valid_base_url?("http://localhost:11434/v1")
    assert Reasons::Provider.valid_base_url?("http://127.0.0.1:11434/v1")
    assert_not Reasons::Provider.valid_base_url?("http://model.example/v1")
    assert_not Reasons::Provider.valid_base_url?("ftp://x")
    assert_not Reasons::Provider.valid_base_url?("not a url")
    assert_not Reasons::Provider.valid_base_url?("")
  end

  test "请求形状：模型名、messages、JSON 输出、Bearer 密钥、User-Agent；响应带 usage" do
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT)
               .with(headers: { "Authorization" => "Bearer test-key", "Content-Type" => "application/json", "User-Agent" => Adapters::Http::USER_AGENT }) do |request|
                 body = JSON.parse(request.body)
                 body["model"] == "test-model" && body["messages"] == [ { "role" => "user", "content" => "hi" } ] &&
                   body["response_format"] == { "type" => "json_object" } && body["temperature"] == 0.3 && body["max_tokens"] == 200
               end
               .to_return(status: 200, body: model_reply(reason: "r", interest_tag: "t", prompt_tokens: 12, completion_tokens: 3))
      response = Reasons::Provider.chat([ { role: "user", content: "hi" } ])
      assert_requested stub
      assert_equal({ "reason" => "r", "interest_tag" => "t" }, JSON.parse(response.text))
      assert_equal 12, response.prompt_tokens
      assert_equal 3, response.completion_tokens
    end
  end

  test "401 / 403 是密钥被拒绝；429 是限流；5xx、超时、坏 JSON 是可重试错误" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 401, body: "{}")
      error = assert_raises(Reasons::Provider::Rejected) { Reasons::Provider.chat([]) }
      assert_equal "密钥被拒绝（401）", error.message

      # 429 单独成一类：仓库不变量「429 / 403 不追加重试」，Generator 见到它就停掉本期
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 429, body: "slow down")
      error = assert_raises(Reasons::Provider::Limited) { Reasons::Provider.chat([]) }
      assert_equal "模型服务限流（429）", error.message

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 500, body: "boom")
      assert_equal "模型服务 500: boom", assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }.message

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_timeout
      assert_raises(Reasons::Provider::TimedOut) { Reasons::Provider.chat([]) }

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: "not json")
      assert_equal "模型响应不是 JSON", assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }.message

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: { choices: [] }.to_json)
      assert_equal "模型没有返回内容", assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }.message
    end
  end

  test "地址末尾的斜杠不重复" do
    with_model_provider(base_url: "https://model.example/v1/") do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "r", interest_tag: "t"))
      Reasons::Provider.chat([])
      assert_requested stub
    end
  end

  test "响应体超过 64 KB：边读边截，读到上限就抛" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: "x" * 100 * 1024)
      assert_equal "响应超过 64 KB", assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }.message
    end
  end

  test "非 2xx 的长响应体只取前 200 字节做摘要" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 500, body: "x" * 100 * 1024)
      error = assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }
      assert_operator error.message.length, :<=, 200
      assert error.message.start_with?("模型服务 500: xxx"), error.message
    end
  end

  # 纵深防御：库里的地址不是 https（也不是本机）就不发请求（终审 F6）
  test "地址不合法时直接抛，不发请求" do
    with_model_provider(base_url: "http://evil.example/v1") do
      stub = stub_request(:post, "http://evil.example/v1/chat/completions")
      assert_equal "地址不合法", assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }.message
      assert_not_requested stub
    end
  end

  test "响应体是带非法字节的二进制字符串：错误信息截成合法 UTF-8，不抛 Encoding 错误" do
    with_model_provider do
      # Net::HTTP 的响应体是 ASCII-8BIT；拼一段合法 UTF-8 前缀加一个不成对的高位字节，模拟被截断的多字节字符
      body = "网关错误 ".b + "\xE7".b
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 502, body: body)
      error = assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }
      assert error.message.start_with?("模型服务 502:"), error.message
    end
  end

  test "响应体标成二进制但内容合法：多字节的理由照常解析" do
    with_model_provider do
      body = model_reply(reason: "这是一条用来验证二进制编码标记不影响正常解析的中文推荐理由。", interest_tag: "前端开发").b
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: body)
      response = Reasons::Provider.chat([])
      assert_equal({ "reason" => "这是一条用来验证二进制编码标记不影响正常解析的中文推荐理由。", "interest_tag" => "前端开发" }, JSON.parse(response.text))
    end
  end
end
