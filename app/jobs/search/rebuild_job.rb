# 后台重建搜索索引：迁移后的一次性步骤走 bin/rails search:rebuild，这个 job 留给 P2 的管理页；
# 同时只允许一份在跑，两份一起清空重建会互相覆盖
class Search::RebuildJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: -> { "search_rebuild" }, duration: 30.minutes

  def perform = Search::Record.rebuild!
end
