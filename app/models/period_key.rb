class PeriodKey
  ZONE = "Asia/Shanghai"
  DAILY = /\A\d{4}-\d{2}-\d{2}\z/
  WEEKLY = /\A\d{4}-W\d{2}\z/

  class << self
    def daily(time = Time.current)
      local(time).strftime("%Y-%m-%d")
    end

    def weekly(time = Time.current)
      local(time).strftime("%G-W%V")
    end

    def today = daily
    def this_week = weekly

    def date_of(daily_key)
      raise ArgumentError, daily_key unless daily_key.match?(DAILY)
      Date.iso8601(daily_key)
    end

    def week_range(weekly_key)
      raise ArgumentError, weekly_key unless weekly_key.match?(WEEKLY)
      year, week = weekly_key.split("-W").map(&:to_i)
      monday = Date.commercial(year, week, 1)
      monday..(monday + 6)
    end

    def week_number(weekly_key)
      raise ArgumentError, weekly_key unless weekly_key.match?(WEEKLY)
      weekly_key[-2, 2].to_i
    end

    # 归档一页一年（PRD 6.2）：这一年全部的 ISO 周键。12月28日 总落在这一年的最后一个 ISO 周里，
    # 所以 2026 有 53 周而 2025 只有 52 周——2025-W53 不存在，week_range 会抛错，控制器据此 404。
    def weeks_in(year)
      (1..Date.new(year, 12, 28).cweek).map { |week| format("%d-W%02d", year, week) }
    end

    private
      def local(time)
        time.in_time_zone(ZONE)
      end
  end
end
