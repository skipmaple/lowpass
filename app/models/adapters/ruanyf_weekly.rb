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
          url: url_for(item, number),
          summary: item[:summary],
          section: item[:section],
          published_at: parsed[:published_on]&.in_time_zone(PeriodKey::ZONE)&.beginning_of_day&.utc,
          rank: rank,
          meta: { issue_no: number, issue_title: parsed[:title], anchor: anchor(item[:section]) }
        )
      end

      # 相对链接以原文地址为基解析成绝对地址；没有链接的条目（言论、图注）指向原文的板块锚点。
      def url_for(item, number)
        absolute(item[:url], number) || anchor_url(item[:section], number)
      end

      def absolute(href, number)
        URI.join(original(number), href).to_s if href.present?
      rescue URI::Error
        nil
      end

      # 锚点要转义，否则中文板块名过不了 URI 解析，条目会被当成非法链接丢掉。
      def anchor_url(section, number)
        "#{original(number)}##{URI::DEFAULT_PARSER.escape(anchor(section))}"
      end

      def original(number)
        "#{ORIGINAL}/issue-#{number}.md"
      end

      def anchor(section)
        section.to_s.downcase.gsub(/\s+/, "-")
      end
  end
end
