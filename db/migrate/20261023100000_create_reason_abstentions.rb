class CreateReasonAbstentions < ActiveRecord::Migration[8.1]
  def change
    create_table :reason_abstentions, id: { type: :string, limit: 25 } do |t|
      t.string :item_id, limit: 25, null: false
      t.datetime :assessed_at, null: false
      t.timestamps

      t.index :item_id, unique: true
      t.foreign_key :items, on_delete: :cascade
      t.check_constraint "length(id) = 25", name: "reason_abstentions_id_len"
      t.check_constraint "length(item_id) = 25", name: "reason_abstentions_item_id_len"
    end
  end
end
