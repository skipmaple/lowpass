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
    # 读者看到的是站内的一页，不是 public/404.html 那张没有报头页脚的静态页
    def render_not_found
      render inertia: "Errors/NotFound", props: footer_props, status: :not_found
    end
end
