# 搜索页（PRD 5.4、设计第 6 节）：参数解析、执行、日志都在模型里，这里只把结果摆成 props。
# 限流按用户每分钟 60 次（R-4.10），超限渲染同一页的 limited 态并回 429，不写日志。
class SearchesController < ApplicationController
  rate_limit to: 60, within: 1.minute, by: -> { Current.user.id }, with: :render_limited

  def show
    query = Search::Query.parse(params)
    if query.blank?
      render_search(query, state: query.q.empty? ? "initial" : "unsupported")
    else
      result = Search::Runner.call(query)
      Search::Log.record(query, result)
      if beyond_last_page?(query, result)
        redirect_to last_page_path(query, result.pages)
      else
        render_search(query, state: state_for(result), result: result)
      end
    end
  end

  private
    # R-4.7：页码合法但超过总页数（分享的地址、结果后来变少）时不渲染一页空结果，跳到最后一页；其余参数原样带上
    def beyond_last_page?(query, result)
      result.ok? && result.total.positive? && query.page > result.pages
    end

    # 只用解析过的字段重建地址，不把 request.query_parameters 整个交给路由助手：
    # 那里面读者能塞 script_name 之类的保留键，拼出协议相对地址就是开放跳转
    def last_page_path(query, pages)
      search_path({ q: query.q, type: query.type, source: query.sources.presence&.join(","), from: query.from&.iso8601,
                    to: query.to&.iso8601, range: query.range, sort: query.sort, page: pages }.compact)
    end

    def render_limited
      render_search(Search::Query.parse(params), state: "limited", status: :too_many_requests)
    end

    def state_for(result)
      if !result.ok?
        "unavailable"
      elsif result.total.zero?
        "empty"
      else
        "results"
      end
    end

    def render_search(query, state:, result: nil, status: :ok)
      latest_daily_key = Issue.latest_daily_key

      render inertia: "Search/Show", props: {
        q: query.q,
        truncated: query.truncated?,
        filters: query.filters,
        source_options: source_options,
        date_presets: date_presets,
        state: state,
        results: results_props(query, result),
        total: result&.total || 0,
        page: query.page,
        pages: result&.pages || 0,
        latest_daily_key: latest_daily_key,
        latest_daily_label: latest_daily_key && PeriodKey.date_label(PeriodKey.date_of(latest_daily_key), year: true)
      }.merge(footer_props), status: status
    end

    # 来源小签列出所有源，含停用的（PRD 5.4「筛选的来源已停用：仍可选，仍可命中历史条目」）；日刊源在前
    def source_options
      Source.order(:publication, :sort_order, :name).map { |source| { id: source.id, name: source.name, enabled: source.enabled } }
    end

    # 日期预设（R-4.4）：近 7 天、近 30 天，按上海时区的今天算，含首尾。页面只拿它拼链接，服务端只认 from / to
    def date_presets
      today = PeriodKey.date_of(PeriodKey.today)
      { "7d" => { from: (today - 6).iso8601, to: today.iso8601 }, "30d" => { from: (today - 29).iso8601, to: today.iso8601 } }
    end

    def results_props(query, result)
      if result
        highlighter = Search::Highlighter.new(query.terms)
        result.entries.map { |entry| entry_props(entry, highlighter) }
      else
        []
      end
    end

    # 高亮与片段在 items 原文上做；索引里的 NFKC 副本只用来匹配
    def entry_props(entry, highlighter)
      record = entry.record
      item = record.item
      {
        item_id: item.id,
        rank: entry.rank,
        publication: record.publication,
        source_name: item.source.name,
        where: { label: record.where_label, href: where_href(record) },
        published_label: record.published_label,
        url: item.url,
        title_runs: highlighter.runs(item.title),
        snippet_runs: item.summary.presence && highlighter.snippet(item.summary)
      }
    end

    # 所在期（设计 6.3）：日刊带 ?source= 切到那一栏并落到条目锚点；周刊落到板块的稳定锚点（Item#anchor）
    def where_href(record)
      if record.daily?
        daily_issue_path(record.period_key, source: record.source_id, anchor: "item-#{record.item_id}")
      else
        weekly_issue_path(record.period_key, anchor: record.anchor)
      end
    end
end
