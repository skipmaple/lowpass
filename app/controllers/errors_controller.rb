# 站内没有这条地址（routes.rb 末尾的兜底路由）。日刊、周刊里形状不对的周期键与越界的
# 月份、年份也渲染同一页，见 ApplicationController#render_not_found。
class ErrorsController < ApplicationController
  def not_found
    render_not_found
  end
end
