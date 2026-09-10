class WeeklyIssuesController < ApplicationController
  YEAR = /\A\d{4}\z/

  # PRD 6.2 周刊归档：一页一年。最早一期之前与本年之后没有这一页（props 为 nil）
  def index
    if props = requested_archive
      render inertia: "Weekly/Index", props: props.merge(footer_props)
    else
      head :not_found
    end
  end

  # R-2.7 那一周没有期不是 404：期头照常显示周次与日期范围，正文只有「本周无内容」
  def show
    if period_key = valid_period_key
      render inertia: "Weekly/Show", props: Issue.weekly_props_for(period_key).merge(footer_props)
    else
      head :not_found
    end
  end

  private
    # ?year[]=… 让 params[:year] 变成 Array/Hash，presence 后 match? 没这个方法：先挡在这里，
    # 不是 String 就当非法值处理（跟 daily_issues_controller#requested_month 同一个道理）。
    def requested_archive
      raw = params[:year]
      return nil unless raw.nil? || raw.is_a?(String)

      year = raw.presence
      Issue.weekly_archive_props(year: year) if year.nil? || year.match?(YEAR)
    end

    # 周期键要形状对得上，也要真的是一周：2026-W99 过得了正则，过不了 Date.commercial。
    # Date::Error 是 ArgumentError 的子类，写一个就够（Lint/ShadowedException）。
    def valid_period_key
      key = params[:period_key]
      PeriodKey.week_range(key) && key
    rescue ArgumentError
      nil
    end
end
