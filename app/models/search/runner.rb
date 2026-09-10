# 执行一次搜索（设计 5.2 到 5.4）：一条 SQL 在 search_records 上按词打分，数据库排序分页，另一条 COUNT。
# 拉丁词 2 到 4 字符走词首前缀（~*），5 字符起走 pg_trgm 的 word_similarity（5 到 8 字符阈值 0.55，
# 9 字符起 0.45），中文词（二元组）走 ILIKE 子串；四列权重 标题 4、板块 2、来源名 2、摘要 1（R-4.3）。
# 词值一律经 Arel 的 build_quoted 进 SQL，没有字符串拼接。超时与连接失败归「不可用」（R-4.10 的兜底），
# 其他异常照常抛出。
class Search::Runner
  PER_PAGE = 20
  STATEMENT_TIMEOUT_MS = 500
  # <% 只认这个 GUC 阈值：取两档里低的那个让 GIN 索引先粗筛，精确阈值由 word_similarity() 复核
  SIMILARITY_FLOOR = 0.45
  WEIGHTS = { title: 4, section: 2, source_name: 2, summary: 1 }.freeze

  def self.call(query, timeout_ms: STATEMENT_TIMEOUT_MS) = new(query, timeout_ms).call

  def initialize(query, timeout_ms)
    @query = query
    @timeout_ms = Integer(timeout_ms)
    @records = Search::Record.arel_table
  end

  def call
    started = now_ms
    rows, total = Search::Record.transaction { run }
    Search::Result.new(entries: entries(rows), total: total, page: @query.page, latency_ms: now_ms - started, status: "ok")
  rescue ActiveRecord::QueryCanceled => e
    unavailable(e, "timeout", started)
  rescue ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad => e
    unavailable(e, "error", started)
  end

  private
    def run
      connection = Search::Record.connection
      connection.execute(Search::Record.sanitize_sql_array([ "SET LOCAL statement_timeout = ?", @timeout_ms ]))
      connection.execute(Search::Record.sanitize_sql_array([ "SET LOCAL pg_trgm.word_similarity_threshold = ?", SIMILARITY_FLOOR ]))
      scope = matching
      [ page_of(scope), scope.count ]
    end

    # 只搜已发布的期；筛选维度之间 AND，来源之间 OR，日期含首尾（R-4.4）
    def matching
      scope = Search::Record.published.where(any_hit)
      scope = scope.where(publication: @query.type) if @query.type
      scope = scope.where(source_id: @query.sources) if @query.sources.any?
      scope = scope.where(published_on: @query.from..) if @query.from
      scope = scope.where(published_on: ..@query.to) if @query.to
      scope
    end

    def page_of(scope)
      scope.select(@records[Arel.star], Arel::Nodes::As.new(score, Arel.sql("score")))
        .order(*ordering).limit(PER_PAGE).offset(offset)
        .preload(item: :source).to_a
    end

    # R-4.2 全部命中的排在部分命中之前，再按分数，同分按发布日期倒序（R-4.3），最后按 item_id 定序；
    # sort=date 时先看日期
    def ordering
      if @query.sort == "date"
        [ @records[:published_on].desc, Arel::Nodes::Descending.new(score), @records[:item_id].asc ]
      else
        [ Arel::Nodes::Descending.new(full_match), Arel::Nodes::Descending.new(score), @records[:published_on].desc, @records[:item_id].asc ]
      end
    end

    def offset = (@query.page - 1) * PER_PAGE

    def entries(rows)
      rows.each_with_index.map { |record, index| Search::Result::Entry.new(record: record, rank: offset + index + 1, score: record.score) }
    end

    def unavailable(error, status, started)
      Rails.error.report(error, handled: true, context: { search: @query.q })
      Search::Result.new(entries: [], total: 0, page: @query.page, latency_ms: now_ms - started, status: status)
    end

    def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

    # ── Arel 片段 ──

    def any_hit = @query.terms.map { |term| term_hit(term) }.reduce { |a, b| a.or(b) }

    def term_hit(term) = WEIGHTS.keys.map { |column| hit(term, column) }.reduce { |a, b| a.or(b) }

    # 一个词对一列的命中判定（设计 5.2）
    def hit(term, column)
      col = @records[column]
      if term.cjk?
        col.matches("%#{Search::Record.sanitize_sql_like(term.text)}%")                       # ILIKE
      elsif term.length <= 4
        col.matches_regexp("\\m#{Regexp.escape(term.text)}", false)                             # ~* 词首前缀；词只含字母数字，escape 只是保险
      else
        quoted = Arel::Nodes.build_quoted(term.text)
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new("<%", quoted, col)                                     # GIN 粗筛（阈值 SIMILARITY_FLOOR）
            .and(Arel::Nodes::NamedFunction.new("word_similarity", [ quoted, col ]).gteq(Arel::Nodes.build_quoted(similarity_threshold(term))))
        )
      end
    end

    def similarity_threshold(term) = term.length <= 8 ? 0.55 : 0.45

    # score = Σ_term Σ_column weight × hit
    def score
      Arel::Nodes::Grouping.new(sum(@query.terms.flat_map do |term|
        WEIGHTS.map { |column, weight| Arel::Nodes::Multiplication.new(case_hit(hit(term, column)), Arel::Nodes.build_quoted(weight)) }
      end))
    end

    # hits = 命中了任一列的词数；全命中 = hits 等于词数
    def hits = Arel::Nodes::Grouping.new(sum(@query.terms.map { |term| case_hit(term_hit(term)) }))

    def full_match = Arel::Nodes::Grouping.new(Arel::Nodes::Equality.new(hits, Arel::Nodes.build_quoted(@query.terms.size)))

    def case_hit(condition) = Arel::Nodes::Case.new.when(condition).then(1).else(0)

    def sum(nodes) = nodes.reduce { |a, b| Arel::Nodes::Addition.new(a, b) }
end
