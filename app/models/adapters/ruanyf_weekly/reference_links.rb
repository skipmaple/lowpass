module Adapters
  class RuanyfWeekly < Base
    # 仅记录原文与完整清洗正文可逐字对应的普通链接；不解释代码和不确定的标记。
    module ReferenceLinks
      LINK = /(?<!!)\[([^\[\]\n]+)\]\(([^()\s]+)\)/
      MARKER = /\uE000(\d+)S\uE001(.*?)\uE000\1E\uE001/
      RESERVED = /[\uE000\uE001]/

      module_function

      def for(body:, content:, issue_no:)
        return if body.blank? || content.blank? || !body.valid_encoding? || !content.valid_encoding?
        return if body.bytesize > 200_000 || content.length >= SummaryCleaner::CONTENT_LIMIT || body.lines.size > 2048
        return if body.match?(RESERVED) || body.include?("`") || body.match?(/^ {0,3}~{3,}/) || body.match?(%r{</?[a-z][^>]*>}i)
        return unless issue_no.is_a?(Integer) && issue_no.positive?

        addresses = []
        marked = body.gsub(LINK) do
          label, href = Regexp.last_match.captures
          return if label.match?(/[\[\]<>\\*_]/)
          address = absolute(href, issue_no)
          return unless address
          index = addresses.size
          addresses << address
          "\uE000#{index}S\uE001#{label}\uE000#{index}E\uE001"
        end
        return if addresses.empty? || addresses.size > 128 || marked.match?(/[\[\]]/)

        cleaned = SummaryCleaner.content(marked)
        return unless cleaned
        links = []
        lines = cleaned.split("\n").each_with_index.map do |line, paragraph|
          plain = +""
          offset = 0
          line.to_enum(:scan, MARKER).each do
            match = Regexp.last_match
            plain << line[offset...match.begin(0)]
            start = plain.length
            plain << match[2]
            index = match[1].to_i
            links << [ paragraph, start, plain.length, addresses[index] ]
            offset = match.end(0)
          end
          plain << line[offset..]
          plain
        end
        return unless links.size == addresses.size && links.all? { |_, start, finish, href| href && finish > start }
        return if lines.any? { |line| line.match?(RESERVED) }
        links if lines.join("\n") == content
      end

      def absolute(href, issue_no)
        return if href.length > 2048
        uri = URI.join("#{RuanyfWeekly::ORIGINAL}/issue-#{issue_no}.md", href)
        uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
      rescue URI::Error
        nil
      end
    end
  end
end
