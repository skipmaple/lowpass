# 每日备份的记录（F-26、N-6，设计 docs/superpowers/specs/2026-09-28-p3-backup-health-design.md §2.2）：
# 一次备份一条，重试沿用同一条；保留 30 天
class CreateBackupRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_runs, id: { type: :string, limit: 25 } do |t|
      t.string :trigger, limit: 10, null: false
      t.string :status, limit: 10, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :duration_ms
      t.bigint :size_bytes
      t.string :object_key, limit: 255
      t.string :error_summary, limit: 200
      t.timestamps

      t.index :created_at
      t.check_constraint "trigger IN ('scheduled', 'manual')", name: "backup_runs_trigger"
      t.check_constraint "status IN ('queued', 'running', 'succeeded', 'failed')", name: "backup_runs_status"
      t.check_constraint "length(object_key) <= 255", name: "backup_runs_object_key_len"
      t.check_constraint "length(error_summary) <= 200", name: "backup_runs_error_summary_len"
    end
  end
end
