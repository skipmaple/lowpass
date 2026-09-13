# 附录 A 的 AuditLog（5.6：写操作全部记审计，操作者、时间、对象、内容；保留 90 天）；
# R-3.8 同一刊物内 feed 地址唯一：只对 RSS 源生效的表达式索引
class CreateAuditLogsAndFeedIndex < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs, id: { type: :string, limit: 25 } do |t|
      t.string :user_id, limit: 25
      t.string :action, limit: 50, null: false
      t.string :target, limit: 100, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false

      t.index :created_at
      t.index :user_id
      t.check_constraint "length(action) <= 50", name: "audit_logs_action_len"
      t.check_constraint "length(target) <= 100", name: "audit_logs_target_len"
    end
    add_foreign_key :audit_logs, :users, on_delete: :nullify

    add_index :sources, "publication, (config->>'feed_url')", unique: true, where: "adapter = 'rss'", name: "index_sources_on_publication_and_feed_url"
  end
end
