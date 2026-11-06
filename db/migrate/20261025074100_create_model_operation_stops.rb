class CreateModelOperationStops < ActiveRecord::Migration[8.1]
  def change
    create_table :model_operation_stops, id: :string, limit: 25 do |t|
      t.string :operation_key, limit: 36, null: false
      t.string :reason, limit: 8, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :model_operation_stops, :operation_key, unique: true
    add_index :model_operation_stops, :expires_at
    add_check_constraint :model_operation_stops, "reason IN ('budget', 'rejected', 'limited')", name: "model_operation_stops_reason"
    { id: 25, operation_key: 36, reason: 8 }.each do |field, limit|
      add_check_constraint :model_operation_stops, "length(#{field}) BETWEEN 1 AND #{limit}", name: "model_operation_stops_#{field}_len"
    end
  end
end
