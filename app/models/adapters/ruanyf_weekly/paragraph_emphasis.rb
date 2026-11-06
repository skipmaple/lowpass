module Adapters
  class RuanyfWeekly < Base
    # 只记录完整独占行的加粗，无法证明与清洗后正文逐段一致时全部回退。
    module ParagraphEmphasis
      module_function

      def for(body:, content:)
        return if body.blank? || content.blank? || !body.valid_encoding? || !content.valid_encoding?
        return if body.bytesize > 200_000 || content.length >= SummaryCleaner::CONTENT_LIMIT
        return if body.match?(/^ {0,3}(?:`{3,}|~{3,})/) || body.match?(%r{</?(?:pre|code)(?:\s|/|>)}i)

        raw_lines = body.lines
        return if raw_lines.size > 2048

        lines = raw_lines.filter_map do |line|
          cleaned = SummaryCleaner.content(line)
          [ line, cleaned ] if cleaned.present?
        end
        return unless lines.map(&:last).join("\n") == content

        positions = lines.each_index.select do |index|
          raw = lines[index].first
          next false if raw.start_with?("    ") || raw[/\A[ \t]*/].include?("\t")
          match = raw.strip.match(/\A\*\*(.+)\*\*\z/)
          match && match[1] == match[1].strip && !match[1].match?(/[*_`\\<>\[\]]/)
        end
        positions if positions.any? && positions.size <= 256
      end
    end
  end
end
