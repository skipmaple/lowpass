class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private
    # 页脚每页都要的两样：下一期日刊几点出、最新一期周刊落在哪（R51）。
    # 日刊详情不用这个：它的 daily_time 已经在期头的 props 里（daily_props_for）。
    def footer_props
      { daily_time: Setting.get("daily_time"), latest_weekly_key: Issue.latest_weekly_key }
    end
end
