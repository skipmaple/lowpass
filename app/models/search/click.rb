# 9.1 的 search_click：点了标题或原文才记（所在期直链不计）；查询词是快照，不连搜索日志；
# 保留 90 天（9.1 埋点保留期），Scheduler 每天清一次。
class Search::Click < ApplicationRecord
  RETENTION = 90.days

  belongs_to :item

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  # 条目不存在（已删、乱填）就不记，也不报错：埋点不影响读者。exists? 到 create! 之间条目可能刚被修订删掉，
  # belongs_to 的存在性校验（RecordInvalid）与外键报错（InvalidForeignKey，理论上校验之后、写入之前那一瞬间
  # 才被删）都当不存在；savepoint 让这一次失败不拖累外层事务
  def self.record(item_id:, rank:, query:)
    transaction(requires_new: true) do
      create!(item_id: item_id, rank: rank, query: query) if Item.exists?(id: item_id)
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey
    nil
  end

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
