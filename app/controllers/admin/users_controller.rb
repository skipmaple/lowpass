# 用户（5.6）：只读
class Admin::UsersController < Admin::BaseController
  def index
    rows = User.admin_rows
    render inertia: "Admin/Users/Index", props: { users: rows, summary: "#{rows.size} 个用户 · 只读" }
  end
end
