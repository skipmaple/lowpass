class CreateSearchTables < ActiveRecord::Migration[8.1]
  # 搜索走 PostgreSQL 内建（ADR T7、设计文档第 2 节）：pg_trgm 是自带的 contrib 扩展，
  # 开发容器与生产 accessory 都用超级用户连接，可以直接启用；唯一启用的扩展就是它。
  def change
    enable_extension "pg_trgm"

    # 条目的搜索副本（设计 3.1）：与 items 分开，不为搜索改条目表；条目删了索引行随外键级联消失。
    # 四个可搜列各一个 trigram GIN 索引：~*（词首前缀）、<%（word_similarity）与 ILIKE 都能走它。
    create_table :search_records, id: { type: :string, limit: 25 } do |t|
      t.string :item_id, limit: 25, null: false
      t.string :issue_id, limit: 25, null: false
      t.string :source_id, limit: 25, null: false
      t.string :publication, limit: 10, null: false
      t.string :period_key, limit: 10, null: false
      t.date :published_on, null: false
      t.string :title, limit: 300, null: false
      t.string :section, limit: 100
      t.string :source_name, limit: 100, null: false
      t.string :summary, limit: 500
      t.string :anchor, limit: 120
      t.timestamps
      t.index :item_id, unique: true
      t.index [ :publication, :published_on ]
      t.index :source_id
      t.index :issue_id
      t.index :title, using: :gin, opclass: :gin_trgm_ops, name: "index_search_records_on_title_trgm"
      t.index :section, using: :gin, opclass: :gin_trgm_ops, name: "index_search_records_on_section_trgm"
      t.index :source_name, using: :gin, opclass: :gin_trgm_ops, name: "index_search_records_on_source_name_trgm"
      t.index :summary, using: :gin, opclass: :gin_trgm_ops, name: "index_search_records_on_summary_trgm"
      t.foreign_key :items, on_delete: :cascade
      t.foreign_key :issues, on_delete: :cascade
      t.foreign_key :sources
      t.check_constraint "publication IN ('daily', 'weekly')", name: "search_records_publication"
      t.check_constraint "length(title) <= 300", name: "search_records_title_len"
      t.check_constraint "length(section) <= 100", name: "search_records_section_len"
      t.check_constraint "length(source_name) <= 100", name: "search_records_source_name_len"
      t.check_constraint "length(summary) <= 500", name: "search_records_summary_len"
      t.check_constraint "length(anchor) <= 120", name: "search_records_anchor_len"
    end

    # 搜索日志（D12）：明文查询词，不存用户、不存 IP，保留 30 天。只有 created_at：一行写完不再改。
    create_table :search_logs, id: { type: :string, limit: 25 } do |t|
      t.string :query, limit: 100, null: false
      t.jsonb :filters, null: false, default: {}
      t.integer :result_count
      t.integer :latency_ms, null: false
      t.integer :page, null: false, default: 1
      t.datetime :created_at, null: false
      t.index :created_at
      t.check_constraint "length(query) <= 100", name: "search_logs_query_len"
    end

    # 结果点击（9.1 的 search_click）：查询词是快照，不连搜索日志，日志先过期也不受影响；保留 90 天
    create_table :search_clicks, id: { type: :string, limit: 25 } do |t|
      t.string :query, limit: 100, null: false
      t.integer :rank, null: false
      t.string :item_id, limit: 25, null: false
      t.datetime :created_at, null: false
      t.index :created_at
      t.index :item_id
      t.foreign_key :items, on_delete: :cascade
      t.check_constraint "length(query) <= 100", name: "search_clicks_query_len"
    end
  end
end
