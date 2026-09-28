# 备份（P3，设计 docs/superpowers/specs/2026-09-28-p3-backup-health-design.md §2.5）：配置只从环境读，启动时把问题喊一声。
# production 没配就是 N-6 不达标（E8）：每天 03:00 会记一次失败并告警。test 里没配是常态，不喊
Rails.application.config.after_initialize do
  next if Rails.env.test?

  if Backup::Config.any_given? && !Backup::Config.configured?
    Rails.logger.warn { "备份配置不完整：#{Backup::Config.problems.join('、')}" }
  elsif Rails.env.production? && !Backup::Config.configured?
    Rails.logger.warn { "没有配置备份（BACKUP_*），每天 03:00 会记一次失败并告警" }
  end
end
