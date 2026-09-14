require "net/http"

# IM webhook 渠道：HTTPS JSON POST，报文形状按 ALERT_WEBHOOK_FORMAT（设计 B2）。地址由运维在环境里配，
# 是可信输入，不过 surfguard；但只接受 https（Alerts::Config 已挡），不跟重定向，5 秒超时
module Alerts::Channels::Webhook
  NAME = "webhook".freeze
  TIMEOUT = 5

  def self.configured? = Alerts::Config.webhook?

  def self.deliver(event, phase)
    uri = URI(Alerts::Config.webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "User-Agent" => Adapters::Http::USER_AGENT)
    request.body = payload(event, phase).to_json
    response = http.request(request)
    return if response.is_a?(Net::HTTPSuccess)

    # 响应体标成 ASCII-8BIT：按字节裁可能切在多字节字符中间，不 scrub 掉，这条消息就是一段非法 UTF-8，
    # 存进 alert_events.delivery_error 或拼进别的中文串时才炸（与 Reasons::Provider 同一处）
    raise Alerts::DeliveryError, "webhook #{response.code}: #{body_text(response)}"[0, 200]
  rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
    raise Alerts::DeliveryError, "webhook #{e.class}: #{e.message}"[0, 200]
  end

  def self.body_text(response) = response.body.to_s.b[0, 200].force_encoding(Encoding::UTF_8).scrub
  private_class_method :body_text

  def self.payload(event, phase)
    text = Alerts::Message.text(event, phase)
    case Alerts::Config.webhook_format
    when "feishu" then { msg_type: "text", content: { text: text } }
    when "wecom", "dingtalk" then { msgtype: "text", text: { content: text } }
    else { text: text, title: Alerts::Message.subject(event, phase), level: event.level, kind: event.kind, url: Alerts::Message.url(event) }
    end
  end
  private_class_method :payload
end
