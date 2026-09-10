module Issue::Weekly
  extend ActiveSupport::Concern

  class_methods do
    # R-2.1 每天检查一次每个启用的周刊源：阮一峰按期号认新内容，其余源按本周的 ISO 周键
    def check_weekly_sources!
      Source.enabled.weekly.ordered.find_each do |source|
        run = source.fetch_runs.create!(trigger: "scheduled", attempt: 1, status: "running", started_at: Time.current)
        ingest(source, run)
      end
    end

    # R-2.2 内容归它自己那一周：本周才检测到的上周内容仍然写进上周的期
    def weekly_for!(period_key)
      weekly.create_with(state: "generating", generation_started_at: Time.current).find_or_create_by!(period_key: period_key)
    end

    private
      # 某个源出错只记账，不拖累别的源，也不阻塞已经装订好的节
      def ingest(source, run)
        case source.adapter
        when "ruanyf_weekly" then ingest_ruanyf(source, run)
        else ingest_rss_weekly(source, run)
        end
      rescue StandardError => e
        run.update!(status: "failed", error_summary: e.message.to_s.lines.first.to_s.strip[0, 200])
      end

      # 期号是阮一峰的新内容标识：已经入库的期号只记一次检查，不重抓也不改写它所在的期
      def ingest_ruanyf(source, run)
        adapter = source.adapter_class.new(source)
        number = adapter.latest_issue_number

        if stored?(source, number)
          run.update!(status: "succeeded", item_count: 0, dropped_count: 0)
        else
          entries = adapter.fetch_issue(number)
          bind!(source, run, PeriodKey.weekly(entries.first.published_at || Time.current), entries)
        end
      rescue Adapters::RuanyfWeekly::Degraded => e
        # R-2.3 原文结构变了：整期降级成一条指向原文的条目。P0 只记录，告警是 P2
        bind!(source, run, PeriodKey.this_week, [ degraded_entry(e) ], error_summary: "降级：#{e.message}"[0, 200])
      end

      # R-2.4 通用 RSS 周刊源：本周内每条 entry 就是一条条目
      def ingest_rss_weekly(source, run)
        key = PeriodKey.this_week
        bind!(source, run, key, source.adapter_class.new(source).fetch(period_key: key))
      end

      def stored?(source, number)
        Item.where(source: source).where("meta->>'issue_no' = ?", number.to_s).exists?
      end

      def degraded_entry(error)
        Adapters::Entry.new(title: "科技爱好者周刊（第 #{error.issue_no} 期）：#{error.issue_title}", url: error.url, rank: 1,
          meta: { issue_no: error.issue_no, issue_title: error.issue_title, degraded: true })
      end

      # R-2.7 一条都没有就不建这一周的期；建期与写节在同一个事务里，写砸了不留下没有条目的空期
      def bind!(source, run, period_key, entries, error_summary: nil)
        kept, dropped = entries.partition(&:valid?)
        issue = if kept.any?
          transaction { weekly_for!(period_key).tap { |target| target.write_section!(source, kept) } }
        end
        run.update!(issue: issue, status: "succeeded", item_count: kept.size, dropped_count: dropped.size, error_summary: error_summary)
      end
  end

  # 一节写完这一期就可见：同周其他源晚点到，各自替换自己那一节，不动别人的
  def write_section!(source, entries)
    transaction do
      replace_section!(source, entries.select(&:valid?))
      update!(state: "published", published_at: published_at || Time.current)
    end
  end

  # R-2.5 周刊页按源分节；R-2.6 源按排序值，板块与板块内条目按原文顺序（rank）
  def weekly_sections
    items.visible.ranked.includes(:source).group_by(&:source).sort_by { |source, _| [ source.sort_order, source.name ] }.map do |source, list|
      head = list.first
      { source: source, issue_no: head.meta["issue_no"], issue_title: head.meta["issue_title"],
        degraded: head.meta["degraded"] == true, sections: list.group_by(&:section).to_a }
    end
  end
end
