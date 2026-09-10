class CreateFetchRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :fetch_runs, id: { type: :string, limit: 25 } do |t|
      t.string :source_id, limit: 25, null: false
      t.string :issue_id, limit: 25
      t.string :trigger, limit: 10, null: false       # scheduled / manual / test
      t.integer :attempt, null: false, default: 1
      t.string :status, limit: 10, null: false        # queued / running / succeeded / failed / timed_out
      t.datetime :started_at
      t.integer :duration_ms
      t.integer :item_count
      t.integer :dropped_count
      t.string :error_summary, limit: 200
      t.timestamps
      t.index [ :source_id, :created_at ]
      t.foreign_key :sources
      t.foreign_key :issues
    end
  end
end
