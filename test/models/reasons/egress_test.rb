require "test_helper"

class Reasons::EgressTest < ActiveSupport::TestCase
  OPENAI = "https://api.openai.com/v1".freeze
  FALLBACK = "https://api.siliconflow.cn/v1".freeze

  test "production OpenAI freezes its own key and a separate direct fallback" do
    with_egress do
      config = Reasons::Provider.configuration
      assert_equal "openai-test-key", config.api_key
      assert_equal "http://100.64.0.2:8888", config.proxy_url
      assert_equal FALLBACK, config.fallback.base_url
      assert_equal "deepseek-test", config.fallback.model_name
      assert_equal "siliconflow-test-key", config.fallback.api_key
      assert_nil config.fallback.proxy_url
      ENV["MODEL_FALLBACK_NAME"] = "changed"
      assert_equal "deepseek-test", config.fallback.model_name
    end
  end

  test "development ignores production egress variables and keeps the existing key" do
    with_egress(environment: "development") do
      config = Reasons::Provider.configuration
      assert_equal "siliconflow-test-key", config.api_key
      assert_nil config.proxy_url
      assert_nil config.fallback
    end
  end

  test "production providers other than official OpenAI never use this proxy or key" do
    with_egress do
      Setting.set("model_base_url", FALLBACK)
      config = Reasons::Provider.configuration
      assert_equal "siliconflow-test-key", config.api_key
      assert_nil config.proxy_url
      assert_nil config.fallback
    end
  end

  test "an unavailable proxy falls back once using the fallback payload and credentials" do
    with_egress do
      config = Reasons::Provider.configuration
      broken = Net::HTTP.new("api.openai.com", 443, nil)
      broken.stubs(:start).raises(Errno::ECONNREFUSED)
      Reasons::Provider.stubs(:connection).with(config).returns(broken)
      Reasons::Provider.stubs(:connection).with(config.fallback, direct: true).returns(Net::HTTP.new("api.siliconflow.cn", 443, nil).tap { |http| http.use_ssl = true })
      stub = stub_request(:post, "#{FALLBACK}/chat/completions").with do |request|
        request.headers["Authorization"] == "Bearer siliconflow-test-key" && JSON.parse(request.body)["model"] == "deepseek-test"
      end.to_return(status: 200, body: abstained_reply)
      response = Reasons::Provider.chat([], configuration: config)
      assert_equal config.fallback, response.configuration
      assert_equal "proxy_connect_failed", response.fallback_reason
      assert_equal 100, response.prompt_tokens
      assert_requested stub, times: 1
      assert_not_requested :post, "#{OPENAI}/chat/completions"
    end
  end

  test "OpenAI auth rate-limit and payload errors never call the fallback" do
    with_egress do
      [ 401, 403, 429, 500 ].each do |status|
        stub_request(:post, "#{OPENAI}/chat/completions").to_return(status: status, body: "upstream failure")
        assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }
      end
      assert_not_requested :post, "#{FALLBACK}/chat/completions"
    end
  end

  test "a timeout after the model request starts is not hidden by an immediate fallback" do
    with_egress do
      stub_request(:post, "#{OPENAI}/chat/completions").to_timeout
      assert_raises(Reasons::Provider::TimedOut) { Reasons::Provider.chat([]) }
      assert_not_requested :post, "#{FALLBACK}/chat/completions"
    end
  end

  test "TLS verification failure never falls back" do
    with_egress do
      config = Reasons::Provider.configuration
      broken = Net::HTTP.new("api.openai.com", 443, nil)
      broken.stubs(:start).raises(OpenSSL::SSL::SSLError, "certificate verify failed")
      Reasons::Provider.stubs(:connection).with(config).returns(broken)
      assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([], configuration: config) }
      assert_not_requested :post, "#{FALLBACK}/chat/completions"
    end
  end

  test "the ledger uses the returned provider configuration even for invalid output" do
    with_egress do
      config = Reasons::Provider.configuration
      response = Reasons::Provider::Response.new(text: "invalid", prompt_tokens: 1000000, completion_tokens: 1000000,
        configuration: config.fallback, fallback_reason: "proxy_connect_failed")
      ModelRequests.record(items(:hn_one), "invalid", response, ModelRequests.now_ms, "invalid output", purpose: "reason",
        operation: ModelRequests.operation, configuration: config)
      call = ModelCall.last
      assert_equal BigDecimal("3"), call.cost
      assert_equal "api.siliconflow.cn", call.provider_host
      assert_equal "deepseek-test", call.provider_model
      assert_equal "proxy_connect_failed", call.fallback_reason
    end
  end

  test "only the OpenAI connection uses the explicit proxy and TLS" do
    with_egress do
      config = Reasons::Provider.configuration
      primary = Reasons::Provider.send(:connection, config)
      fallback = Reasons::Provider.send(:connection, config.fallback, direct: true)
      assert_equal "100.64.0.2", primary.proxy_address
      assert_equal 8888, primary.proxy_port
      assert primary.use_ssl?
      assert_nil fallback.proxy_address
      assert fallback.use_ssl?
      assert_equal 0, primary.max_retries
      assert_equal 0, fallback.max_retries
    end
  end

  test "invalid proxy addresses fail closed before sending credentials" do
    with_egress do
      [ "http://example.com:8888", "http://user:pass@100.64.0.2:8888", "https://100.64.0.2:8888", "http://100.64.0.2:8888/path" ].each do |proxy|
        ENV["MODEL_OPENAI_PROXY_URL"] = proxy
        assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }
      end
      assert_not_requested :post, "#{OPENAI}/chat/completions"
      assert_not_requested :post, "#{FALLBACK}/chat/completions"
    end
  end

  test "both providers unavailable retain the retry ceiling and actual fallback metadata" do
    with_egress do
      config = Reasons::Provider.configuration
      broken = Net::HTTP.new("api.openai.com", 443, nil)
      broken.stubs(:start).raises(Net::OpenTimeout)
      Reasons::Provider.stubs(:connection).with(config).returns(broken)
      Reasons::Provider.stubs(:connection).with(config.fallback, direct: true).returns(Net::HTTP.new("api.siliconflow.cn", 443, nil).tap { |http| http.use_ssl = true })
      stub = stub_request(:post, "#{FALLBACK}/chat/completions").to_return(status: 503)
      items(:hn_one).update!(summary: "This technical article explains how a structured log viewer streams local logs, applies severity and process filters, and exports matches as JSON for offline debugging.")
      operation = ModelRequests.operation
      2.times { assert_equal :failed, Reasons::Generator.generate_item!(items(:hn_one), operation: operation) }
      assert_requested stub, times: 3
      assert_equal 3, ModelCall.count
      assert_equal [ "api.siliconflow.cn" ], ModelCall.distinct.pluck(:provider_host)
      assert_equal [ "deepseek-test" ], ModelCall.distinct.pluck(:provider_model)
      assert_equal [ "proxy_connect_failed" ], ModelCall.distinct.pluck(:fallback_reason)
    end
  end

  test "a later call returns to OpenAI once the proxy is restored" do
    with_egress do
      config = Reasons::Provider.configuration
      broken = Net::HTTP.new("api.openai.com", 443, nil)
      broken.stubs(:start).raises(Errno::ECONNREFUSED)
      Reasons::Provider.stubs(:connection).with(config).returns(broken)
      Reasons::Provider.stubs(:connection).with(config.fallback, direct: true).returns(Net::HTTP.new("api.siliconflow.cn", 443, nil).tap { |http| http.use_ssl = true })
      fallback = stub_request(:post, "#{FALLBACK}/chat/completions").to_return(body: abstained_reply)
      assert_equal config.fallback, Reasons::Provider.chat([]).configuration
      Reasons::Provider.unstub(:connection)
      primary = stub_request(:post, "#{OPENAI}/chat/completions").to_return(body: abstained_reply)
      response = Reasons::Provider.chat([])
      assert_equal config, response.configuration
      assert_nil response.fallback_reason
      assert_requested primary, times: 1
      assert_requested fallback, times: 1
    end
  end

  test "OpenAI exhausted credits fall back but ordinary rate limits do not" do
    with_egress do
      [ "credit_balance_exhausted", "insufficient_quota" ].each do |code|
        stub_request(:post, "#{OPENAI}/chat/completions").to_return(status: 429, body: { error: { code: code, type: "insufficient_quota" } }.to_json)
        fallback = stub_request(:post, "#{FALLBACK}/chat/completions").to_return(body: abstained_reply)
        response = Reasons::Provider.chat([])
        assert_equal "openai_quota_exhausted", response.fallback_reason
        assert_equal "deepseek-test", response.configuration.model_name
      end
      assert_requested :post, "#{FALLBACK}/chat/completions", times: 2
    end
  end

  test "current OpenAI model uses supported completion parameters" do
    with_egress do
      Setting.set("model_name", "gpt-6-luna")
      request = stub_request(:post, "#{OPENAI}/chat/completions").with do |req|
        payload = JSON.parse(req.body)
        payload["max_completion_tokens"] == 320 && payload["reasoning_effort"] == "none" && !payload.key?("max_tokens")
      end.to_return(body: abstained_reply)
      Reasons::Provider.chat([], max_tokens: 320)
      assert_requested request
    end
  end

  test "OpenAI cache reads and writes are billed separately in USD" do
    with_egress do
      Setting.set("model_name", "gpt-6-luna")
      Setting.set("model_currency", "USD")
      Setting.set("model_input_price", "0.1")
      Setting.set("model_output_price", "0.5")
      reply = JSON.parse(abstained_reply(prompt_tokens: 1000, completion_tokens: 200))
      reply["usage"]["prompt_tokens_details"] = { "cached_tokens" => 300, "cache_write_tokens" => 200 }
      stub_request(:post, "#{OPENAI}/chat/completions").to_return(body: reply.to_json)
      config = Reasons::Provider.configuration
      response = Reasons::Provider.chat([])
      ModelRequests.record(items(:hn_one), "abstained", response, ModelRequests.now_ms, purpose: "reason", operation: ModelRequests.operation, configuration: config)
      assert_equal BigDecimal("0.000178"), ModelCall.last.cost
      assert_equal "USD", ModelCall.last.currency
      assert_equal 300, ModelCall.last.cached_tokens
      assert_equal 200, ModelCall.last.cache_write_tokens
    end
  end

  test "SiliconFlow prices follow Shanghai peak hours and stay in CNY" do
    with_egress do
      ENV["MODEL_FALLBACK_NAME"] = "deepseek-ai/DeepSeek-V4-Flash"
      travel_to Time.find_zone("Asia/Shanghai").parse("2026-11-06 06:00") do
        config = Reasons::Provider.configuration.fallback
        assert_equal "1.5", config.input_price
        assert_equal "4.5", config.output_price
        assert_equal "0.15", config.cached_input_price
        assert_equal "CNY", config.currency
      end
      travel_to Time.find_zone("Asia/Shanghai").parse("2026-11-06 08:00") do
        config = Reasons::Provider.configuration.fallback
        assert_equal "3", config.input_price
        assert_equal "9", config.output_price
        assert_equal "0.3", config.cached_input_price
      end
    end
  end

  test "missing production proxy is rejected without a direct OpenAI request" do
    with_egress do
      ENV.delete("MODEL_OPENAI_PROXY_URL")
      assert_raises(Reasons::Provider::Error) { Reasons::Provider.chat([]) }
      assert_not_requested :post, "#{OPENAI}/chat/completions"
    end
  end

  test "development keeps environment proxy support" do
    with_egress(environment: "development") do
      http = Reasons::Provider.send(:connection, Reasons::Provider.configuration)
      assert http.proxy_from_env?
    end
  end

  test "CONNECT refusal is a rejected operation with no fallback" do
    with_egress do
      [ Net::HTTPForbidden, Net::HTTPProxyAuthenticationRequired ].each do |klass|
        code = klass == Net::HTTPForbidden ? "403" : "407"
        denied = klass.new("1.1", code, "Denied")
        exception = assert_raises(Net::HTTPClientException) { denied.value }
        config = Reasons::Provider.configuration
        http = Net::HTTP.new("api.openai.com", 443, nil)
        http.stubs(:start).raises(exception)
        Reasons::Provider.stubs(:connection).with(config).returns(http)
        item = items(:hn_one)
        item.update!(summary: "A detailed technical discussion of local log streaming, structured event processing, severity filters, and exporting matching records for offline debugging.")
        operation = ModelRequests.operation
        assert_raises(Reasons::Provider::Rejected) { Reasons::Generator.generate_item!(item, operation: operation) }
        assert_equal "rejected", ModelRequests.stop_reason(operation)
        assert_equal "api.openai.com", ModelCall.last.provider_host
      end
      assert_not_requested :post, "#{FALLBACK}/chat/completions"
    end
  end

  test "fallback rates use actual request time across both tariff boundaries" do
    with_egress do
      ENV["MODEL_FALLBACK_NAME"] = "deepseek-ai/DeepSeek-V4-Flash"
      [ [ "07:59:59", "08:00:04", "3" ], [ "01:59:59", "02:00:04", "1.5" ] ].each do |before, after, price|
        travel_to Time.find_zone("Asia/Shanghai").parse("2026-11-06 #{before}")
        config = Reasons::Provider.configuration
        stub_request(:post, "#{OPENAI}/chat/completions").to_return do
          travel_to Time.find_zone("Asia/Shanghai").parse("2026-11-06 #{after}")
          { status: 429, body: { error: { code: "credit_balance_exhausted" } }.to_json }
        end
        stub_request(:post, "#{FALLBACK}/chat/completions").with { |req| JSON.parse(req.body)["enable_thinking"] == false }.to_return(body: abstained_reply)
        response = Reasons::Provider.chat([], configuration: config)
        assert_equal price, response.configuration.input_price
      end
    ensure
      travel_back
    end
  end

  private
    def with_egress(environment: "production")
      values = { "OPENAI_API_KEY" => "openai-test-key", "MODEL_API_KEY" => "siliconflow-test-key",
        "MODEL_OPENAI_PROXY_URL" => "http://100.64.0.2:8888", "MODEL_FALLBACK_NAME" => "deepseek-test",
        "MODEL_FALLBACK_INPUT_PRICE" => "1", "MODEL_FALLBACK_OUTPUT_PRICE" => "2" }
      before = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new(environment))
      Setting.set("model_base_url", OPENAI)
      Setting.set("model_name", "gpt-4.1")
      Setting.set("model_input_price", "10")
      Setting.set("model_output_price", "20")
      yield
    ensure
      before.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      Rails.unstub(:env)
    end
end
