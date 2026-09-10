module Adapters
  class RuanyfWeekly < Base
    # 把一期周刊的 Markdown 拆成板块与条目（PRD R-2.3）：一级标题给出期号与主题，二级标题是板块。
    # 板块按名字分三类：固定的清单板块按条目符号拆条（顶格的「1、」或列表符号开一条，直到下一条、
    # 下一个板块或全文结束）；封面图与往年回顾整块不要；其余（本周话题这类专题）整节成为一条（R26）。
    module Markdown
      TITLE = /\A#\s*科技爱好者周刊（第\s*(\d+)\s*期）[：:]\s*(.+?)\s*\z/
      SECTION = /\A##\s+(.+?)\s*\z/
      LIST_SECTIONS = [ "科技动态", "文章", "工具", "资源", "AI 相关", "图片", "文摘", "言论", "一句话消息" ].freeze
      SKIPPED_SECTIONS = [ "封面图", "往年回顾" ].freeze
      TRAILING_COLON = /[:：]\s*\z/
      ITEM_START = /\A(?:\d+、\s*|（\d+）\s*|\d+\.\s+|[-*]\s+)/
      NUMBERED = /\A\d+、/
      IMAGE = /!\[[^\]]*\]\([^)]*\)/
      IMAGE_LINE = /\A#{IMAGE}\s*\z/
      LINK = %r{(?<!!)\[([^\]]*)\]\(([^)\s]+)\)}
      BOLD = /\*\*([^*]+)\*\*/
      ANNOTATION = /\A[（(][^（()）]*[)）]\z/
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

        text.each_line do |raw|
          line = raw.chomp
          if issue_no.nil? && (heading = line.match(TITLE))
            issue_no = heading[1].to_i
            title = heading[2]
          elsif (heading = line.match(SECTION))
            section = { name: heading[1], lines: [] }
            sections << section
          elsif section
            section[:lines] << line
          elsif published_on.nil?
            # 日期只找第一个板块之前的开篇：板块正文里的年月日说的是别人的事，不是本期的发布日。
            published_on = date_in(line)
          end
        end

        {
          issue_no: issue_no,
          title: title,
          published_on: published_on,
          sections: sections.map { |s| { name: s[:name], items: items_in(s) } }.reject { |s| s[:items].empty? }
        }
      end

      def items_in(section)
        case classify(section[:name])
        when :skipped then []
        when :list then list_items(section[:lines], section[:name])
        else essay_items(section[:lines], section[:name])
        end
      end

      # 板块名可能带全角/半角冒号（「文章：」），认名字时先去掉。
      def classify(name)
        key = name.to_s.strip.sub(TRAILING_COLON, "").strip
        if SKIPPED_SECTIONS.include?(key)
          :skipped
        elsif LIST_SECTIONS.include?(key)
          :list
        else
          :essay
        end
      end

      def list_items(lines, section)
        items = []
        block = []

        lines.each do |line|
          if item_start?(line, block)
            items << build_item(block, section) if block.any?
            block = [ line ]
          elsif block.any?
            block << line
          end
        end
        items << build_item(block, section) if block.any?

        items
      end

      # 条目以「1、」编号。编号条目的正文里，顶格的 `（1）`/`-`/`1.` 列表属于正文，不另开一条（R-2.3：嵌套内容并入摘要）；
      # 没有编号条目时，这些符号才是板块自己的条目（如 403 的科技动态）。
      def item_start?(line, block)
        line.match?(NUMBERED) || (line.match?(ITEM_START) && !block.first.to_s.match?(NUMBERED))
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
        trim([ block.first.sub(ITEM_START, ""), *block.drop(1) ].reject { |line| line.match?(IMAGE_LINE) })
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

      # 首行只是标题时不重复进摘要；Markdown 标记留着，存储时再由 SummaryCleaner 清洗、截断。
      def summary_of(lines, title)
        body = title_line?(lines.first.to_s, title) ? lines.drop(1) : lines
        body.drop_while { |line| line.strip.empty? }.join("\n")
      end

      # 标题后面只跟着「（英文）」这类括注的，整行还是标题；跟着正文的（`[欧盟](…)规定，……`）要留下。
      def title_line?(line, title)
        text = plain(line)
        if title.present? && text.start_with?(title)
          rest = text.delete_prefix(title).strip
          rest.empty? || rest.match?(ANNOTATION)
        else
          false
        end
      end

      def plain(line)
        line.gsub(IMAGE, "").gsub(LINK, '\1').gsub(MARKUP, "").strip
      end

      # 专题板块整节就是一条：标题是板块名，摘要是整节正文（嵌套列表原样保留），链接取正文里的第一个。
      def essay_items(lines, section)
        body = trim(lines.reject { |line| line.match?(IMAGE_LINE) }).join("\n")
        if body.present?
          [ { title: section, url: link_in(body), summary: body, section: section } ]
        else
          []
        end
      end

      def trim(lines)
        lines = lines.dup
        lines.shift while lines.first&.strip&.empty?
        lines.pop while lines.last&.strip&.empty?
        lines
      end

      def date_in(line)
        year, month, day = line.match(DATE)&.captures&.map(&:to_i)
        Date.new(year, month, day) if year && Date.valid_date?(year, month, day)
      end
    end
  end
end
