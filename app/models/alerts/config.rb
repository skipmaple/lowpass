# 渠道配置只从环境读（设计 B1、B14），进程内读一次；测试用 load! 换一份。
# 非法的值当没配，并留一句 warning 给初始化器打日志——启动时喊一声，比在第一条告警发不出去时才发现好
module Alerts::Config
  FORMATS = %w[ generic feishu wecom dingtalk ].freeze
  DEFAULT_BASE_URL = "http://localhost:3000".freeze

  class << self
    def load!(env = ENV)
      @warnings = []
      @base_url = env["BASE_URL"].presence || DEFAULT_BASE_URL
      @email_to = env["ALERT_EMAIL_TO"].to_s.split(",").map(&:strip).reject(&:blank?)
      @smtp_address = env["SMTP_ADDRESS"].presence
      # 这里不能调 host（它经 loaded 又会进 load!）：直接从刚读到的 @base_url 取主机名
      @email_from = env["ALERT_EMAIL_FROM"].presence || "lowpass@#{URI(@base_url).host}"
      @webhook_url = checked_webhook(env["ALERT_WEBHOOK_URL"])
      @webhook_format = env["ALERT_WEBHOOK_FORMAT"].presence || "generic"
      unless FORMATS.include?(@webhook_format)
        @warnings << "ALERT_WEBHOOK_FORMAT=#{@webhook_format} 不认识（#{FORMATS.join(' / ')}），按 generic 发"
        @webhook_format = "generic"
      end
      @warnings << "ALERT_EMAIL_TO 已配但 SMTP_ADDRESS 缺失，邮件渠道视为未配置" if @email_to.any? && @smtp_address.nil?
      @loaded = true
      self
    end

    def base_url = loaded && @base_url
    def host = URI(base_url).host
    def email_to = loaded && @email_to
    def email_from = loaded && @email_from
    def smtp_address = loaded && @smtp_address
    def webhook_url = loaded && @webhook_url
    def webhook_format = loaded && @webhook_format
    def warnings = loaded && @warnings

    def email? = email_to.any? && smtp_address.present?
    def webhook? = webhook_url.present?
    def configured? = email? || webhook?

    # 设置页的渠道状态（设计 §8）：邮件地址脱敏、webhook 只露主机名与格式
    def status_props
      { email: { configured: email?, label: email? ? email_to.map { |address| mask(address) }.join(" · ") : "未配置" },
        webhook: { configured: webhook?, label: webhook? ? "#{URI(webhook_url).host} · #{webhook_format}" : "未配置" } }
    end

    private
      def loaded
        load! unless @loaded
        true
      end

      def checked_webhook(url)
        return nil if url.blank?
        uri = URI(url)
        return url if uri.is_a?(URI::HTTPS) && uri.host.present?
        @warnings << "ALERT_WEBHOOK_URL 不是 https 地址，webhook 渠道视为未配置"
        nil
      rescue URI::Error
        @warnings << "ALERT_WEBHOOK_URL 不是 https 地址，webhook 渠道视为未配置"
        nil
      end

      # 不像地址的值（没有 @）整条盖掉：脱敏不该反过来把它原样贴到设置页上
      def mask(address)
        local, domain = address.split("@", 2)
        if domain.present?
          "#{local.to_s[0]}***@#{domain}"
        else
          "***"
        end
      end
  end
end
