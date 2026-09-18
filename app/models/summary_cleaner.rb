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

  class << self
    def clean(text)
      truncate(normalize(text), STORE_LIMIT) if text
    end

    def content(text)
      truncate(normalize(text), CONTENT_LIMIT) if text
    end

    def preview(text)
      truncate(clean(text).to_s, PREVIEW_LIMIT)
    end

    private
      def normalize(text)
        s = strip_markdown(strip_html(text))
        CGI.unescapeHTML(s).gsub(/[[:space:]]+/, " ").strip
      end

      def strip_html(text)
        Nokogiri::HTML.fragment(text).text
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
