# R-1.6 补生成缺期：今天等同立即生成；过去的日子走回填（7.7）；未来与已有期拒绝
class Admin::Issues::BackfillsController < Admin::BaseController
  def create
    key = params[:issue_period_key]
    raise ActiveRecord::RecordNotFound unless key.match?(PeriodKey::DAILY)

    today = PeriodKey.today
    if Issue.daily.exists?(period_key: key)
      redirect_to admin_issues_path, alert: "这一天已有期"
    elsif key > today
      redirect_to admin_issues_path, alert: "还没到这一天"
    elsif key == today
      Issue.generate_daily!(key, late: late_now?, trigger: "manual")
      Audit.record("issue.generate_today", "Issue##{key}")
      redirect_to admin_issues_path, notice: "已开始生成今日日刊"
    else
      Issue.backfill_daily!(key)
      Audit.record("issue.backfill", "Issue##{key}")
      redirect_to admin_issues_path, notice: "已补生成 #{key}，正在抓取"
    end
  end

  private
    def late_now?
      Time.current.in_time_zone(PeriodKey::ZONE).strftime("%H:%M") > Setting.get("daily_time")
    end
end
