require "test_helper"

class Reasons::ProviderTest < ActiveSupport::TestCase
  test "完整聊天端点及查询片段不作为基础地址" do
    assert Reasons::Provider.valid_base_url?("https://model.example/v1/")
    assert_not Reasons::Provider.valid_base_url?("https://model.example/v1/chat/completions")
    assert_not Reasons::Provider.valid_base_url?("https://model.example/v1/chat/completions/")
    assert_not Reasons::Provider.valid_base_url?("https://model.example/v1?key=x")
    assert_not Reasons::Provider.valid_base_url?("https://model.example/v1#chat")
  end

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
      assert_equal({ "decision" => "generated", "reason" => "r", "interest_tag" => "t" }, JSON.parse(response.text))
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

  test "显式开启的开发本机模式兼容文本响应，为推理留出输出额度和读取时间" do
    Rails.env.stubs(:development?).returns(true)
    previous = ENV["MODEL_LOCAL_COMPAT"]
    ENV["MODEL_LOCAL_COMPAT"] = "1"
    with_model_provider(base_url: "http://localhost:1236/v1") do
      body = nil
      stub = stub_request(:post, "http://localhost:1236/v1/chat/completions").with do |request|
        body = JSON.parse(request.body)
        true
      end.to_return(status: 200, body: model_reply(reason: "r", interest_tag: "t"))
      Net::HTTP.any_instance.expects(:read_timeout=).with(300)
      Timeout.expects(:timeout).with(300, Reasons::Provider::TimedOut, "模型请求超过截止时间").yields

      Reasons::Provider.chat([], max_tokens: 600)

      assert_requested stub
      assert_equal({ "type" => "text" }, body["response_format"])
      assert_equal 8192, body["max_tokens"]
    end
  ensure
    ENV["MODEL_LOCAL_COMPAT"] = previous
  end

  test "本机兼容开关不改变生产环境、远程端点或未启用的开发调用" do
    previous = ENV["MODEL_LOCAL_COMPAT"]
    [ [ false, "1", "http://localhost:1236/v1" ],
      [ true, "1", "https://model.example/v1" ],
      [ true, nil, "http://127.0.0.1:1236/v1" ] ].each do |development, enabled, url|
      Rails.env.stubs(:development?).returns(development)
      ENV["MODEL_LOCAL_COMPAT"] = enabled
      with_model_provider(base_url: url) do
        body = nil
        stub = stub_request(:post, "#{url}/chat/completions").with do |request|
          body = JSON.parse(request.body)
          true
        end.to_return(status: 200, body: model_reply(reason: "r", interest_tag: "t"))
        Net::HTTP.any_instance.expects(:read_timeout=).with(20)

        Reasons::Provider.chat([], max_tokens: 320)

        assert_requested stub
        assert_equal({ "type" => "json_object" }, body["response_format"])
        assert_equal 320, body["max_tokens"]
      end
    end
  ensure
    ENV["MODEL_LOCAL_COMPAT"] = previous
  end

  test "不把思考字段当成最终内容保存" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200,
        body: { choices: [ { message: { content: "", reasoning_content: '{"reason":"r","interest_tag":"t"}' } } ] }.to_json)
      assert_equal "模型没有返回内容", assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }.message
    end
  end

  test "输出额度耗尽是不可接纳的截断响应，保留全部 usage 而不读取思考作为答案" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: {
        choices: [ { finish_reason: "length", message: { content: "", reasoning_content: "只供模型内部推理" } } ],
        usage: { prompt_tokens: 456, completion_tokens: 2047, completion_tokens_details: { reasoning_tokens: 2047 } }
      }.to_json)

      error = assert_raises(Reasons::Provider::Incomplete) { Reasons::Provider.chat([]) }

      assert_equal "模型输出达到长度上限，未生成完整回复", error.message
      assert_equal 456, error.prompt_tokens
      assert_equal 2047, error.completion_tokens
      assert_not_includes error.message, "只供模型内部推理"
    end
  end

  test "截断标记优先于内容，即使 JSON 完整也不能当成功响应" do
    with_model_provider do
      reply = JSON.parse(model_reply(reason: "这条理由看起来完整但响应被明确标记为长度截断，不能存入条目。", interest_tag: "AI / LLM"))
      reply["choices"].first["finish_reason"] = "length"
      reply.delete("usage")
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply.to_json)

      error = assert_raises(Reasons::Provider::Incomplete) { Reasons::Provider.chat([]) }

      assert_equal 0, error.prompt_tokens
      assert_equal 0, error.completion_tokens
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
      assert_equal({ "decision" => "generated", "reason" => "这是一条用来验证二进制编码标记不影响正常解析的中文推荐理由。", "interest_tag" => "前端开发" }, JSON.parse(response.text))
    end
  end
end
