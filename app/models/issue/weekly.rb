module Issue::Weekly
  extend ActiveSupport::Concern

  class_methods do
    # R-2.1 每天检查一次每个启用的周刊源：阮一峰按期号认新内容，其余源按本周的 ISO 周键
    def check_weekly_sources!
      # 周刊源列表很小：find_each 按主键分批、忽略 .ordered 的排序，这里改用 each 让 sort_order 真正生效
      Source.enabled.weekly.ordered.each do |source|
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

      # 期号是阮一峰的新内容标识：已经入库的期号只记一次检查，不重抓也不改写它所在的期；
      # 降级 stub 不算数（R42）：结构修好之后的检查照样重抓，把 stub 换成真内容
      def ingest_ruanyf(source, run)
        adapter = source.adapter_class.new(source)
        number = adapter.latest_issue_number
        item = stored_items(source, number).first

        if item
          run.update!(issue: item.issue, status: "succeeded", item_count: 0, dropped_count: 0)
        else
          entries = adapter.fetch_issue(number)
          bind!(source, run, PeriodKey.weekly(entries.first.published_at || Time.current), entries, issue_no: number)
        end
      rescue Adapters::RuanyfWeekly::Degraded => e
        # R-2.3 原文结构变了：整期降级成一条指向原文的条目。P0 只记录，告警是 P2
        bind!(source, run, PeriodKey.this_week, [ degraded_entry(e) ], issue_no: e.issue_no, error_summary: "降级：#{e.message}"[0, 200])
      end

      # R-2.4 通用 RSS 周刊源：本周内每条 entry 就是一条条目。这一节从周一起就在页面上了，
      # 每天的检查只补新地址（append），不整节重写：重写会把周初的条目挤出 count 封顶（R-2.8、R-1.4）
      def ingest_rss_weekly(source, run)
        key = PeriodKey.this_week
        bind!(source, run, key, source.adapter_class.new(source).fetch(period_key: key), append: true)
      end

      # 排除降级 stub：它站着这个期号的位置，但不是「已经入库的内容」
      def stored_items(source, number)
        Item.where(source: source)
          .where("meta->>'issue_no' = ?", number.to_s)
          .where("coalesce((meta->>'degraded')::boolean, false) = false")
      end

      def degraded_entry(error)
        Adapters::Entry.new(title: "科技爱好者周刊（第 #{error.issue_no} 期）：#{error.issue_title}", url: error.url, rank: 1,
          meta: { issue_no: error.issue_no, issue_title: error.issue_title, degraded: true })
      end

      # R-2.7 一条都没有就不建这一周的期；建期与写节在同一个事务里，写砸了不留下没有条目的空期
      def bind!(source, run, period_key, entries, issue_no: nil, append: false, error_summary: nil)
        kept, dropped = entries.partition(&:valid?)
        issue, deduped = if kept.any?
          transaction { weekly_for!(period_key).then { |target| [ target, target.write_section!(source, kept, issue_no: issue_no, append: append) ] } }
        else
          [ nil, 0 ]
        end

        # 跟日刊路径一样（Source::Fetching#fetch_now）：同源重复地址在写入时被去掉，也要计进
        # dropped_count，不然 item_count 报的是抓到几条，不是这一节真的写进去几条
        run.update!(issue: issue, status: "succeeded", item_count: kept.size - deduped, dropped_count: dropped.size + deduped, error_summary: error_summary)
      end
  end

  # 一节写完这一期就可见：同周其他源晚点到，各自写自己那一节，不动别人的；
  # 阮一峰传 issue_no，同一周两期各占一节，互不覆盖（PRD 异常与边界，R41）；
  # RSS 周刊源传 append，一周里每天补进来的 entry 接在这一节后面，不重写已发布的条目（R-2.8）。
  # 返回同源重复地址被去掉的条数（replace_section!/append_section! 的返回值），调用方
  # （class 方法 bind!）计进 FetchRun 的 dropped_count，跟日刊路径一致。
  def write_section!(source, entries, issue_no: nil, append: false)
    transaction do
      kept = entries.select(&:valid?)
      deduped = if append
        append_section!(source, kept)
      else
        replace_section!(source, kept, issue_no: issue_no)
      end

      # 周刊有节就有内容（R-2.7 一条都没有不建期），降级 stub 也算数：degraded 记在条目的 meta 里。
      # 不同源各自的 write_section! 可能前后脚落地：merge 前 with_lock 一下，读到的才是
      # 别的源刚提交的最新 source_states，不然后写的会拿着自己读进来的旧值把它覆盖掉
      # （跟 Issue::Finalization#finalize! 的 with_lock 是同一个道理）。
      with_lock do
        update!(state: "published", published_at: published_at || Time.current,
          source_states: source_states.merge(source.id => "ok"))
      end

      deduped
    end
  end

  # R-2.5 周刊页按源分节，阮一峰同一周的多期各自成节；R-2.6 源按排序值，同源内按期号顺序，板块与板块内条目按原文顺序（rank）
  def weekly_sections
    items.visible.ranked.includes(:source)
      .group_by { |item| [ item.source, item.meta["issue_no"] ] }
      .sort_by { |(source, issue_no), _| [ source.sort_order, source.name, issue_no.to_i ] }
      .map do |(source, issue_no), list|
        head = list.first
        { source: source, issue_no: issue_no, issue_title: head.meta["issue_title"],
          degraded: head.meta["degraded"] == true, sections: list.group_by(&:section).to_a }
      end
  end
end
