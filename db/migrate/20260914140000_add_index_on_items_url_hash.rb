# 跨天沿用理由（R-1.11）按裸 url_hash 查更早的日刊：复合索引 (source_id, issue_id, url_hash) 的前缀对不上，
# 只能顺序扫全表——条目表是全站最大的一张，加一个单列索引
class AddIndexOnItemsUrlHash < ActiveRecord::Migration[8.1]
  def change
    add_index :items, :url_hash
  end
end
