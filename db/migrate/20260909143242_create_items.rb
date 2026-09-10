class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items, id: { type: :string, limit: 25 } do |t|
      t.string :source_id, limit: 25, null: false
      t.string :issue_id, limit: 25, null: false
      t.string :title, limit: 300, null: false
      t.string :url, limit: 2048, null: false
      t.string :url_hash, limit: 64, null: false
      t.string :summary, limit: 500
      t.string :section, limit: 100
      t.string :author, limit: 100
      t.datetime :published_at
      t.integer :rank
      t.jsonb :meta, null: false, default: {}
      t.datetime :fetched_at, null: false
      t.boolean :hidden, null: false, default: false
      t.string :reason, limit: 120
      t.string :interest_tag, limit: 20
      t.datetime :reason_generated_at
      t.timestamps
      t.index [ :source_id, :issue_id, :url_hash ], unique: true
      t.index [ :issue_id, :source_id, :rank ]
      t.foreign_key :sources
      t.foreign_key :issues
      t.check_constraint "length(title) <= 300", name: "items_title_len"
      t.check_constraint "length(url) <= 2048", name: "items_url_len"
      t.check_constraint "length(summary) <= 500", name: "items_summary_len"
    end
  end
end
