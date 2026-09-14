# 告警渠道（P2-③，设计 §7）：只从环境读；启动时把配置问题喊一声。test 里没配是常态，不喊
Rails.application.config.after_initialize do
  next if Rails.env.test?

  Alerts::Config.warnings.each { |warning| Rails.logger.warn { warning } }
  unless Alerts::Config.configured?
    Rails.logger.warn { "没有配置任何告警渠道（ALERT_EMAIL_TO + SMTP_ADDRESS，或 ALERT_WEBHOOK_URL），告警只记录不发送" }
  end
  if Rails.env.production? && ENV["BASE_URL"].blank?
    Rails.logger.warn { "BASE_URL 未配置，告警里的后台链接会指向 localhost" }
  end
end
