# 备份一次（设计 §2.1）：做事在 BackupRun#perform_now，这里只管重试与告警（E7）。上传的暂时性故障再试两次，
# 其余立即算失败；失败与重试耗尽都告警一次（「备份失败」按日去重、没有「已恢复」，设计 B8），再照常抛出，队列面板里看得见
class BackupJob < ApplicationJob
  queue_as :default
  # 同时只有一份备份在跑：两份一起导出、一起上传只是白占 CPU 与带宽
  limits_concurrency to: 1, key: ->(_run) { "backup" }, duration: 30.minutes
  WAITS = [ 2.minutes, 10.minutes ].freeze
  MAX_ATTEMPTS = 3

  retry_on Backup::Transient, wait: ->(executions) { WAITS[executions - 1] || WAITS.last }, attempts: MAX_ATTEMPTS do |job, error|
    Alerts.backup_failed!(job.arguments.first.error_summary.presence || Backup.summary(error))
    raise error
  end

  def perform(run)
    run.perform_now(attempt: executions)
  rescue Backup::Transient
    # 还要再试：记录回到「排队」，后台看到的是在等重试，不是一次已经失败的备份
    run.update!(status: "queued") if executions < MAX_ATTEMPTS
    raise
  rescue StandardError => e
    Alerts.backup_failed!(run.error_summary.presence || Backup.summary(e))
    raise
  end
end
