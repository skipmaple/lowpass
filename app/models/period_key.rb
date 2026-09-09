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

    private
      def local(time)
        time.in_time_zone(ZONE)
      end
  end
end
