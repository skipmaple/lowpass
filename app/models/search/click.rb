# 9.1 的 search_click：点了标题或原文才记（所在期直链不计）；查询词是快照，不连搜索日志；
# 保留 90 天（9.1 埋点保留期），Scheduler 每天清一次。
class Search::Click < ApplicationRecord
  RETENTION = 90.days

  belongs_to :item

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  # 条目不存在（已删、乱填）就不记，也不报错：埋点不影响读者
  def self.record(item_id:, rank:, query:)
    create!(item_id: item_id, rank: rank, query: query) if Item.exists?(id: item_id)
  end

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
