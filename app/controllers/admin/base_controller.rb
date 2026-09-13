# /admin 下所有控制器的基类（AGENTS.md：只给白名单推导出的 admin，其他人 403）。mission_control-jobs 的控制器也继承它
# （config/application.rb 的 base_controller_class）。not_found 接 /admin 下没有页面的路径：admin 看到 404，成员先被 403 拦住。
class Admin::BaseController < ApplicationController
  before_action :require_admin

  def not_found
    render_not_found
  end

  private
    def require_admin
      render_forbidden unless Current.admin?
    end
end
