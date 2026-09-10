class DailyIssuesController < ApplicationController
  # D20：首页就是最新一期，没有单独的首页；一期都还没有时落到今天（页面会说「本期未生成」）
  def latest
    redirect_to daily_issue_path(Issue.daily.maximum(:period_key) || PeriodKey.today)
  end

  # PRD 6.2 日刊归档：一页一个月，默认当月；上线前的日期不列
  def index
    if month = requested_month
      render inertia: "Daily/Index", props: Issue.daily_archive_props(month: month).merge(footer_props)
    else
      head :not_found
    end
  end

  # R-1.6 某日没有期记录不是 404，页面照常显示日期与「本期未生成」
  def show
    if period_key = valid_period_key
      issue = Issue.daily.find_by(period_key: period_key)
      sources = Issue.daily_source_summaries(issue)

      render inertia: "Daily/Show", props: {
        issue: Issue.daily_props_for(period_key, issue: issue),
        missing: issue.nil?,
        sources: sources,
        items_by_source: issue&.items_by_source || {},
        active_source_id: params[:source].presence_in(sources.pluck(:id)) || sources.dig(0, :id),
        latest_weekly_key: Issue.latest_weekly_key
      }
    else
      head :not_found
    end
  end

  private
    MONTH = /\A\d{4}-\d{2}\z/

    # 周期键要形状对得上，也要真的是一天：2026-13-45 过得了正则，过不了 Date.iso8601。
    # Date::Error 是 ArgumentError 的子类，写一个就够，写两个会被 Lint/ShadowedException 拦下。
    def valid_period_key
      key = params[:period_key]
      PeriodKey.date_of(key) && key
    rescue ArgumentError
      nil
    end

    # ?month=YYYY-MM；不带参数就是上海时区的当月。2026-13 同样过得了正则、过不了 Date.strptime
    def requested_month
      key = params[:month].presence or return PeriodKey.date_of(PeriodKey.today)
      Date.strptime(key, "%Y-%m") if key.match?(MONTH)
    rescue ArgumentError
      nil
    end
end
