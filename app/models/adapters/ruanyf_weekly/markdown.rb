module Adapters
  class RuanyfWeekly < Base
    # 把一期周刊的 Markdown 拆成板块与条目（PRD R-2.3）：一级标题给出期号与主题，二级标题是板块，
    # 板块内顶格的「1、」或列表符号开一条，直到下一条、下一个板块或全文结束。
    module Markdown
      TITLE = /\A#\s*科技爱好者周刊（第\s*(\d+)\s*期）[：:]\s*(.+?)\s*\z/
      SECTION = /\A##\s+(.+?)\s*\z/
      ITEM_START = /\A(?:\d+、\s*|（\d+）\s*|\d+\.\s+|[-*]\s+)/
      NUMBERED = /\A\d+、/
      IMAGE = /!\[[^\]]*\]\([^)]*\)/
      IMAGE_LINE = /\A#{IMAGE}\s*\z/
      LINK = %r{(?<!!)\[([^\]]*)\]\(([^)\s]+)\)}
      BOLD = /\*\*([^*]+)\*\*/
      DATE = /(\d{4})年(\d{1,2})月(\d{1,2})日/
      MARKUP = /[*_`#>]/
      ABSOLUTE = %r{\Ahttps?://}i
      SCHEME = %r{\A[a-z][a-z0-9+.\-]*:}i

      module_function

      def parse(text)
        issue_no = nil
        title = nil
        published_on = nil
        sections = []
        section = nil
        block = []

        text.each_line do |raw|
          line = raw.chomp
          if issue_no.nil? && (heading = line.match(TITLE))
            issue_no = heading[1].to_i
            title = heading[2]
          elsif (heading = line.match(SECTION))
            flush(section, block)
            block = []
            section = { name: heading[1], items: [] }
            sections << section
          elsif section && item_start?(line, block)
            flush(section, block)
            block = [ line ]
          elsif block.any?
            block << line
          elsif published_on.nil?
            published_on = date_in(line)
          end
        end
        flush(section, block)

        { issue_no: issue_no, title: title, published_on: published_on, sections: sections.reject { |s| s[:items].empty? } }
      end

      # 条目以「1、」编号。编号条目的正文里，顶格的 `（1）`/`-`/`1.` 列表属于正文，不另开一条（R-2.3：嵌套内容并入摘要）；
      # 没有编号条目时，这些符号才是板块自己的条目（如 401 的「一句话消息」、403 的科技动态）。
      def item_start?(line, block)
        line.match?(NUMBERED) || (line.match?(ITEM_START) && !block.first.to_s.match?(NUMBERED))
      end

      def flush(section, block)
        section[:items] << build_item(block, section[:name]) if section && block.any?
      end

      def build_item(block, section)
        lines = body_of(block)
        body = lines.join("\n")
        title = title_of(lines, body)
        {
          title: title,
          url: link_in(body),
          summary: summary_of(lines, title),
          section: section
        }
      end

      # 去掉条目符号与单独成行的图片（图片不下载不展示），首尾空行也不要。
      def body_of(block)
        lines = [ block.first.sub(ITEM_START, ""), *block.drop(1) ].reject { |line| line.match?(IMAGE_LINE) }
        lines.shift while lines.first&.strip&.empty?
        lines.pop while lines.last&.strip&.empty?
        lines
      end

      # 标题取首行的加粗文本，其次是块内首个链接的文本，都没有就取首个非空行的纯文本。
      def title_of(lines, body)
        candidates = [ lines.first.to_s[BOLD, 1], body[LINK, 1], *lines.map { |line| plain(line) } ]
        candidates.compact.find(&:present?)
      end

      # 相对链接留给 fetch_issue 按原文地址解析，mailto: 这类非 http 链接不要。
      def link_in(body)
        body.scan(LINK).map(&:last).find { |href| href.match?(ABSOLUTE) || !href.match?(SCHEME) }
      end

      # 首行只有标题时不重复进摘要；Markdown 标记留着，存储时再由 SummaryCleaner 清洗、截断。
      def summary_of(lines, title)
        body = plain(lines.first.to_s) == title ? lines.drop(1) : lines
        body.drop_while { |line| line.strip.empty? }.join("\n")
      end

      def plain(line)
        line.gsub(IMAGE, "").gsub(LINK, '\1').gsub(MARKUP, "").strip
      end

      def date_in(line)
        year, month, day = line.match(DATE)&.captures&.map(&:to_i)
        Date.new(year, month, day) if year && Date.valid_date?(year, month, day)
      end
    end
  end
end
