# 一次搜索的结果（设计 5.4）：entries 是这一页的记录（含全局名次与分数），total 是全部命中数，
# pages 封顶 50 页（R-4.7）；status 是 ok / timeout / error，后两者页面显示「搜索暂不可用」。
class Search::Result
  Entry = Data.define(:record, :rank, :score)

  attr_reader :entries, :total, :page, :latency_ms, :status

  def initialize(entries:, total:, page:, latency_ms:, status:)
    @entries = entries
    @total = total
    @page = page
    @latency_ms = latency_ms
    @status = status
  end

  def ok? = status == "ok"

  def pages = [ (total.to_f / Search::Runner::PER_PAGE).ceil, Search::Query::PAGES ].min
end
