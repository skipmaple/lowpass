class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings, id: { type: :string, limit: 25 } do |t|
      t.string :key, limit: 50, null: false
      t.string :value, limit: 255, null: false
      t.timestamps
      t.index :key, unique: true
    end
  end
end
