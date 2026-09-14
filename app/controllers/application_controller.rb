class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  prepend_before_action :set_current_request_details

  # 每个 Inertia 页都带的两样（设计第 5 节）：报头头像菜单要的当前用户，登录页与设置页要的 flash
  inertia_share do
    {
      current_user: Current.user && {
        display_name: Current.user.display_name, avatar_url: Current.user.avatar_url,
        email: Current.user.email, admin: Current.user.admin?
      },
      flash: { notice: flash[:notice], alert: flash[:alert] }.compact
    }
  end

  private
    def set_current_request_details
      Current.request_id = request.uuid
      Current.ip_address = request.remote_ip
      Current.user_agent = request.user_agent
    end

    # 页脚每页都要的两样：下一期日刊几点出、最新一期周刊落在哪（R51）。
    # 日刊详情不用这个：它的 daily_time 已经在期头的 props 里（daily_props_for）。
    def footer_props
      { daily_time: Setting.get("daily_time"), latest_weekly_key: Issue.latest_weekly_key }
    end

    # 附录 B 的 404 页，带页脚：地址形状不对、月份或年份越界都落到这里，
    # 读者看到的是站内的一页，不是 public/404.html 那张没有报头页脚的静态页。
    # layout 显式指定的理由同 render_forbidden：Admin::BaseController 把 RecordNotFound 也接到这里，
    # 而 mission_control-jobs 的控制器继承它、又把 layout 定死成自己那张（依赖它自己的 before_action 设 @application）
    def render_not_found
      render inertia: "Errors/NotFound", props: footer_props, status: :not_found, layout: "application"
    end

    # 附录 B 的 403 页（AC-3.5）：登录了但不是 admin，不跳登录页。显式指定 layout：
    # mission_control-jobs 的控制器把 layout 定死成它自己那张（期待 @application 已经由它自己的
    # before_action 设好），而 require_admin 先于那些 before_action 拦下请求，不指定就会渲染那张
    # 布局并因为 @application 是 nil 而炸掉
    def render_forbidden
      render inertia: "Errors/Forbidden", props: footer_props, status: :forbidden, layout: "application"
    end
end
