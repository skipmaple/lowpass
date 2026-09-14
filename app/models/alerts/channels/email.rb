# 邮件渠道：SMTP 配置在 config/environments/production.rb 从环境读；同步发，重试由 DeliverAlertJob 管
module Alerts::Channels::Email
  NAME = "email".freeze

  def self.configured? = Alerts::Config.email?

  def self.deliver(event, phase)
    AlertMailer.event(event, phase).deliver_now
  rescue StandardError => e
    raise Alerts::DeliveryError, "email #{e.class}: #{e.message}"[0, 200]
  end
end
