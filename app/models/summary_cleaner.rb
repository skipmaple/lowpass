require "strscan"

class SummaryCleaner
  STORE_LIMIT = 500
  CONTENT_LIMIT = 50_000
  PREVIEW_LIMIT = 200

  # 强调标记只在成对、且两头都落在词边界上时才算排版：snake_case、some_repo_name 里的下划线
  # 是内容不是标记（GitHub Trending 一栏的仓库名与 HN 标题里到处都是），星号同理。
  # 汉字不靠空格分词，紧贴汉字的成对星号仍是排版；下划线保留所有语言的词内标记。
  EMPHASIS = [
    /(?<![[:word:]*&&[^\p{Han}]])\*\*(?![[:space:]])(.+?)(?<![[:space:]])\*\*(?![[:word:]*&&[^\p{Han}]])/m,
    /(?<![[:word:]_])__(?![[:space:]])(.+?)(?<![[:space:]])__(?![[:word:]_])/m,
    /(?<![[:word:]*&&[^\p{Han}]])\*(?![[:space:]*])(.+?)(?<![[:space:]*])\*(?![[:word:]*&&[^\p{Han}]])/m,
    /(?<![[:word:]_])_(?![[:space:]_])(.+?)(?<![[:space:]_])_(?![[:word:]_])/m
  ].freeze
  CODE_SPAN = /(?<!`)(`+)(?!`)(.*?)(?<!`)\1(?!`)/m
  HTML_TAG = /<!--.*?-->|<(?:[^>"']|"[^"]*"|'[^']*')*>/m
  HTML_CODE_TAG = /\A<(\/?)(code|pre)(?=[[:space:]\/>])/i
  HTML_ELEMENT_TAG = /\A<(\/?)([a-z][a-z0-9:-]*)(?=[[:space:]\/>])/i
  HTML_VOID_TAGS = %w[ area base br col embed hr img input link meta param source track wbr ].freeze

  # 源站附加的「阅读更多」链接不是摘要（PRD 7.5）：Hackaday 用 a.read-more，WordPress 默认主题用 a.more-link
  READ_MORE = "a.read-more, a.more-link".freeze
  READ_MORE_MARKER = /\A[[:space:]]*(?:…|\.{3})[[:space:]]*read[[:space:]]+more[[:space:]]*\z/i
  COMPLETE_ENDING = /[.!?。！？…]["'”’）)\]】」』]*[[:space:]]*\z/
  # 旧条目可能存着「…read more」；移除链接文案，保留源站明确的省略号（期发布后不改库）
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

    # 已存摘要的代码边界已经丢失；展示只处理源站的已知尾巴，保留其余纯文本。
    def stored(text)
      remove_read_more_tail(text) if text
    end

    def preview(text)
      truncate(clean(text).to_s, PREVIEW_LIMIT)
    end

    private
      def normalize(text)
        s = strip_markdown(strip_html(protect_code(text), preserve_excerpt_marker: true))
        remove_read_more_tail(CGI.unescapeHTML(s).gsub(/[[:space:]]+/, " ").strip)
      end

      def paragraphs(text)
        s = CGI.unescapeHTML(strip_markdown(strip_html(protect_code(text))))
        s.split("\n").map { |line| line.gsub(/[[:space:]]+/, " ").strip }.reject(&:empty?).join("\n")
      end

      # 先消费完整 HTML 标签与 code/pre，属性与 HTML 代码里的反引号不参与 Markdown 配对。
      # 普通文字里的 Markdown 代码先于 HTML 解析，保留反引号内的 <T> 等标签示例。
      def protect_code(text)
        scanner = StringScanner.new(text)
        result = +""
        html_context = []
        until scanner.eos?
          if tag = scanner.scan(HTML_TAG)
            code_tag = HTML_CODE_TAG.match(tag)
            if code_tag && code_tag[1].empty?
              result << encoded_code(html_code_text(scanner, tag, code_tag[2]))
            else
              result << tag
              update_html_context(html_context, tag)
            end
          elsif html_context.any?
            result << protect_html_text(scanner)
          elsif scanner.scan(CODE_SPAN)
            result << encoded_code(scanner[2])
          else
            result << (scanner.scan(/[^<`]+/) || scanner.getch)
          end
        end
        result
      end

      # 只处理外层代码块一次；Nokogiri 在这里按 HTML 语义解实体，保留内部的反引号。
      def html_code_text(scanner, opening_tag, name)
        html = +opening_tag
        depth = 1
        until scanner.eos? || depth.zero?
          if tag = scanner.scan(HTML_TAG)
            html << tag
            code_tag = HTML_CODE_TAG.match(tag)
            if code_tag && code_tag[2].casecmp?(name)
              depth += code_tag[1].empty? ? 1 : -1
            end
          else
            html << (scanner.scan(/[^<]+/) || scanner.getch)
          end
        end
        Nokogiri::HTML.fragment(html).text
      end

      # 普通 HTML 里的 Markdown 代码只在当前文字节点内配对，闭合标签后回到原始 Markdown。
      def update_html_context(context, tag)
        if element = HTML_ELEMENT_TAG.match(tag)
          name = element[2].downcase
          if element[1] == "/"
            if position = context.rindex(name)
              context.slice!(position..)
            end
          elsif !HTML_VOID_TAGS.include?(name) && !tag.end_with?("/>")
            context << name
          end
        end
      end

      def protect_html_text(scanner)
        node = scanner.scan_until(/(?=#{HTML_TAG})/)
        unless node
          node = scanner.rest
          scanner.terminate
        end
        node.gsub(CODE_SPAN) { encoded_code(Nokogiri::HTML.fragment(Regexp.last_match(2)).text) }
      end

      # 编码两层：后续 HTML 解析解一层，最后实体清洗还原代码，不再解释其中的排版或实体。
      def encoded_code(text)
        text.codepoints.map { |codepoint| "&amp;##{codepoint};" }.join
      end

      def strip_html(text, preserve_excerpt_marker: false)
        fragment = Nokogiri::HTML.fragment(text)
        links = fragment.css(READ_MORE)
        tail = links.last if preserve_excerpt_marker
        links.each { |link| link.remove unless link == tail }
        if tail
          following = CGI.unescapeHTML(strip_markdown(tail.xpath("following::text()").map(&:text).join))
          preceding = CGI.unescapeHTML(strip_markdown(tail.xpath("preceding::text()").map(&:text).join))
          if following.blank? && tail.text.match?(READ_MORE_MARKER) && incomplete_excerpt?(preceding)
            tail.replace("…")
          else
            tail.remove
          end
        end
        fragment.text
      end

      def remove_read_more_tail(text)
        if text.match?(READ_MORE_TAIL)
          prefix = text.sub(READ_MORE_TAIL, "")
          incomplete_excerpt?(prefix) ? "#{prefix}…" : prefix
        else
          text
        end
      end

      def incomplete_excerpt?(text)
        text.present? && !text.match?(COMPLETE_ENDING)
      end

      def strip_markdown(text)
        stripped = text.gsub(/!\[[^\]]*\]\([^)]*\)/, "")  # 图片
            .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')          # 链接保留文字
            .gsub(/^\s{0,3}\#{1,6}\s+/, "")               # 标题
            .gsub(/^\s*[-*+]\s+/, "")                     # 列表符

        EMPHASIS.reduce(stripped) { |s, marker| s.gsub(marker, '\1') }
      end

      def truncate(s, limit)
        s.length > limit ? s[0, limit - 1] + "…" : s
      end
  end
end
