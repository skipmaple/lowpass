require "net/http"

# 模型接入层（ADR T8、设计 §4.4、C1）：只认 OpenAI 兼容的 chat completions——地址与模型名在后台，密钥只从环境读。
# 单条 20 秒（R-9.8）；401 / 403 是密钥被拒绝、429 是被限流（都不追加重试，本期不再继续），其余失败可重试；
# 响应体边读边截，上限 64 KB
module Reasons::Provider
  Error = Class.new(StandardError)
  TimedOut = Class.new(Error)
  Rejected = Class.new(Error)
  Limited = Class.new(Error)
  Response = Data.define(:text, :prompt_tokens, :completion_tokens)
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 20
  MAX_BYTES = 64 * 1024
  ERROR_BYTES = 200            # 非 2xx 时只留一段摘要（error_summary 列也是 200）
  LOCAL_HOSTS = %w[ localhost 127.0.0.1 ].freeze

  class << self
    def base_url = Setting.get("model_base_url")
    def model_name = Setting.get("model_name")
    def api_key = ENV["MODEL_API_KEY"].to_s
    def key_configured? = api_key.present?
    def configured? = base_url.present? && model_name.present? && key_configured?

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

    def chat(messages, temperature: 0.3, max_tokens: 200)
      # 纵深防御：地址在存进 settings 时已经校验过一次，这里发请求之前再看一眼——
      # 别的写入路径（console、迁移、以后的导入）绕不过这一道
      raise Error, "地址不合法" unless valid_base_url?(base_url)

      uri = URI("#{base_url.sub(%r{/+\z}, "")}/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.is_a?(URI::HTTPS)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{api_key}", "User-Agent" => Adapters::Http::USER_AGENT)
      request.body = { model: model_name, messages: messages, temperature: temperature, max_tokens: max_tokens, response_format: { type: "json_object" } }.to_json
      # 块形式：响应体边读边截（同 Adapters::Http#read_capped），上限之前就停手，
      # 不先把一个几百 KB 的回复整段读进内存再裁
      http.request(request) do |response|
        case response
        when Net::HTTPSuccess then return parse(read_capped(response))
        when Net::HTTPUnauthorized, Net::HTTPForbidden then raise Rejected, "密钥被拒绝（#{response.code}）"
        when Net::HTTPTooManyRequests then raise Limited, "模型服务限流（429）"
        else raise Error, "模型服务 #{response.code}: #{read_head(response, ERROR_BYTES)}"[0, ERROR_BYTES]
        end
      end
    rescue Timeout::Error => e
      raise TimedOut, "#{e.class}: #{e.message}"[0, 200]
    rescue IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, "#{e.class}: #{e.message}"[0, 200]
    end

    private
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
        text = json.is_a?(Hash) ? json.dig("choices", 0, "message", "content").to_s : ""
        raise Error, "模型没有返回内容" if text.blank?
        usage = json["usage"].is_a?(Hash) ? json["usage"] : {}
        Response.new(text: text, prompt_tokens: usage["prompt_tokens"].to_i, completion_tokens: usage["completion_tokens"].to_i)
      rescue JSON::ParserError
        raise Error, "模型响应不是 JSON"
      end
  end
end
