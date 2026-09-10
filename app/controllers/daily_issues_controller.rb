class DailyIssuesController < ApplicationController
  # D20：首页就是最新一期，没有单独的首页；一期都还没有时落到今天（页面会说「本期未生成」）
  def latest
    redirect_to daily_issue_path(Issue.daily.maximum(:period_key) || PeriodKey.today)
  end

  # PRD 6.2 日刊归档：一页一个月，默认当月；上线前的日期不列，未来的月份也没有这一页
  def index
    if props = requested_archive
      render inertia: "Daily/Index", props: props.merge(footer_props)
    else
      render_not_found
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
      render_not_found
    end
  end

  private
    MONTH = /\A\d{4}-\d{2}\z/

    # 月份形状对、也在范围内才查：daily_archive_props 对晚于当月的月份返回 nil（跟周刊归档的
    # 年份越界一致），让这里统一落到 404
    def requested_archive
      month = requested_month
      Issue.daily_archive_props(month: month) if month
    end

    # 周期键要形状对得上，也要真的是一天：2026-13-45 过得了正则，过不了 Date.iso8601。
    # Date::Error 是 ArgumentError 的子类，写一个就够，写两个会被 Lint/ShadowedException 拦下。
    def valid_period_key
      key = params[:period_key]
      PeriodKey.date_of(key) && key
    rescue ArgumentError
      nil
    end

    # ?month=YYYY-MM；不带参数就是上海时区的当月。2026-13 同样过得了正则、过不了 Date.strptime。
    # ?month[]=… 让 params[:month] 变成 Array/Hash，presence 后 match? 没这个方法：先挡在这里，
    # 不是 String 就当非法值处理（同一个 rescue 之前只护得住 ArgumentError）。
    def requested_month
      raw = params[:month]
      return nil unless raw.nil? || raw.is_a?(String)

      key = raw.presence or return PeriodKey.date_of(PeriodKey.today)
      Date.strptime(key, "%Y-%m") if key.match?(MONTH)
    rescue ArgumentError
      nil
    end
end
