class SummaryCleaner
  STORE_LIMIT = 500
  PREVIEW_LIMIT = 200

  class << self
    def clean(text)
      return nil if text.nil?
      s = strip_markdown(strip_html(text))
      s = CGI.unescapeHTML(s).gsub(/[[:space:]]+/, " ").strip
      truncate(s, STORE_LIMIT)
    end

    def preview(text)
      truncate(clean(text).to_s, PREVIEW_LIMIT)
    end

    private
      def strip_html(text)
        Nokogiri::HTML.fragment(text).text
      end

      def strip_markdown(text)
        text.gsub(/!\[[^\]]*\]\([^)]*\)/, "")            # 图片
            .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')          # 链接保留文字
            .gsub(/^\s{0,3}\#{1,6}\s+/, "")               # 标题
            .gsub(/(\*\*|__|\*|_|`)/, "")                 # 强调与代码
            .gsub(/^\s*[-*+]\s+/, "")                     # 列表符
      end

      def truncate(s, limit)
        s.length > limit ? s[0, limit - 1] + "…" : s
      end
  end
end
