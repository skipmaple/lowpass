class AddContentToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :content, :text, limit: 50_000
    add_check_constraint :items, "length(content) <= 50000", name: "items_content_len"
  end
end
