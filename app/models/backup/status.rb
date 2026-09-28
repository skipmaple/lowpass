# 设置页「备份」一节的 props（设计 §2.6）：配置状态（不含任何密钥）、最近一次与最近成功；句子在这里拼好，前端直接画
module Backup::Status
  def self.props
    last = BackupRun.ordered.first
    succeeded_at = BackupRun.succeeded.maximum(:finished_at)
    {
      configured: Backup::Config.configured?,
      problems: Backup::Config.any_given? ? Backup::Config.problems : [],
      storage: Backup::Config.storage_label,
      key_fingerprint: Backup::Config.key_fingerprint,
      last: last && { status: last.stalled? ? "stalled" : last.status, summary: summary(last) },
      last_succeeded: succeeded_at && stamp(succeeded_at),
      active: BackupRun.active.exists?
    }
  end

  # 「9月28日 03:00 · 成功 · 12.3 MB · 用时 8 秒」「9月28日 03:00 · 失败：上传失败（403）：AccessDenied」
  def self.summary(run)
    parts = [ stamp(run.started_at || run.created_at) ]
    if run.status == "succeeded"
      parts += [ run.status_label, ActiveSupport::NumberHelper.number_to_human_size(run.size_bytes), "用时 #{(run.duration_ms / 1000.0).ceil} 秒" ]
    elsif run.status == "failed"
      parts << "#{run.status_label}：#{run.error_summary}"
    else
      parts << run.status_label
    end
    parts.join(" · ")
  end

  def self.stamp(time)
    local = time.in_time_zone(PeriodKey::ZONE)
    "#{local.month}月#{local.day}日 #{local.strftime('%H:%M')}"
  end
  private_class_method :summary, :stamp
end
