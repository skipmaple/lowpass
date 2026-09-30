# 收藏（PRD 5.10，设计 docs/superpowers/specs/2026-09-30-favorites-design.md §3）：一人一链接一条，带收藏时的快照。
# 不引用条目行：管理员重抓会整栏换掉条目的 id（Issue::Sections#replace_section!），收藏按 url_hash 认（D27）。
# 只有 created_at：一行写完不再改
class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites, id: { type: :string, limit: 25 } do |t|
      t.string :user_id, limit: 25, null: false
      t.string :url_hash, limit: 64, null: false
      t.string :url, limit: 2048, null: false
      t.string :title, limit: 300, null: false
      t.string :title_zh, limit: 300
      t.string :summary, limit: 500
      t.string :summary_zh, limit: 500
      t.string :source_id, limit: 25, null: false
      t.string :publication, limit: 10, null: false
      t.string :period_key, limit: 10, null: false
      t.string :section, limit: 100
      t.string :anchor, limit: 120
      t.datetime :created_at, null: false

      t.index [ :user_id, :url_hash ], unique: true
      t.index [ :user_id, :created_at ]
      t.foreign_key :users, on_delete: :cascade
      t.foreign_key :sources
      t.check_constraint "publication IN ('daily', 'weekly')", name: "favorites_publication"
      t.check_constraint "length(url_hash) = 64", name: "favorites_url_hash_len"
      t.check_constraint "length(url) <= 2048", name: "favorites_url_len"
      t.check_constraint "length(title) <= 300", name: "favorites_title_len"
      t.check_constraint "length(title_zh) <= 300", name: "favorites_title_zh_len"
      t.check_constraint "length(summary) <= 500", name: "favorites_summary_len"
      t.check_constraint "length(summary_zh) <= 500", name: "favorites_summary_zh_len"
      t.check_constraint "length(section) <= 100", name: "favorites_section_len"
      t.check_constraint "length(anchor) <= 120", name: "favorites_anchor_len"
    end
  end
end
