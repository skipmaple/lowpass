# D25 说明译文：GitHub Trending 的标题是仓库名，译的是仓库简介（summary）；跟推荐理由同一次生成，发布后可补写（R-9.7）。
# 上限与说明同为 500 字符（7.2）
class AddSummaryZhToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :summary_zh, :string, limit: 500
    add_check_constraint :items, "length(summary_zh) <= 500", name: "items_summary_zh_len"
  end
end
