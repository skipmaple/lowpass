# 地址参数 → 不可变的查询（设计 5.1）。q 保留读者的原文（去首尾空白、最长 100 字符）给页面回显，
# 拆词用的是 NFKC 归一化后的文本：全角字母数字标点转半角，标点与符号当空格，拉丁词小写，
# 中文串拆二元组（R-4.2「终端工具」与「终端 工具」等价）。筛选参数不合法就当没给，页面不报错。
class Search::Query
  MAX_LENGTH = 100
  MAX_TERMS = 8
  PAGES = 50
  MIN_LATIN = 2
  TYPES = %w[ daily weekly ].freeze
  SORTS = %w[ relevance date ].freeze
  RANGES = %w[ 7d 30d all custom ].freeze
  DATE = /\A\d{4}-\d{2}-\d{2}\z/
  # 中日韩：汉字、假名、谚文。其余脚本按「拉丁词」处理（连续的非空白非中日韩字符）
  CJK = /[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]/
  RUNS = /[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]+|[^\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\s]+/
  # 不是字母、数字、组合记号或空白的字符（标点、符号、控制字符）一律换成空格。
  # 剩下的词只含字母数字，拼进正则（Runner 的词首前缀）时没有元字符。
  NOISE = /[^\p{L}\p{N}\p{M}\s]/

  Term = Data.define(:text, :kind) do
    def cjk? = kind == :cjk
    def length = text.length
  end

  attr_reader :q, :terms, :type, :sources, :from, :to, :range, :page, :sort

  def self.parse(params) = new(params)

  def initialize(params)
    raw = str(params, :q).strip
    @truncated = raw.length > MAX_LENGTH
    @q = raw[0, MAX_LENGTH]
    @terms = tokenize(@q.unicode_normalize(:nfkc))
    @type = str(params, :type).presence_in(TYPES)
    @sources = existing_sources(str(params, :source))
    @from, @to = date_range(str(params, :from), str(params, :to))
    @range = str(params, :range).presence_in(RANGES) || (@from || @to ? "custom" : "all")
    @page = page_number(str(params, :page))
    @sort = str(params, :sort).presence_in(SORTS) || "relevance"
    freeze
  end

  def blank? = terms.empty?
  def truncated? = @truncated

  # 页面 props 的 filters（设计 6.2）
  def filters
    { type: type, sources: sources, from: from&.iso8601, to: to&.iso8601, range: range, sort: sort }
  end

  # search_logs.filters（设计 3.2）：range 只是页面便利，不记
  def log_filters
    { "type" => type, "source" => sources, "from" => from&.iso8601, "to" => to&.iso8601, "sort" => sort }
  end

  private
    # ?q[]=… 让值变成数组或哈希：不是字符串就当没给
    def str(params, key)
      value = params[key]
      value.is_a?(String) ? value : ""
    end

    def tokenize(text)
      text.gsub(NOISE, " ").split.flat_map { |piece| piece.scan(RUNS).flat_map { |run| run_terms(run) } }.uniq.first(MAX_TERMS)
    end

    # 中文串拆二元组（长度 1 的串本身即一个词）；拉丁词小写，不到 2 字符丢弃（R-4.1）
    def run_terms(run)
      if run.match?(CJK)
        run.length == 1 ? [ Term.new(text: run, kind: :cjk) ] : run.each_char.each_cons(2).map { |pair| Term.new(text: pair.join, kind: :cjk) }
      elsif run.length >= MIN_LATIN
        [ Term.new(text: run.downcase, kind: :latin) ]
      else
        []
      end
    end

    # 只保留库里存在的源 id，顺序照给（来源之间 OR，R-4.4）
    def existing_sources(raw)
      ids = raw.split(",").map(&:strip).reject(&:blank?).uniq.first(20)
      ids & Source.where(id: ids).pluck(:id)
    end

    def date_range(from, to)
      from, to = parse_date(from), parse_date(to)
      from && to && from > to ? [ to, from ] : [ from, to ]
    end

    # 形状对得上还要真的是一天：2026-13-45 过正则、过不了 Date.iso8601（Date::Error 是 ArgumentError 的子类）
    def parse_date(raw)
      Date.iso8601(raw) if raw.match?(DATE)
    rescue ArgumentError
      nil
    end

    def page_number(raw)
      number = Integer(raw, exception: false)
      number && number.between?(1, PAGES) ? number : 1
    end
end
