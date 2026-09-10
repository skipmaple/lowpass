# R-4.8 索引跟着条目走：单条建、改（推荐理由补写、下架）在事务提交后同步到 Search::Record；
# 删除由外键级联，不在这里处理。装订走 insert_all!，不经过回调，由 Issue::Sections 批量索引。
#
# 用 after_save_commit（on: [:create, :update]）而不是分开写 after_create_commit /
# after_update_commit 两行：两次 set_callback 用同一个方法名做 filter 时，Rails 的回调链去重
# （ActiveSupport::Callbacks::Callback#duplicates? 只比较 kind 与 filter，不看 on: 各自的条件）
# 会把后声明的当成「替换」先声明的，新建条目那次回调直接被顶掉、永远不会进索引。
module Searchable
  extend ActiveSupport::Concern

  included do
    after_save_commit :index_for_search
  end

  def index_for_search
    Search::Record.index!(self)
  end
end
