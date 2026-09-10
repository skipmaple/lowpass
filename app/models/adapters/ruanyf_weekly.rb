module Adapters
  class RuanyfWeekly < Base
    RAW = "https://raw.githubusercontent.com/ruanyf/weekly/master"
    ORIGINAL = "https://github.com/ruanyf/weekly/blob/master/docs"

    # 条目太少说明原文结构变了：整期降级交给调用方处理，不在这里悄悄放过。
    Degraded = Class.new(StandardError) { attr_accessor :issue_no, :issue_title, :url }

    def latest_issue_number
      numbers = http("#{RAW}/README.md").body.scan(%r{docs/issue-(\d+)\.md}).flatten.map(&:to_i)
      numbers.max or raise Http::Error, "README 里没有期号"
    end

    def fetch_issue(number)
      parsed = Markdown.parse(http("#{RAW}/docs/issue-#{number}.md").body)
      items = parsed[:sections].flat_map { |section| section[:items] }
      raise degraded(number, parsed[:title], items.size) if items.size < config.fetch(:min_items, 5).to_i

      items.each_with_index.map { |item, index| entry(item, parsed, number, index + 1) }
    end

    private
      def entries(period_key:)
        fetch_issue(latest_issue_number)
      end

      def degraded(number, title, count)
        Degraded.new("issue #{number} parsed #{count} items").tap do |error|
          error.issue_no = number
          error.issue_title = title
          error.url = original(number)
        end
      end

      def entry(item, parsed, number, rank)
        Entry.new(
          title: item[:title],
          url: url_for(item, number, rank),
          summary: item[:summary],
          section: item[:section],
          published_at: parsed[:published_on]&.in_time_zone(PeriodKey::ZONE)&.beginning_of_day&.utc,
          rank: rank,
          meta: { issue_no: number, issue_title: parsed[:title], anchor: anchor(item[:section]) }
        )
      end

      # 相对链接以原文地址为基解析成绝对地址；没有链接的条目（言论、图注）回退到原文的板块锚点。
      # 图片板块必须用回退地址，忽略条目内的链接（R24）。
      def url_for(item, number, rank)
        if item[:section] == "图片"
          fallback_url(item[:section], number, rank)
        else
          absolute(item[:url], number) || fallback_url(item[:section], number, rank)
        end
      end

      def absolute(href, number)
        URI.join(original(number), href).to_s if href.present?
      rescue URI::Error
        nil
      end

      # 归一化会丢掉 fragment，同期回退到同一板块的条目会撞 url_hash 唯一索引，所以带上条目序号；
      # GitHub 忽略这个查询参数，UrlNormalizer 不当它是跟踪参数（R25）。
      # 锚点还要转义，否则中文板块名过不了 URI 解析，条目会被当成非法链接丢掉。
      def fallback_url(section, number, rank)
        "#{original(number)}?item=#{rank}##{URI::DEFAULT_PARSER.escape(anchor(section))}"
      end

      def original(number)
        "#{ORIGINAL}/issue-#{number}.md"
      end

      # 对齐 GitHub 的锚点算法：转小写，去掉非单词字符，空格换连字符。
      def anchor(section)
        section.to_s.downcase.gsub(/[^\p{Word}\s-]/, "").gsub(/\s+/, "-")
      end
  end
end
