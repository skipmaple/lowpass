# R-1.1 调度是每分钟一次的 tick，读数据库里的生成时间；错过的（服务停过、机器睡过）由同一次 tick 补跑
class Scheduler
  LATE_AFTER = 1.minute
  CLEANUP_TIME = "04:00".freeze

  def self.tick(now: Time.current)
    new(now).tick
  end

  def initialize(now)
    @now = now.in_time_zone(PeriodKey::ZONE)
  end

  def tick
    step(:generate_daily_if_due)
    step(:finalize_stale_issues)
    step(:check_weekly_if_due)
    step(:cleanup_if_due)
  end

  private
    # R-1.6 每个自然日最多一期；R-1.7 当日内补跑的期标注延迟生成
    def generate_daily_if_due
      due_at = today_at(Setting.get("daily_time"))
      return if @now < due_at

      key = PeriodKey.daily(@now)
      return if Issue.daily.exists?(period_key: key)

      late_by = @now - due_at
      issue = Issue.generate_daily!(key, late: late_by > LATE_AFTER)
      # 5.7「日刊未生成」：06:00 的期到 06:30 还没有才算事故（设计 B4）；一两分钟的重启只标延迟
      Alerts.issue_late!(issue, (late_by / 60).floor) if late_by > Alerts::LATE_ALERT_AFTER
    end

    # R-1.2 期级总超时 20 分钟：没有源再回来的话，由 tick 替这一期收尾
    def finalize_stale_issues
      Issue.daily.where(state: "generating").where(generation_started_at: ...(@now - Issue::Daily::ISSUE_TIMEOUT)).find_each do |issue|
        issue.finalize!(reason: "timeout")
      end
    end

    # R-2.1 每天检查一次上游周刊：先入队再记账，重复一次幂等的检查好过漏掉一次
    def check_weekly_if_due
      today = PeriodKey.daily(@now)
      return if @now < today_at(Setting.get("weekly_time")) || Setting.get("weekly_checked_on") == today

      WeeklyCheckJob.perform_later
      Setting.set("weekly_checked_on", today)
    end

    # F-26 抓取记录保留 30 天，搜索日志 30 天（D12）、结果点击 90 天（9.1）；会话过期即删（附录 A）；
    # 审计日志 90 天（7.8）；告警事件 90 天；模型调用账本 90 天（R-9.8）。跟周刊检查一样按上海时区的自然日记账：
    # 只认「今天清过没有」，不认「现在是不是 04:02」——那一分钟的 tick 错过了（服务停过、机器睡过）就整天不清了
    def cleanup_if_due
      today = PeriodKey.daily(@now)
      return if @now < today_at(CLEANUP_TIME) || Setting.get("cleaned_on") == today

      FetchRun.cleanup
      Search::Log.cleanup
      Search::Click.cleanup
      Session.cleanup
      AuditLog.cleanup
      AlertEvent.cleanup
      ModelCall.cleanup
      Setting.set("cleaned_on", today)
    end

    def today_at(hhmm)
      hour, min = hhmm.split(":").map(&:to_i)
      @now.change(hour: hour, min: min, sec: 0)
    end

    # 一步出错不拖累其他步：记到错误报告里，下一分钟的 tick 会再来
    def step(name)
      send(name)
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { step: name })
    end
end
