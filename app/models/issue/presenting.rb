module Issue::Presenting
  extend ActiveSupport::Concern

  WEEKDAYS = %w[ 星期日 星期一 星期二 星期三 星期四 星期五 星期六 ].freeze

  class_methods do
    # 期头要的一切。缺期时 issue 是 nil，日期、星期与前后期仍然从周期键与库里算得出来。
    # 状态文案在这里定稿而不是留给前端：没有开 SSR，页面上读得到的每个字符串都得先进 props。
    def daily_props_for(period_key, now: Time.current)
      issue = daily.find_by(period_key: period_key)
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

    # R-1.8 栏目顺序由源的排序值决定，期生成器与页面都不认识具体的源
    def daily_source_summaries(issue)
      Source.enabled.daily.ordered.map do |source|
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

    private
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

  private
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
