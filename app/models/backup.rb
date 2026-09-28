# 每日备份（F-26、N-6，设计 docs/superpowers/specs/2026-09-28-p3-backup-health-design.md）：主库 pg_dump → 加密 → 上传到
# S3 兼容的对象存储。一次备份的流程在 BackupRun#perform_now，这里只有错误分类与「该不该有备份」
module Backup
  Error = Class.new(StandardError)       # 终态：记失败、告警
  Transient = Class.new(Error)           # 上传遇到 5xx、网络错误、超时：job 再试（设计 E7）

  # 设计 E8：production 一定要有备份，没配就是 N-6 不达标，要记失败、要告警；别的环境配了才算
  def self.expected? = Rails.env.production? || Config.any_given?

  # 记录与告警里的一句话：自己抛的错已经是中文句子，别的异常带上类名；只留首行，截到 200（error_summary 列）
  def self.summary(error)
    text = error.is_a?(Error) ? error.message : "#{error.class}: #{error.message}"
    text.to_s.lines.first.to_s.strip[0, 200]
  end
end
