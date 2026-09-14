# R-3.11 立即生成今日日刊：当日无期则立即生成；已有期则（页面二次确认后）对所有启用源逐一重抓
class Admin::TodayIssuesController < Admin::BaseController
  def create
    key = PeriodKey.today
    if issue = Issue.daily.find_by(period_key: key)
      refetch(issue)
    else
      generate(key)
    end
  end

  private
    # 二次确认在页面上；全部来源都还在跑时一条也入不了队，说清楚而不是报「正在重抓 0 个来源」
    def refetch(issue)
      if params[:confirm] != "1"
        redirect_back_or_to admin_issues_path, alert: "今日日刊已存在"
      elsif (count = refetch_all(issue)).zero?
        redirect_back_or_to admin_issues_path, alert: "没有可重抓的来源"
      else
        Audit.record("issue.generate_today", "Issue##{issue.period_key}", { refetched: count })
        redirect_back_or_to admin_issues_path, notice: "正在重抓 #{count} 个来源…"
      end
    end

    def refetch_all(issue)
      sources = issue.generating? ? Source.enabled.daily : Source.where(id: issue.source_states.keys)
      sources.reject { |source| source.fetch_runs.active.exists?(issue: issue) }.each { |source| source.refetch_later(issue) }.size
    end

    def generate(key)
      Issue.generate_daily!(key, late: late_now?, trigger: "manual")
      Audit.record("issue.generate_today", "Issue##{key}")
      redirect_back_or_to admin_issues_path, notice: "已开始生成今日日刊"
    end

    def late_now?
      Time.current.in_time_zone(PeriodKey::ZONE).strftime("%H:%M") > Setting.get("daily_time")
    end
end
