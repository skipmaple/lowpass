# 告警门面（设计 §5）：触发点只说「发生了什么」，去重、建记录、入队投递都在这里。
# 告警是记账：永远不让抓取、定稿、搜索跟着失败（B10）——每个入口都 rescue 并 Rails.error.report
module Alerts
  LATE_ALERT_AFTER = 30.minutes
  SEARCH_FAILURES_KEY = "alerts:search_failures".freeze
  SEARCH_FAILURES_LIMIT = 3

  class << self
    def source_failed!(source, issue, summary) = raise!("source_failed", "warning", source: source, issue: issue, summary: summary, url_path: runs_path(source))
    def parse_degraded!(source, issue, summary) = raise!("parse_degraded", "warning", source: source, issue: issue, summary: summary, url_path: runs_path(source))
    def issue_empty!(issue) = raise!("issue_empty", "critical", issue: issue, summary: "所有来源都失败", url_path: issues_path(issue))
    def issue_late!(issue, minutes) = raise!("issue_late", "critical", issue: issue, summary: "晚于生成时间 #{minutes} 分钟", url_path: issues_path(issue))
    def search_unavailable!(summary) = raise!("search_unavailable", "critical", summary: summary, url_path: "/search")
    def backup_failed!(summary) = raise!("backup_failed", "critical", summary: summary, url_path: "/admin/settings")
    def reasons_missing!(issue, count, summary: nil) = raise!("reasons_missing", "warning", issue: issue, summary: summary || "理由缺失 #{count} 条", url_path: issues_path(issue))

    # 后台「发送测试告警」（R-7.4）：不去重；限流在控制器（B12）
    def test!(user)
      raise!("test", "info", summary: "由 #{user.display_name.presence || user.email} 触发", url_path: "/admin/settings", dedup: false)
    end

    # 条件消失：关掉未恢复的事件并各发一条「已恢复」（渠道都没配就只记账）
    def recover!(kind:, source: nil)
      AlertEvent.open_for(kind, source).find_each do |event|
        event.update!(recovered_at: Time.current)
        DeliverAlertJob.perform_later(event, "recovery") if configured?
      end
      nil
    rescue StandardError => e
      report(e)
      nil
    end

    # 搜索连续失败的计数（B5）：到 3 次告警一次，成功即清零并恢复。成功路径只读一次缓存，不下库
    def search_status(status)
      if status == "ok"
        return unless Rails.cache.read(SEARCH_FAILURES_KEY)
        Rails.cache.delete(SEARCH_FAILURES_KEY)
        recover!(kind: "search_unavailable")
      else
        failures = Rails.cache.increment(SEARCH_FAILURES_KEY, 1, expires_in: 1.hour).to_i
        search_unavailable!("搜索#{status == "timeout" ? "超时" : "出错"}，连续 #{failures} 次") if failures >= SEARCH_FAILURES_LIMIT
      end
      nil
    rescue StandardError => e
      report(e)
      nil
    end

    def configured? = Config.configured?

    private
      def raise!(kind, level, summary:, url_path:, source: nil, issue: nil, dedup: true)
        event = AlertEvent.new(kind: kind, level: level, source: source, issue: issue, summary: truncate(summary), url_path: url_path,
                               dedup_key: dedup ? dedup_key(kind, source, issue) : "test:#{Lowpass::Uuid.generate}")
        event.delivery_error = "未配置渠道" unless configured?
        # 自己一层 savepoint：撞唯一索引是常态（当天已发过），咽掉之后调用方手里的外层事务还得能用（B10）
        AlertEvent.transaction(requires_new: true) { event.save! }
        DeliverAlertJob.perform_later(event, "alert") if configured?
        event
      rescue ActiveRecord::RecordNotUnique
        nil   # R-7.1 当天已发过同一条
      rescue StandardError => e
        report(e)
        nil
      end

      # R-7.1「同一源同一天同类只发一次」：范围是源、期（按周期键）或全局；「天」按上海时区
      def dedup_key(kind, source, issue)
        scope = source&.id || issue&.period_key || "-"
        "#{kind}:#{scope}:#{PeriodKey.daily(Time.current)}"
      end

      def runs_path(source) = "/admin/sources/#{source.id}/runs"
      def issues_path(issue) = issue.kind == "weekly" ? "/admin/issues?kind=weekly" : "/admin/issues?month=#{issue.period_key[0, 7]}"
      def truncate(text) = text.to_s.lines.first.to_s.strip[0, 200]
      def report(error) = Rails.error.report(error, handled: true, context: { alerts: true })
  end
end
