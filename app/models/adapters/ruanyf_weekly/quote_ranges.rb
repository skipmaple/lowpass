module Adapters
  class RuanyfWeekly < Base
    # 只记录能与完整清洗正文逐行对应的普通引用，不猜测代码或嵌套引用。
    module QuoteRanges
      module_function

      def for(body:, content:)
        return if body.blank? || content.blank? || !body.valid_encoding? || !content.valid_encoding?
        return if body.bytesize > 200_000 || content.length >= SummaryCleaner::CONTENT_LIMIT || body.include?("`")
        return if body.match?(/^ {0,3}~{3,}/) || body.match?(%r{</?(?:pre|code)(?:\s|/|>)}i)

        raw_lines = body.lines
        return if raw_lines.size > 2048

        cleaned = []
        ranges = []
        start = nil
        raw_lines.each do |raw|
          text = SummaryCleaner.content(raw)
          quote = raw.chomp.match?(/\A {0,3}>(?:[ \t]|\z)/) && text.present? && text.start_with?(">")
          return if quote && text.sub(/\A>\s*/, "").start_with?(">")
          if quote
            start ||= cleaned.size
          elsif start
            ranges << [ start, cleaned.size ]
            start = nil
          end
          cleaned << text if text.present?
        end
        ranges << [ start, cleaned.size ] if start
        return unless cleaned.join("\n") == content && ranges.size.between?(1, 128)
        return unless ranges.all? { |first, last| cleaned[first...last].any? { |text| text.sub(/\A>\s?/, "").present? } }

        ranges
      end
    end
  end
end
