# D25 标题译文：Hacker News 条目生成推荐理由的那次调用顺带给出标题的简体中文译文，发布后可补写（R-9.7）。
# 上限与标题同为 300 字符（7.2）
class AddTitleZhToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :title_zh, :string, limit: 300
    add_check_constraint :items, "length(title_zh) <= 300", name: "items_title_zh_len"
  end
end
