# 附录 A 的 AlertEvent（5.7）：去重（同 kind 同范围同一上海日一条）与「已恢复」的账本；保留 90 天
class CreateAlertEvents < ActiveRecord::Migration[8.1]
  KINDS = %w[ source_failed parse_degraded issue_empty issue_late search_unavailable backup_failed reasons_missing test ].freeze

  def change
    create_table :alert_events, id: { type: :string, limit: 25 } do |t|
      t.string :kind, limit: 40, null: false
      t.string :level, limit: 10, null: false
      t.string :source_id, limit: 25
      t.string :issue_id, limit: 25
      t.string :summary, limit: 200, null: false, default: ""
      t.string :url_path, limit: 200, null: false, default: ""
      t.string :dedup_key, limit: 120, null: false
      t.jsonb :delivered, null: false, default: []
      t.datetime :sent_at
      t.datetime :recovered_at
      t.datetime :recovery_sent_at
      t.string :delivery_error, limit: 200
      t.integer :attempts, null: false, default: 0
      t.timestamps

      t.index :dedup_key, unique: true
      t.index [ :kind, :source_id, :recovered_at ]
      t.index :created_at
      t.check_constraint "kind IN (#{KINDS.map { |k| "'#{k}'" }.join(', ')})", name: "alert_events_kind"
      t.check_constraint "level IN ('warning', 'critical', 'info')", name: "alert_events_level"
      t.check_constraint "length(summary) <= 200", name: "alert_events_summary_len"
      t.check_constraint "length(url_path) <= 200", name: "alert_events_url_path_len"
      t.check_constraint "length(dedup_key) <= 120", name: "alert_events_dedup_key_len"
      t.check_constraint "length(delivery_error) <= 200", name: "alert_events_delivery_error_len"
    end
    add_foreign_key :alert_events, :sources, on_delete: :nullify
    add_foreign_key :alert_events, :issues, on_delete: :nullify
  end
end
