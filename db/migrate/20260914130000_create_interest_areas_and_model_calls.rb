# 附录 A 的 InterestArea（5.9 兴趣画像，全局一份，D18）与模型调用账本（R-9.8：次数与费用在后台可见，保留 90 天）
class CreateInterestAreasAndModelCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :interest_areas, id: { type: :string, limit: 25 } do |t|
      t.string :name, limit: 20, null: false
      t.string :keywords, limit: 200, null: false, default: ""
      t.integer :sort_order, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.timestamps

      t.index "lower(name)", unique: true, name: "index_interest_areas_on_lower_name"
      t.check_constraint "length(name) <= 20", name: "interest_areas_name_len"
      t.check_constraint "length(keywords) <= 200", name: "interest_areas_keywords_len"
    end

    create_table :model_calls, id: { type: :string, limit: 25 } do |t|
      t.string :issue_id, limit: 25
      t.string :item_id, limit: 25
      t.string :status, limit: 10, null: false
      t.integer :prompt_tokens, null: false, default: 0
      t.integer :completion_tokens, null: false, default: 0
      t.decimal :cost, precision: 10, scale: 4, null: false, default: 0
      t.integer :duration_ms
      t.string :error_summary, limit: 200
      t.datetime :created_at, null: false

      t.index :created_at
      t.index :issue_id
      t.check_constraint "status IN ('ok', 'failed', 'timed_out', 'invalid')", name: "model_calls_status"
      t.check_constraint "length(error_summary) <= 200", name: "model_calls_error_summary_len"
    end
    add_foreign_key :model_calls, :issues, on_delete: :nullify
    add_foreign_key :model_calls, :items, on_delete: :nullify
  end
end
