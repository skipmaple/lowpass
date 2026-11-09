require "net/http"
require "timeout"
require "ipaddr"

# 模型接入层（ADR T8、设计 §4.4、C1）：只认 OpenAI 兼容的 chat completions——地址与模型名在后台，密钥只从环境读。
# 默认单条 20 秒（R-9.8），显式开发本机模式 300 秒；401 / 403 与普通 429 不追加重试；生产 OpenAI 的额度耗尽可切换一次供应商，其余失败有限重试；
# 响应体边读边截，上限 64 KB
module Reasons::Provider
  class Error < StandardError
    attr_accessor :configuration, :fallback_reason
  end
  ConnectionUnavailable = Class.new(Error)
  TimedOut = Class.new(Error)
  Rejected = Class.new(Error)
  Limited = Class.new(Error)
  QuotaExhausted = Class.new(Limited)
  Response = Data.define(:text, :prompt_tokens, :completion_tokens, :configuration, :fallback_reason, :cached_tokens, :cache_write_tokens) do
    def initialize(text:, prompt_tokens:, completion_tokens:, configuration: nil, fallback_reason: nil, cached_tokens: 0, cache_write_tokens: 0)
      super
    end
  end
  # 截断仍有实际消耗；携带全部计费信息且不重试相同请求。
  class Incomplete < Error
    MESSAGE = "模型输出达到长度上限，未生成完整回复".freeze
    attr_reader :prompt_tokens, :completion_tokens, :cached_tokens, :cache_write_tokens

    def initialize(prompt_tokens:, completion_tokens:, cached_tokens: 0, cache_write_tokens: 0)
      @prompt_tokens, @completion_tokens = prompt_tokens, completion_tokens
      @cached_tokens, @cache_write_tokens = cached_tokens, cache_write_tokens
      super(MESSAGE)
    end
  end

  Configuration = Data.define(:base_url, :model_name, :api_key, :input_price, :output_price, :proxy_url, :fallback, :currency, :cached_input_price, :cache_write_price) do
    def initialize(base_url:, model_name:, api_key:, input_price:, output_price:, proxy_url: nil, fallback: nil, currency: nil, cached_input_price: nil, cache_write_price: nil)
      super
    end
  end
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 20
  REQUEST_TIMEOUT = 20
  LOCAL_READ_TIMEOUT = 300
  LOCAL_MAX_TOKENS = 8192
  MAX_BYTES = 64 * 1024
  ERROR_BYTES = 200            # 非 2xx 时只留一段摘要（error_summary 列也是 200）
  LOCAL_HOSTS = %w[ localhost 127.0.0.1 ].freeze

  class << self
    def base_url = Setting.get("model_base_url")
    def model_name = Setting.get("model_name")
    def api_key(url = base_url) = credential_for(url)
    def key_configured? = api_key.present?
    def configured? = base_url.present? && model_name.present? && key_configured?

    def configuration
      keys = %w[ model_base_url model_name model_input_price model_output_price model_currency ]
      stored = Setting.where(key: keys).pluck(:key, :value).to_h
      # 一个SQL快照配合后台整组事务，避免请求冻结到两版端点/模型/价格的混合值。
      snapshot = keys.index_with { |key| (stored[key].presence || Setting::DEFAULTS.fetch(key)).to_s.dup.freeze }
      url = snapshot.fetch("model_base_url")
      proxy = ENV["MODEL_OPENAI_PROXY_URL"].presence if production_openai?(url)
      raise Error, "生产 OpenAI 专用出口未配置" if production_openai?(url) && proxy.nil?

      Configuration.new(base_url: url, model_name: snapshot.fetch("model_name"), api_key: api_key(url).dup.freeze,
        input_price: snapshot.fetch("model_input_price"), output_price: snapshot.fetch("model_output_price"),
        proxy_url: proxy&.dup&.freeze, fallback: proxy ? fallback_configuration : nil,
        currency: snapshot.fetch("model_currency"), **cache_prices(url, snapshot.fetch("model_name"), snapshot.fetch("model_input_price")))
    end

    # 基础地址自动追加 /chat/completions；完整端点、查询或片段会改变拼接语义。
    # https；本机的 http 也行（本地 Ollama）。
    def valid_base_url?(url) = base_url_error(url).nil?

    def base_url_error(url)
      uri = URI(url.to_s)
      return "地址必须是 https" if uri.host.blank? || !(uri.is_a?(URI::HTTPS) || (uri.is_a?(URI::HTTP) && LOCAL_HOSTS.include?(uri.host)))

      if uri.query || uri.fragment || uri.path.match?(%r{/chat/completions(?:/|\z)}i)
        "请填写 API 基础地址，例如 https://api.openai.com/v1；不要包含 /chat/completions、查询参数或片段"
      end
    rescue URI::Error
      "地址必须是 https"
    end

    def chat(messages, temperature: 0.3, max_tokens: 200, configuration: nil)
      config = configuration || self.configuration
      perform(messages, temperature: temperature, max_tokens: max_tokens, config: config)
    rescue ConnectionUnavailable, QuotaExhausted => e
      raise unless config.proxy_url && config.fallback

      reason = e.is_a?(QuotaExhausted) ? "openai_quota_exhausted" : "proxy_connect_failed"
      Rails.logger.warn(event: "model_egress_fallback", reason: reason, model: config.fallback.model_name)
      fallback = config.fallback
      prices = Reasons::Pricing.siliconflow(fallback.model_name)
      fallback = fallback.with(**prices) if prices
      perform(messages, temperature: temperature, max_tokens: max_tokens, config: fallback,
        fallback_reason: reason)
    end

    private
      # 仅显式开发本机服务接受 text；解析与业务字段校验保持一致。
      def local_development?(uri)
        Rails.env.development? && ENV["MODEL_LOCAL_COMPAT"] == "1" && LOCAL_HOSTS.include?(uri.host)
      end

      def production_openai?(url)
        uri = URI(url.to_s)
        Rails.env.production? && uri.is_a?(URI::HTTPS) && uri.host == "api.openai.com" && uri.port == 443 && uri.userinfo.nil?
      rescue URI::Error
        false
      end

      def credential_for(url)
        ENV[production_openai?(url) ? "OPENAI_API_KEY" : "MODEL_API_KEY"].to_s
      end

      def fallback_configuration
        return if ENV["MODEL_FALLBACK_NAME"].blank? || ENV["MODEL_API_KEY"].blank?

        model = ENV.fetch("MODEL_FALLBACK_NAME").dup.freeze
        prices = Reasons::Pricing.siliconflow(model) || {
          input_price: fallback_price("MODEL_FALLBACK_INPUT_PRICE"),
          output_price: fallback_price("MODEL_FALLBACK_OUTPUT_PRICE")
        }
        Configuration.new(base_url: "https://api.siliconflow.cn/v1", model_name: model,
          api_key: ENV.fetch("MODEL_API_KEY").dup.freeze, currency: "CNY", **prices)
      end

      def fallback_price(key)
        price = ENV[key].to_s
        raise Error, "备用模型需要配置有效单价（#{key}）" unless BigDecimal(price).finite? && BigDecimal(price) >= 0

        price.dup.freeze
      rescue ArgumentError
        raise Error, "备用模型需要配置有效单价（#{key}）"
      end

      def cache_prices(url, model, input_price)
        if production_openai?(url) && model == "gpt-6-luna"
          { cached_input_price: (BigDecimal(input_price) * BigDecimal("0.1")).to_s("F"),
            cache_write_price: (BigDecimal(input_price) * BigDecimal("1.25")).to_s("F") }
        else
          {}
        end
      end

      def connection(config, direct: false)
        uri = URI(config.base_url)
        if config.proxy_url
          proxy = URI(config.proxy_url)
          unless proxy.is_a?(URI::HTTP) && proxy.scheme == "http" && proxy.userinfo.nil? && proxy.query.nil? && proxy.fragment.nil? &&
              [ "", "/" ].include?(proxy.path) && IPAddr.new("100.64.0.0/10").include?(IPAddr.new(proxy.host))
            raise Error, "模型出口必须是 Tailscale 内网 HTTP 代理"
          end
          http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
        else
          # 只让备用显式直连；开发环境及其他供应商保留原有环境代理行为。
          http = Net::HTTP.new(uri.host, uri.port, direct ? nil : :ENV)
        end
        http.use_ssl = uri.is_a?(URI::HTTPS)
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = local_development?(uri) ? LOCAL_READ_TIMEOUT : READ_TIMEOUT
        http.max_retries = 0
        http
      rescue URI::Error, IPAddr::Error
        raise Error, "模型出口地址不合法"
      end

      def perform(messages, temperature:, max_tokens:, config:, fallback_reason: nil)
        raise Error, "地址不合法" unless valid_base_url?(config.base_url)

        uri = URI("#{config.base_url.sub(%r{/+\z}, "")}/chat/completions")
        local = local_development?(uri)
        http = fallback_reason ? connection(config, direct: true) : connection(config)
        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{config.api_key}", "User-Agent" => Adapters::Http::USER_AGENT)
        payload = { model: config.model_name, messages: messages, temperature: temperature, response_format: { type: local ? "text" : "json_object" } }
        if production_openai?(config.base_url) && config.model_name == "gpt-6-luna"
          payload.merge!(max_completion_tokens: max_tokens, reasoning_effort: "none")
        else
          payload[:max_tokens] = local ? [ max_tokens, LOCAL_MAX_TOKENS ].max : max_tokens
        end
        if fallback_reason && config.model_name == "deepseek-ai/DeepSeek-V4-Flash"
          payload[:enable_thinking] = false
        end
        request.body = payload.to_json
        Timeout.timeout(local ? LOCAL_READ_TIMEOUT : REQUEST_TIMEOUT, TimedOut, "模型请求超过截止时间") do
          connect(http)
          # CONNECT 与 TLS 握手完成之后才发模型请求。此后失败由现有任务重试/记账，不能暗中再调用另一家。
          http.request(request) do |response|
            case response
            when Net::HTTPSuccess then return parse(read_capped(response)).with(configuration: config, fallback_reason: fallback_reason)
            when Net::HTTPUnauthorized, Net::HTTPForbidden then raise Rejected, "密钥被拒绝（#{response.code}）"
            when Net::HTTPTooManyRequests then reject_limit(response, config)
            else raise Error, "模型服务 #{response.code}: #{read_head(response, ERROR_BYTES)}"[0, ERROR_BYTES]
            end
          end
        end
      rescue Error => e
        e.configuration = config
        e.fallback_reason = fallback_reason
        raise
      rescue Timeout::Error => e
        raise routed_error(TimedOut, e, config, fallback_reason)
      rescue IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::HTTPExceptions => e
        raise routed_error(Error, e, config, fallback_reason)
      ensure
        http.finish if http&.started?
      end

      def connect(http)
        http.start
      rescue Timeout::Error, IOError, SystemCallError, SocketError => e
        raise ConnectionUnavailable, "模型连接失败（#{e.class}）"
      rescue Net::HTTPExceptions => e
        # 仅代理无法建立上游连接可回退；403/407 等拒绝不绕过。
        if %w[ 502 503 504 ].include?(e.response&.code)
          raise ConnectionUnavailable, "模型代理无法连接上游"
        elsif %w[ 401 403 407 ].include?(e.response&.code)
          raise Rejected, "模型代理拒绝连接（#{e.response.code}）"
        else
          raise
        end
      end

      def reject_limit(response, config)
        body = read_head(response, 4096)
        error = JSON.parse(body)["error"] rescue nil
        code = error["code"] if error.is_a?(Hash)
        type = error["type"] if error.is_a?(Hash)
        exhausted = code == "credit_balance_exhausted" || code == "insufficient_quota" || (code.nil? && type == "insufficient_quota")
        if production_openai?(config.base_url) && exhausted
          raise QuotaExhausted, "OpenAI 可用额度已耗尽（429）"
        else
          raise Limited, "模型服务限流（429）"
        end
      end

      def routed_error(type, error, config, fallback_reason)
        type.new("#{error.class}: #{error.message}"[0, 200]).tap do |failure|
          failure.configuration = config
          failure.fallback_reason = fallback_reason
        end
      end

      # 成功路径：累计到超过上限就抛，后面的字节不再读
      def read_capped(response)
        buffer = "".b
        response.read_body do |chunk|
          buffer << chunk
          raise Error, "响应超过 #{MAX_BYTES / 1024} KB" if buffer.bytesize > MAX_BYTES
        end
        body_text(buffer, MAX_BYTES)
      end

      # 错误路径只要一段摘要：够 limit 字节就不再往下读。用 throw 跳出——块里的 break 要穿过
      # Net::ReadAdapter 才回得到这里，throw 不依赖那一层的实现
      def read_head(response, limit)
        buffer = "".b
        catch(:enough) do
          response.read_body do |chunk|
            buffer << chunk
            throw :enough if buffer.bytesize >= limit
          end
        end
        body_text(buffer, limit)
      end

      # Net::HTTP 的响应体标成 ASCII-8BIT：按字节裁可能切在多字节字符中间，force_encoding 之后
      # 就是一段非法 UTF-8——不 scrub 掉，拼进中文错误信息或喂给 blank? 都会直接抛 Encoding::CompatibilityError
      # / ArgumentError，逃出 Error 体系，Reasons::Generator 的 rescue 就接不住了
      def body_text(body, limit) = body.to_s.b[0, limit].force_encoding(Encoding::UTF_8).scrub

      def parse(body)
        json = JSON.parse(body)
        choice = json.dig("choices", 0) if json.is_a?(Hash)
        usage = json.is_a?(Hash) && json["usage"].is_a?(Hash) ? json["usage"] : {}
        details = usage["prompt_tokens_details"].is_a?(Hash) ? usage["prompt_tokens_details"] : {}
        tokens = { prompt_tokens: usage["prompt_tokens"].to_i, completion_tokens: usage["completion_tokens"].to_i,
          cached_tokens: (details["cached_tokens"] || usage["prompt_cache_hit_tokens"]).to_i,
          cache_write_tokens: details["cache_write_tokens"].to_i }
        raise Incomplete.new(**tokens) if choice.is_a?(Hash) && choice["finish_reason"] == "length"

        text = choice.is_a?(Hash) ? choice.dig("message", "content").to_s : ""
        raise Error, "模型没有返回内容" if text.blank?

        Response.new(text: text, **tokens)
      rescue JSON::ParserError
        raise Error, "模型响应不是 JSON"
      end
  end
end
