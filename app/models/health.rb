# 健康检查（N-5，设计 docs/superpowers/specs/2026-09-28-p3-backup-health-design.md §3）：给外部拨测看的五项。
# 任一项 fail，整体就是 fail（控制器回 503）。每一项自己兜住异常记成 fail 并报告，返回里不带异常信息（可能有内部主机名）
class Health
  CHECKS = %i[ database search scheduler daily_issue backup ].freeze
  TICK_STALE_AFTER = 5.minutes
  BACKUP_STALE_AFTER = 50.hours
  SEARCH_TIMEOUT_MS = 1000

  Report = Data.define(:checked_at, :checks, :details) do
    def ok? = checks.values.none?("fail")

    def as_json(*)
      { status: ok? ? "ok" : "fail", checked_at: checked_at.iso8601, checks: checks }.merge(details).as_json
    end
  end

  def self.check(now: Time.current) = new(now).check

  def initialize(now)
    @now = now.in_time_zone(PeriodKey::ZONE)
  end

  def check
    results = CHECKS.index_with { |name| run(name) }
    Report.new(checked_at: @now, checks: results.transform_values(&:first), details: results.transform_values(&:last).compact_blank)
  end

  private
    def run(name)
      send(name)
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { health: name })
      [ "fail", {} ]
    end

    def database
      ActiveRecord::Base.connection.select_value("SELECT 1")
      [ "ok", {} ]
    end

    def search
      result = Search::Runner.probe(timeout_ms: SEARCH_TIMEOUT_MS)
      [ result.ok? ? "ok" : "fail", { latency_ms: result.latency_ms } ]
    end

    # tick 每分钟一次，每次先写心跳（Scheduler#heartbeat）：5 分钟没动静就是调度停了，这能跨过一次部署重启（设计 E12）。
    # Solid Queue 自己的进程心跳只做诊断：tick 停了而它还在跳，是 tick 本身出错；两个都停，是 Solid Queue 停了
    def scheduler
      ticked_at = time_from(Setting.get("ticked_at"))
      [ ticked_at && ticked_at >= @now - TICK_STALE_AFTER ? "ok" : "fail",
        { ticked_at: ticked_at&.iso8601, queue_heartbeat_at: queue_heartbeat&.in_time_zone(PeriodKey::ZONE)&.iso8601 } ]
    end

    # 生成时间过后 30 分钟起当日期必须在（与「日刊未生成」告警同一条线，设计 B4），此前看昨日期；顺带给出 N-5 的「最近一期距今」
    def daily_issue
      due = today_at(Setting.get("daily_time")) + Alerts::LATE_ALERT_AFTER
      expected = PeriodKey.daily(@now >= due ? @now : @now - 1.day)
      latest = Issue.daily.maximum(:period_key)
      published_at = Issue.daily.where(state: "published").order(period_key: :desc).pick(:published_at)
      [ latest && latest >= expected ? "ok" : "fail",
        { latest: latest, expected: expected, published_at: published_at&.in_time_zone(PeriodKey::ZONE)&.iso8601,
          age_minutes: published_at && ((@now - published_at) / 60).floor } ]
    end

    # 设计 E8、E12：应该有备份时，最近一次成功不超过 50 小时；一次都没成功过，从第一条记录起算；
    # 一条记录都没有不判（刚部署、还没到 03:00）
    def backup
      return [ "skipped", {} ] unless Backup.expected?

      succeeded_at = BackupRun.succeeded.maximum(:finished_at)
      since = succeeded_at || BackupRun.minimum(:created_at)
      [ since.nil? || since >= @now - BACKUP_STALE_AFTER ? "ok" : "fail",
        { last_succeeded_at: succeeded_at&.in_time_zone(PeriodKey::ZONE)&.iso8601 } ]
    end

    # 队列表在 production 是另一个库（config.solid_queue.connects_to）；test 里没有这张表，也不该因此判失败
    def queue_heartbeat
      SolidQueue::Process.maximum(:last_heartbeat_at) if SolidQueue::Process.table_exists?
    rescue StandardError
      nil
    end

    def time_from(value)
      Time.iso8601(value).in_time_zone(PeriodKey::ZONE) if value.present?
    rescue ArgumentError
      nil
    end

    def today_at(hhmm)
      hour, min = hhmm.split(":").map(&:to_i)
      @now.change(hour: hour, min: min, sec: 0)
    end
end
