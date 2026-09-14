# 告警事件（PRD 5.7、附录 A）：一条 = 某 kind 在某范围（源 / 期 / 全局）某一上海日发生过；
# dedup_key 的唯一索引就是 R-7.1 的「只发一次」，recovered_at 记条件消失、发过「已恢复」。保留 90 天
class AlertEvent < ApplicationRecord
  RETENTION = 90.days
  KINDS = %w[ source_failed parse_degraded issue_empty issue_late search_unavailable backup_failed reasons_missing test ].freeze
  LEVELS = %w[ warning critical info ].freeze
  KIND_LABELS = { "source_failed" => "源抓取失败", "parse_degraded" => "解析退化", "issue_empty" => "空刊", "issue_late" => "日刊延迟生成",
                  "search_unavailable" => "搜索不可用", "backup_failed" => "备份失败", "reasons_missing" => "推荐理由缺失", "test" => "测试告警" }.freeze
  LEVEL_LABELS = { "warning" => "警告", "critical" => "严重", "info" => "提示" }.freeze
  # 有「已恢复」语义的 kind（设计 B8）
  RECOVERABLE = %w[ source_failed parse_degraded issue_empty search_unavailable reasons_missing ].freeze

  belongs_to :source, optional: true
  belongs_to :issue, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :level, inclusion: { in: LEVELS }
  validates :summary, length: { maximum: 200 }
  validates :url_path, length: { maximum: 200 }
  validates :dedup_key, presence: true, length: { maximum: 120 }
  validates :delivery_error, length: { maximum: 200 }, allow_nil: true

  scope :stale, -> { where(created_at: ...RETENTION.ago) }
  scope :open_for, ->(kind, source = nil) { where(kind: kind, source_id: source&.id, recovered_at: nil) }

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end

  def kind_label = KIND_LABELS.fetch(kind)
  def level_label = LEVEL_LABELS.fetch(level)
  def recoverable? = RECOVERABLE.include?(kind)
  def delivered?(channel, phase) = delivered.include?("#{channel}:#{phase}")
end
