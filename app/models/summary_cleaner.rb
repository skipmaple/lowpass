class SummaryCleaner
  STORE_LIMIT = 500
  CONTENT_LIMIT = 50_000
  PREVIEW_LIMIT = 200

  # 强调标记只在成对、且两头都落在词边界上时才算排版：snake_case、some_repo_name 里的下划线
  # 是内容不是标记（GitHub Trending 一栏的仓库名与 HN 标题里到处都是），星号同理。
  # 行内代码没有这个问题，一对反引号就是一对。
  EMPHASIS = [
    /(?<![[:word:]*])\*\*(?![[:space:]])(.+?)(?<![[:space:]])\*\*(?![[:word:]*])/m,
    /(?<![[:word:]_])__(?![[:space:]])(.+?)(?<![[:space:]])__(?![[:word:]_])/m,
    /(?<![[:word:]*])\*(?![[:space:]])(.+?)(?<![[:space:]])\*(?![[:word:]*])/m,
    /(?<![[:word:]_])_(?![[:space:]])(.+?)(?<![[:space:]])_(?![[:word:]_])/m,
    /`([^`]*)`/
  ].freeze

  # 源站附加的「阅读更多」链接不是摘要（PRD 7.5）：Hackaday 用 a.read-more，WordPress 默认主题用 a.more-link
  READ_MORE = "a.read-more, a.more-link".freeze
  # 已发布的旧条目库里存着清洗过的「…read more」：读出时再过一遍 clean，只去结尾这一种（期发布后不改库）
  READ_MORE_TAIL = /[[:space:]]*…[[:space:]]*read more[[:space:]]*\z/i

  class << self
    def clean(text)
      truncate(normalize(text), STORE_LIMIT) if text
    end

    # 完整正文（D24）要留住分段：一行一段，各行自己压空白，段与段之间留一个换行，详情页按行分段渲染。
    # 摘要（clean）是一行文字，照旧整段压平。
    def content(text)
      truncate(paragraphs(text), CONTENT_LIMIT) if text
    end

    def preview(text)
      truncate(clean(text).to_s, PREVIEW_LIMIT)
    end

    private
      def normalize(text)
        s = strip_markdown(strip_html(text))
        CGI.unescapeHTML(s).gsub(/[[:space:]]+/, " ").strip.sub(READ_MORE_TAIL, "")
      end

      def paragraphs(text)
        s = CGI.unescapeHTML(strip_markdown(strip_html(text)))
        s.split("\n").map { |line| line.gsub(/[[:space:]]+/, " ").strip }.reject(&:empty?).join("\n")
      end

      def strip_html(text)
        fragment = Nokogiri::HTML.fragment(text)
        fragment.css(READ_MORE).each(&:remove)
        fragment.text
      end

      def strip_markdown(text)
        stripped = text.gsub(/!\[[^\]]*\]\([^)]*\)/, "")  # 图片
            .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')          # 链接保留文字
            .gsub(/^\s{0,3}\#{1,6}\s+/, "")               # 标题
            .gsub(/^\s*[-*+]\s+/, "")                     # 列表符

        EMPHASIS.reduce(stripped) { |s, marker| s.gsub(marker, '\1') }  # 强调与代码
      end

      def truncate(s, limit)
        s.length > limit ? s[0, limit - 1] + "…" : s
      end
  end
end
