class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private
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
