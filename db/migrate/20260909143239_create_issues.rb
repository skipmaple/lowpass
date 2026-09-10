class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues, id: { type: :string, limit: 25 } do |t|
      t.string :kind, limit: 10, null: false          # daily / weekly
      t.string :period_key, limit: 10, null: false
      t.string :state, limit: 12, null: false, default: "generating"  # generating / published / empty
      t.datetime :published_at
      t.datetime :revised_at
      t.datetime :generation_started_at, null: false
      t.boolean :generated_late, null: false, default: false
      t.timestamps
      t.index [ :kind, :period_key ], unique: true
      t.check_constraint "state IN ('generating', 'published', 'empty')", name: "issues_state"
    end
  end
end
