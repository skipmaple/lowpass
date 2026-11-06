class AddIndependentTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_preservations, id: :string, limit: 25 do |t|
      t.string :item_id, limit: 25, null: false
      t.string :field, limit: 7, null: false
      t.string :input_digest, limit: 64, null: false
      t.datetime :assessed_at, null: false
      t.timestamps
    end
    add_index :translation_preservations, [ :item_id, :field ], unique: true
    add_foreign_key :translation_preservations, :items, on_delete: :cascade
    add_check_constraint :translation_preservations, "field IN ('title', 'summary')", name: "translation_preservations_field"
    add_check_constraint :translation_preservations, "input_digest ~ '^[0-9a-f]{64}$'", name: "translation_preservations_digest"
    add_column :model_calls, :purpose, :string, limit: 11, null: false, default: "reason"
    add_column :model_calls, :operation_key, :string, limit: 36
    add_column :model_calls, :input_field, :string, limit: 7
    add_column :model_calls, :input_digest, :string, limit: 64
    add_index :model_calls, [ :operation_key, :purpose, :item_id, :input_field ], name: "index_model_calls_on_operation_target"
    add_check_constraint :model_calls, "purpose IN ('reason', 'translation')", name: "model_calls_purpose"
    add_check_constraint :model_calls, "purpose != 'translation' OR (operation_key IS NOT NULL AND length(operation_key) > 0 AND input_field IS NOT NULL AND input_field IN ('title', 'summary') AND input_digest IS NOT NULL AND input_digest ~ '^[0-9a-f]{64}$')", name: "model_calls_translation_target"
    { purpose: 11, operation_key: 36, input_field: 7, input_digest: 64 }.each do |field, limit|
      add_check_constraint :model_calls, "length(#{field}) <= #{limit}", name: "model_calls_#{field}_len"
    end
    { id: 25, item_id: 25, field: 7, input_digest: 64 }.each do |field, limit|
      add_check_constraint :translation_preservations, "length(#{field}) <= #{limit}", name: "translation_preservations_#{field}_len"
    end
  end
end
