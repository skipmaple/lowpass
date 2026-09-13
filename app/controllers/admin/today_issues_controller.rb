# R-3.11 立即生成今日日刊：当日无期则立即生成；已有期则（页面二次确认后）对所有启用源逐一重抓
class Admin::TodayIssuesController < Admin::BaseController
  def create
    key = PeriodKey.today
    if issue = Issue.daily.find_by(period_key: key)
      if params[:confirm] == "1"
        count = refetch_all(issue)
        Audit.record("issue.generate_today", "Issue##{key}", { refetched: count })
        redirect_to admin_issues_path, notice: "正在重抓 #{count} 个来源…"
      else
        redirect_to admin_issues_path, alert: "今日日刊已存在"
      end
    else
      Issue.generate_daily!(key, late: late_now?, trigger: "manual")
      Audit.record("issue.generate_today", "Issue##{key}")
      redirect_to admin_issues_path, notice: "已开始生成今日日刊"
    end
  end

  private
    def refetch_all(issue)
      sources = issue.generating? ? Source.enabled.daily : Source.where(id: issue.source_states.keys)
      sources.reject { |source| source.fetch_runs.active.exists?(issue: issue) }.each { |source| source.fetch_later(issue, trigger: "manual") }.size
    end

    def late_now?
      Time.current.in_time_zone(PeriodKey::ZONE).strftime("%H:%M") > Setting.get("daily_time")
    end
end
