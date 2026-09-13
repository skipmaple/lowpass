# D12：明文查询词，不存用户、不存 IP；每次真的执行了的搜索一行（空查询与限流不记），
# 不可用态也记但 result_count 为空。保留 30 天，Scheduler 每天清一次。
class Search::Log < ApplicationRecord
  RETENTION = 30.days

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  def self.record(query, result)
    create!(query: query.q, filters: query.log_filters, result_count: (result.total if result.ok?), latency_ms: result.latency_ms, page: query.page)
  end

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end
