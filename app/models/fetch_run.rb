class FetchRun < ApplicationRecord
  belongs_to :source
  belongs_to :issue, optional: true

  RETENTION = 30.days
  STATUS_LABELS = { "queued" => "排队", "running" => "运行中", "succeeded" => "成功", "failed" => "失败", "timed_out" => "超时" }.freeze
  TRIGGER_LABELS = { "scheduled" => "调度", "manual" => "手动", "test" => "测试" }.freeze

  validates :trigger, inclusion: { in: %w[ scheduled manual test ] }
  validates :status, inclusion: { in: %w[ queued running succeeded failed timed_out ] }

  scope :ordered, -> { order(created_at: :desc) }
  scope :stale,   -> { where(created_at: ...RETENTION.ago) }
  scope :active,  -> { where(status: %w[ queued running ]) }
  # 后台轮询用：手动任务在 60 秒内有过更新——刚结束的弹一次提示，还在跑的让页面继续轮询
  scope :manual_recent, -> { where(trigger: "manual").where(updated_at: 60.seconds.ago..) }

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end

  # 后台轮询与提示（设计 6.3）：进行中的让页面继续轮询并禁用按钮，刚结束的弹一次「已更新 / 重抓失败」
  def self.manual_run_props(scope)
    runs = scope.includes(:source, :issue).to_a
    active, finished = runs.partition { |run| run.status.in?(%w[ queued running ]) }
    {
      active: active.map { |run| { id: run.id, source_name: run.source.name, period_key: run.issue&.period_key } },
      finished: finished.map { |run| { id: run.id, source_name: run.source.name, status: run.status, item_count: run.item_count, error_summary: run.error_summary } }
    }
  end

  def status_label = STATUS_LABELS.fetch(status)
  def trigger_label = TRIGGER_LABELS.fetch(trigger)
end
