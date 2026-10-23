# 已发布条目的展示缓存：只记天然尺寸与探测时机，不回写 Item / Issue，也不保存图像。
class CreateImageDimensions < ActiveRecord::Migration[8.1]
  def change
    create_table :image_dimensions, id: { type: :string, limit: 25 } do |t|
      t.string :url, limit: 2048, null: false
      t.string :url_hash, limit: 64, null: false
      t.integer :width
      t.integer :height
      t.datetime :confirmed_at
      t.datetime :retry_at
      t.datetime :queued_at
      t.timestamps

      t.index :url_hash, unique: true
      t.check_constraint "length(url) BETWEEN 1 AND 2048", name: "image_dimensions_url_len"
      t.check_constraint "url_hash ~ '^[0-9a-f]{64}$'", name: "image_dimensions_url_hash"
      t.check_constraint "(width IS NULL AND height IS NULL AND confirmed_at IS NULL) OR " \
        "(width IS NOT NULL AND height IS NOT NULL AND confirmed_at IS NOT NULL AND " \
        "width BETWEEN 1 AND 100000 AND height BETWEEN 1 AND 100000)", name: "image_dimensions_size"
    end
  end
end
