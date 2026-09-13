# 搜索（PRD 5.4，设计 docs/superpowers/specs/2026-09-11-p1-search-design.md）：
# 索引副本 Search::Record、查询解析 Search::Query、执行 Search::Runner、高亮 Search::Highlighter、
# 日志 Search::Log 与点击 Search::Click。表名统一带 search_ 前缀。
module Search
  def self.table_name_prefix = "search_"
end
