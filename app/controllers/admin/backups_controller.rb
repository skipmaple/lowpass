# 设置页「立即备份」（设计 §2.6、E10）：配好之后马上验证，不用等到 03:00；做高风险操作之前也用得上。
# 同时只有一份备份在跑；每分钟 5 次
class Admin::BackupsController < Admin::BaseController
  rate_limit to: 5, within: 1.minute, by: -> { Current.user.id }, with: -> { redirect_to admin_settings_path, alert: "操作过于频繁，请稍后再试。" }

  def create
    if !Backup::Config.configured?
      redirect_to admin_settings_path, alert: "备份未配置"
    elsif BackupRun.active.exists?
      redirect_to admin_settings_path, alert: "已有备份在进行"
    else
      run = BackupRun.create_later(trigger: "manual")
      Audit.record("backup.create", "BackupRun##{run.id}")
      redirect_to admin_settings_path, notice: "已开始备份"
    end
  rescue Backup::Error => e
    redirect_to admin_settings_path, alert: e.message
  end
end
