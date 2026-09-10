class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources, id: { type: :string, limit: 25 } do |t|
      t.string :name, limit: 100, null: false
      t.string :adapter, limit: 40, null: false      # hacker_news / github_trending / rss / ruanyf_weekly
      t.string :publication, limit: 10, null: false  # daily / weekly
      t.jsonb :config, null: false, default: {}
      t.integer :sort_order, null: false, default: 100
      t.boolean :enabled, null: false, default: true
      t.timestamps
      t.index :name, unique: true
      t.check_constraint "publication IN ('daily', 'weekly')", name: "sources_publication"
    end
  end
end
