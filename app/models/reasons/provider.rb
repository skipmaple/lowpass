require "net/http"

# 模型接入层（ADR T8、设计 §4.4、C1）：只认 OpenAI 兼容的 chat completions——地址与模型名在后台，密钥只从环境读。
# 单条 20 秒（R-9.8）；401 / 403 是密钥被拒绝（本期不再继续），其余失败可重试；响应体上限 64 KB
module Reasons::Provider
  Error = Class.new(StandardError)
  TimedOut = Class.new(Error)
  Rejected = Class.new(Error)
  Response = Data.define(:text, :prompt_tokens, :completion_tokens)
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 20
  MAX_BYTES = 64 * 1024
  LOCAL_HOSTS = %w[ localhost 127.0.0.1 ].freeze

  class << self
    def base_url = Setting.get("model_base_url")
    def model_name = Setting.get("model_name")
    def api_key = ENV["MODEL_API_KEY"].to_s
    def key_configured? = api_key.present?
    def configured? = base_url.present? && model_name.present? && key_configured?

    # https；本机的 http 也行（本地 Ollama）
    def valid_base_url?(url)
      uri = URI(url.to_s)
      return false if uri.host.blank?
      uri.is_a?(URI::HTTPS) || (uri.is_a?(URI::HTTP) && LOCAL_HOSTS.include?(uri.host))
    rescue URI::Error
      false
    end

    def chat(messages, temperature: 0.3, max_tokens: 200)
      uri = URI("#{base_url.chomp('/')}/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.is_a?(URI::HTTPS)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{api_key}", "User-Agent" => Adapters::Http::USER_AGENT)
      request.body = { model: model_name, messages: messages, temperature: temperature, max_tokens: max_tokens, response_format: { type: "json_object" } }.to_json
      response = http.request(request)
      case response
      when Net::HTTPSuccess then parse(response.body.to_s[0, MAX_BYTES])
      when Net::HTTPUnauthorized, Net::HTTPForbidden then raise Rejected, "密钥被拒绝（#{response.code}）"
      else raise Error, "模型服务 #{response.code}: #{response.body.to_s[0, 200]}"[0, 200]
      end
    rescue Timeout::Error => e
      raise TimedOut, "#{e.class}: #{e.message}"[0, 200]
    rescue IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, "#{e.class}: #{e.message}"[0, 200]
    end

    private
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
