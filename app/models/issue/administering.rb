# 后台期列表（5.6）：一页一个月，日刊逐天列（缺期也占一行，好给「补生成」按钮），周刊列与该月有重叠的周；
# 各源结果与状态词沿用归档页的推导（Issue::Presenting）
module Issue::Administering
  extend ActiveSupport::Concern

  class_methods do
    def admin_rows(kind:, month:, now: Time.current)
      today = PeriodKey.date_of(PeriodKey.daily(now))
      month = (month ? Date.strptime(month, "%Y-%m") : today).beginning_of_month
      earliest = daily.minimum(:period_key)&.then { |key| PeriodKey.date_of(key) } || today
      return if month > today.beginning_of_month || month < earliest.beginning_of_month

      rows = []
      rows.concat(admin_daily_rows([ month, earliest ].max, [ month.end_of_month, today ].min)) unless kind == "weekly"
      rows.concat(admin_weekly_rows(month)) unless kind == "daily"
      {
        month_label: "#{month.year} 年 #{month.month} 月",
        prev_month: month_nav(month.prev_month, month, earliest, today),
        next_month: month_nav(month.next_month, month, earliest, today),
        summary: admin_summary(month, rows),
        rows: rows
      }
    rescue Date::Error
      nil
    end

    private
      def admin_daily_rows(first, last)
        return [] if first > last

        issues = daily.where(period_key: first.iso8601..last.iso8601).includes(:fetch_runs).index_by(&:period_key)
        sources = Source.ordered.to_a
        counts = Item.visible.where(issue_id: issues.values.map(&:id)).group(:issue_id, :source_id).count
        missing_counts = Item.visible.where(issue_id: issues.values.map(&:id), reason: nil).group(:issue_id).count
        (first..last).to_a.reverse.map { |date| admin_daily_row(date.iso8601, issues[date.iso8601], sources, counts, missing_counts) }
      end

      def admin_daily_row(key, issue, sources, counts, missing_counts)
        columns = issue ? daily_columns(issue, sources) : []
        {
          kind: "daily", period_key: key, state: issue&.state || "missing", state_label: admin_state_label(issue),
          time_label: admin_time_label(issue), source_marks: issue && columns.map { |source| "#{abbr(source)} #{mark(issue, source, counts)}" }.join(" · "),
          refetchable_sources: (issue&.generating? ? [] : columns.map { |source| { id: source.id, name: source.name } }),
          reasons: admin_reasons(issue, missing_counts)
        }
      end

      # 期页「理由」格（设计 §6.2）：未配置 / 缺 N 条 / 已生成；生成中或缺期是 nil
      def admin_reasons(issue, missing_counts)
        return nil unless issue&.state == "published"
        missing = missing_counts.fetch(issue.id, 0)
        label = if !Reasons::Provider.configured? then "未配置模型供应商"
        elsif missing.positive? then "缺 #{missing} 条"
        else "已生成"
        end
        { label: label, missing: missing }
      end

      # 一个 ISO 周可能横跨两个月（周一在上个月），周一是否落在这个月不能决定这周算哪个月：
      # 按这个月每一天各自所在的周去重，横跨月份边界的那一周会在两个月的页上都出现一次
      def admin_weekly_rows(month)
        keys = (month..month.end_of_month).map { |date| PeriodKey.weekly(date.in_time_zone(PeriodKey::ZONE)) }.uniq
        weekly.where(period_key: keys).order(period_key: :desc).includes(items: :source).map do |issue|
          sources = issue.items.map(&:source).uniq.sort_by(&:sort_order)
          counts = issue.items.group_by(&:source_id).transform_values(&:size)
          {
            kind: "weekly", period_key: issue.period_key, state: issue.state, state_label: admin_state_label(issue),
            time_label: issue.published_at && day_stamp(issue.published_at),
            source_marks: sources.map { |source| "#{abbr(source)} #{counts[source.id]}" }.join(" · "),
            refetchable_sources: sources.map { |source| { id: source.id, name: source.name } }
          }
        end
      end

      def admin_state_label(issue)
        case issue&.state
        when nil then "缺期"
        when "generating" then "生成中"
        when "empty" then "空刊"
        else [ "已发布", ("延迟" if issue.generated_late), ("已修订" if issue.revised_at) ].compact.join(" · ")
        end
      end

      def admin_time_label(issue)
        return unless issue

        stamp = issue.published_at ? hhmm(issue.published_at) : hhmm(issue.generation_started_at)
        issue.revised_at ? "#{stamp} / #{hhmm(issue.revised_at)}" : stamp
      end

      def admin_summary(month, rows)
        present = rows.count { |row| row[:state] != "missing" }
        "#{month.month} 月 · #{present} 期 · #{rows.count { |row| row[:state] == "empty" }} 空刊 · #{rows.count { |row| row[:state] == "missing" }} 缺期"
      end
  end
end
