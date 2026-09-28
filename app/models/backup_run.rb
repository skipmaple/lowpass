require "tmpdir"

# 一次备份（设计 §2.1、§2.2）：create_later 建记录并入队，BackupJob 调 perform_now 真正去做；重试沿用同一条记录。
# 临时文件都在 tmp/ 下的临时目录里，成败都删；保留 30 天，随 04:00 清理
class BackupRun < ApplicationRecord
  RETENTION = 30.days
  # 排队或在跑、却 30 分钟没有动静：进程在备份途中被杀、job 丢了，都会留下这样的记录（设计 §2.2）
  STALL_AFTER = 30.minutes
  ACTIVE = %w[ queued running ].freeze
  STATUS_LABELS = { "queued" => "排队", "running" => "进行中", "succeeded" => "成功", "failed" => "失败" }.freeze

  validates :trigger, inclusion: { in: %w[ scheduled manual ] }
  validates :status, inclusion: { in: STATUS_LABELS.keys }
  validates :object_key, length: { maximum: 255 }, allow_nil: true
  validates :error_summary, length: { maximum: 200 }, allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :stale, -> { where(created_at: ...RETENTION.ago) }
  scope :succeeded, -> { where(status: "succeeded") }
  scope :active, -> { where(status: ACTIVE, updated_at: STALL_AFTER.ago..) }

  # 入队失败就把记录删掉再抛出：调度的下一分钟会重来，不留一条永远排着队的记录
  def self.create_later(trigger:)
    run = create!(trigger: trigger, status: "queued")
    if BackupJob.perform_later(run)
      run
    else
      run.destroy!
      raise Backup::Error, "备份没能入队"
    end
  end

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end

  def perform_now(attempt: 1)
    started = now_ms
    update!(status: "running", attempts: attempt, started_at: Time.current, finished_at: nil, error_summary: nil)
    raise Backup::Error, "未配置备份：#{Backup::Config.problems.join('、')}" unless Backup::Config.configured?

    Dir.mktmpdir("backup-", Rails.root.join("tmp")) do |dir|
      dump = File.join(dir, "lowpass.dump")
      encrypted = "#{dump}.enc"
      Backup::Dump.write(dump)
      Lowpass::BackupCipher.encrypt(dump, encrypted, key: Backup::Config.encryption_key)
      name = object_name
      Backup::Storage.put(name, encrypted)
      update!(status: "succeeded", object_key: name, size_bytes: File.size(encrypted), duration_ms: now_ms - started, finished_at: Time.current)
    end
  rescue StandardError => e
    record_failure(e)
    raise
  end

  def stalled? = status.in?(ACTIVE) && updated_at < STALL_AFTER.ago
  def status_label = stalled? ? "未完成" : STATUS_LABELS.fetch(status)

  # 对象名：库名加这一次开始的 UTC 时间，存储的控制台里按名字排就是按时间排
  def object_name = "#{ActiveRecord::Base.connection_db_config.database}-#{started_at.utc.strftime('%Y%m%dT%H%M%SZ')}.dump.enc"

  private
    # 记失败本身出错（多半是数据库也挂了）只报告，不能盖掉真正的原因
    def record_failure(error)
      update!(status: "failed", error_summary: Backup.summary(error), finished_at: Time.current)
    rescue ActiveRecord::ActiveRecordError => e
      Rails.error.report(e, handled: true, context: { backup_run: id })
    end

    def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
end
