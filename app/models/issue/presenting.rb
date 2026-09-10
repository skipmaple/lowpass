module Issue::Presenting
  extend ActiveSupport::Concern

  WEEKDAYS = %w[ 星期日 星期一 星期二 星期三 星期四 星期五 星期六 ].freeze
  # 归档一行里放不下来源名：榜单类源与周刊源有通用缩写；个别源名字的前三个字符不达意
  # （Hackaday → HAC），按画布（docs/design/src/pages_site.py 的 DAYS）用名字表纠正成 HAD；
  # 其余源取名字前三个字符。
  SOURCE_ABBRS = { "hacker_news" => "HN", "github_trending" => "GH", "ruanyf_weekly" => "阮" }.freeze
  SOURCE_NAME_ABBRS = { "Hackaday" => "HAD" }.freeze

  class_methods do
    # 期头要的一切。缺期时 issue 是 nil，日期、星期与前后期仍然从周期键与库里算得出来。
    # 状态文案在这里定稿而不是留给前端：没有开 SSR，页面上读得到的每个字符串都得先进 props。
    # 调用方已经查过这一期就用 issue: 传进来（缺期传 nil），省掉一次查询；不传才自己查。
    def daily_props_for(period_key, issue: :lookup, now: Time.current)
      issue = daily.find_by(period_key: period_key) if issue == :lookup
      date = PeriodKey.date_of(period_key)
      daily_time = Setting.get("daily_time")
      is_yesterday = yesterdays_issue?(period_key, now, daily_time)

      {
        period_key: period_key,
        date_label: "#{date.month}月#{date.day}日",
        weekday: WEEKDAYS[date.wday],
        state: issue&.state,
        time_label: head_time_label(issue),
        status: head_status(issue, is_yesterday, daily_time),
        daily_time: daily_time,
        published_at: hhmm(issue&.published_at),
        revised_at: hhmm(issue&.revised_at),
        generated_late: issue&.generated_late || false,
        is_yesterday: is_yesterday,
        prev_key: daily.where("period_key < ?", period_key).maximum(:period_key),
        next_key: daily.where("period_key > ?", period_key).minimum(:period_key)
      }
    end

    # R-1.8 栏目顺序由源的排序值决定，期生成器与页面都不认识具体的源。
    # 列哪些栏由 daily_columns 按期决定（R58：定稿的期认它自己记下的源）。
    def daily_source_summaries(issue)
      daily_columns(issue, Source.ordered.to_a).map do |source|
        {
          id: source.id,
          name: source.name,
          adapter: source.adapter,
          state: issue ? issue.source_state(source) : "pending",
          home_url: source.home_url,
          last_ok_label: day_stamp(source.last_ok_at)
        }
      end
    end

    # R-2.5 周刊页：期头（第几周、年份、日期范围）加按源分节。那一周没有期也照常给期头，
    # 正文只有附录 B 的「本周无内容」（R-2.7）。周期键非法时 PeriodKey.week_range 抛错，控制器据此 404。
    def weekly_props_for(period_key, issue: :lookup)
      issue = weekly.find_by(period_key: period_key) if issue == :lookup
      range = PeriodKey.week_range(period_key)
      sections = issue&.weekly_section_props || []

      {
        issue: {
          period_key: period_key,
          year: period_key[0, 4].to_i,
          week_label: week_label(period_key),
          range_label: range_label(range),
          state: issue&.state,
          # 一节都没有就是没内容：期不存在是常态，期在库里但条目都被藏起来也算（页面按 sections 空不空决定）
          status: ("本周无内容" if sections.empty?),
          published_at: hhmm(issue&.published_at),
          prev_key: weekly.where("period_key < ?", period_key).maximum(:period_key),
          next_key: weekly.where("period_key > ?", period_key).minimum(:period_key)
        },
        sections: sections
      }
    end

    # 页脚的「最新周刊」在每个页面都指向最新一期；一期都没有时页面落到归档
    def latest_weekly_key = weekly.maximum(:period_key)

    # PRD 6.2 日刊归档：一页一个月，每天一行（含缺期）。上线前的日期不显示，所以行从最早一期那天起算，
    # 到今天为止；整段落在这两头之外的月份一行都没有，翻月的按钮也就到此为止。请求的月份晚于当月时
    # 没有这一页（跟 weekly_archive_props 的年份越界一致），返回 nil 让控制器 404。
    def daily_archive_props(month: nil, now: Time.current)
      today = PeriodKey.date_of(PeriodKey.daily(now))
      month = (month || today).beginning_of_month
      return if month > today.beginning_of_month

      earliest = daily.minimum(:period_key)&.then { |key| PeriodKey.date_of(key) } || today

      {
        month_label: "#{month.year} 年 #{month.month} 月",
        prev_month: month_nav(month.prev_month, month, earliest, today),
        next_month: month_nav(month.next_month, month, earliest, today),
        days: archive_days([ month, earliest ].max, [ month.end_of_month, today ].min)
      }
    end

    # PRD 6.2 周刊归档：一页一年，每周一行，没有期的周标「本周无内容」（R-2.7）。
    # 年份越出「最早一期所在年 到 本年」就没有这一页，返回 nil 让控制器 404。
    def weekly_archive_props(year: nil, now: Time.current)
      current = PeriodKey.weekly(now)
      earliest = weekly.minimum(:period_key) || current
      years = earliest[0, 4].to_i..current[0, 4].to_i
      year = (year.presence || years.last).to_i
      return unless years.cover?(year)

      keys = PeriodKey.weeks_in(year).select { |key| key.between?(earliest, current) }.reverse
      issues = weekly.where(period_key: keys).index_by(&:period_key)

      {
        year_label: "#{year} 年",
        prev_year: year_nav(year - 1, years),
        next_year: year_nav(year + 1, years),
        weeks: keys.map { |key| archive_week(key, issues[key]) }
      }
    end

    private
      def week_label(period_key) = "第 #{PeriodKey.week_number(period_key)} 周"

      def range_label(range)
        "#{range.first.month}月#{range.first.day}日 至 #{range.last.month}月#{range.last.day}日"
      end

      def archive_days(first, last)
        return [] if first > last

        issues = daily.where(period_key: first.iso8601..last.iso8601).includes(:fetch_runs).index_by(&:period_key)
        # 停用的源也要查出来：定稿的期记下的源可能后来被停用了，那几栏的内容还在库里
        sources = Source.ordered.to_a
        counts = Item.visible.where(issue_id: issues.values.map(&:id)).group(:issue_id, :source_id).count

        (first..last).to_a.reverse.map { |date| archive_day(date, issues[date.iso8601], sources, counts) }
      end

      def archive_day(date, issue, sources, counts)
        {
          period_key: date.iso8601,
          date_label: "#{date.month}月#{date.day}日",
          weekday: WEEKDAYS[date.wday],
          state: issue&.state || "missing",
          published_label: archive_label(issue),
          source_marks: issue && daily_columns(issue, sources).map { |source| "#{abbr(source)} #{mark(issue, source, counts)}" }.join(" · ")
        }
      end

      # 归档一行只放得下一句：空刊那句「今日为空刊，管理员已收到通知」太长，交给状态记号说
      def archive_label(issue)
        case issue&.state
        when nil then "缺期"
        when "generating" then "生成中，约 1 分钟后刷新"
        when "empty" then nil
        else
          stamp = issue.generated_late ? "延迟生成于 #{hhmm(issue.published_at)}" : "#{hhmm(issue.published_at)} 发布"
          issue.revised_at ? "#{stamp} · 已于 #{hhmm(issue.revised_at)} 修订" : stamp
        end
      end

      def abbr(source) = SOURCE_ABBRS[source.adapter] || SOURCE_NAME_ABBRS[source.name] || source.name[0, 3].upcase

      def mark(issue, source, counts)
        case issue.source_state(source)
        when "ok" then counts.fetch([ issue.id, source.id ], 0).to_s
        when "empty" then "0"
        when "pending" then "生成中"
        else "失败"
        end
      end

      def archive_week(key, issue)
        {
          period_key: key,
          week_label: week_label(key),
          range_label: range_label(PeriodKey.week_range(key)),
          # 周维度的「没有」只有一种文案与记号（本周无内容 · 描边方块）：不分「没有这一期」与
          # 「这一期是空刊」，缺期的叉留给日刊（archive_day）
          state: issue&.state || "empty"
        }.merge(issue&.weekly_archive_row || { summary: "本周无内容", count: nil })
      end

      def month_nav(target, month, earliest, today)
        return unless target.between?(earliest.beginning_of_month, today.beginning_of_month)

        label = target.year == month.year ? "#{target.month} 月" : "#{target.year} 年 #{target.month} 月"
        { key: target.strftime("%Y-%m"), label: label }
      end

      def year_nav(target, years)
        { key: target.to_s, label: "#{target} 年" } if years.cover?(target)
      end

      # 一个期头只挂一个标签：期级状态先于期的来历，来历里修订又先于延迟（附录 B 的六句）
      def head_status(issue, is_yesterday, daily_time)
        if issue.nil?
          "本期未生成"
        elsif issue.generating?
          "生成中，约 1 分钟后刷新"
        elsif issue.empty?
          "今日为空刊，管理员已收到通知"
        elsif is_yesterday
          "昨日日刊，今日将于 #{daily_time} 生成"
        elsif issue.revised_at
          "已于 #{hhmm(issue.revised_at)} 修订"
        elsif issue.generated_late
          "延迟生成于 #{hhmm(issue.published_at)}"
        end
      end

      # 期头右栏那行等宽时间：发布了写「hh:mm 发布」，空刊只写定稿时间，生成中写开始时间
      def head_time_label(issue)
        case issue&.state
        when "published"  then "#{hhmm(issue.published_at)} 发布"
        when "empty"      then hhmm(issue.published_at)
        when "generating" then hhmm(issue.generation_started_at)
        end
      end

      # 5.1 边界：生成时间之前访问，看到的是昨日那一期，期头要说清楚今天几点出
      def yesterdays_issue?(period_key, now, daily_time)
        period_key == PeriodKey.daily(now - 1.day) &&
          now.in_time_zone(PeriodKey::ZONE).strftime("%H:%M") < daily_time &&
          !daily.exists?(period_key: PeriodKey.daily(now))
      end

      def day_stamp(time)
        if time
          local = time.in_time_zone(PeriodKey::ZONE)
          "#{local.month}月#{local.day}日 #{local.strftime("%H:%M")}"
        end
      end

      def hhmm(time)
        time&.in_time_zone(PeriodKey::ZONE)&.strftime("%H:%M")
      end
  end

  # 全期条目一次性给前端：来源切换是本地状态，不再回服务端（R-1.9 栏内顺序就是 ranked）
  def items_by_source
    items.visible.ranked.group_by(&:source_id).transform_values { |list| list.map { |item| item_props(item) } }
  end

  # R-2.5 一节 = 一个源的一期：源、该源自己的期号与标题、原文链接、按板块分组的条目。
  # 板块锚点目录点的是 anchor，所以同一页里每个板块得有一个唯一的落点。
  # D19：周刊条目不生成推荐理由，条目字段与日刊同一套（reason 与 interest_tag 一直是空的）。
  def weekly_section_props
    anchor = 0

    weekly_sections.map do |section|
      source = section[:source]
      {
        source: { id: source.id, name: source.name, adapter: source.adapter, home_url: source.home_url },
        issue_no: section[:issue_no],
        issue_title: section[:issue_title],
        issue_label: section_issue_label(section),
        degraded: section[:degraded],
        original_url: section_original_url(section),
        groups: section[:sections].map do |(name, list)|
          anchor += 1
          { name: name, anchor: "#{source.id}-#{anchor}", items: list.map { |item| item_props(item) } }
        end
      }
    end
  end

  # 归档一行的后半截：各源的期号与主题压成一句，加上本周条目数
  def weekly_archive_row
    sections = weekly_sections

    {
      summary: sections.map { |section| [ section[:source].name, section_issue_label(section) ].compact.join(" ") }.join(" / "),
      count: sections.sum { |section| section[:sections].sum { |(_, list)| list.size } }
    }
  end

  private
    def section_issue_label(section)
      [ "第 #{section[:issue_no]} 期", section[:issue_title].presence ].compact.join(" · ") if section[:issue_no].present?
    end

    # 阮一峰的原文是该期的 Markdown；其余源回到源站（feed 地址不是 http 时没有落点，页面把链接整条收掉）
    def section_original_url(section)
      source = section[:source]
      if source.adapter == "ruanyf_weekly" && section[:issue_no].present?
        "#{Adapters::RuanyfWeekly::ORIGINAL}/issue-#{section[:issue_no]}.md"
      else
        source.home_url
      end
    end

    # R-1.10 列表显示摘要前 200 字；reason 与 interest_tag 在 P0 是空的，前端不渲染
    def item_props(item)
      {
        id: item.id,
        title: item.title,
        url: item.url,
        summary: item.summary && SummaryCleaner.preview(item.summary),
        section: item.section,
        author: item.author,
        published_at: item.published_at&.iso8601,
        rank: item.rank,
        meta: item.meta,
        reason: item.reason,
        interest_tag: item.interest_tag
      }
    end
end
