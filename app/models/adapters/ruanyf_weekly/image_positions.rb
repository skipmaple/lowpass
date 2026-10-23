module Adapters
  class RuanyfWeekly < Base
    # 只为能逐张证明的独占行图片记录纯文本段落边界；任何歧义都保留旧的全文后图片展示。
    module ImagePositions
      MAX_IMAGES = 128
      FENCE = /\A {0,3}(`{3,}|~{3,})/

      module_function

      def for(body:, content:, image_urls:)
        return if body.blank? || content.blank? || content.length >= SummaryCleaner::CONTENT_LIMIT
        return if image_urls.empty? || image_urls.size > MAX_IMAGES

        images = body.scan(Markdown::IMAGE).flatten
        return unless images == image_urls && images.uniq.size == images.size
        return if code_images?(body)
        return unless SummaryCleaner.content(body.gsub(Markdown::IMAGE, "")) == content

        positions = positions_in(body, content.split("\n"))
        positions if positions&.size == image_urls.size && positions == positions.sort
      end

      def code_images?(body)
        body.include?("<!--") ||
          body.scan(SummaryCleaner::CODE_SPAN).any? { |_, code| code.match?(Markdown::IMAGE) } ||
          body.scan(SummaryCleaner::HTML_TAG).any? { |tag| tag.match?(SummaryCleaner::HTML_CODE_TAG) || tag.match?(Markdown::IMAGE) }
      end

      def positions_in(body, paragraphs)
        positions = []
        offset = 0
        fence = nil

        body.each_line do |line|
          image = line.match(Markdown::IMAGE)
          if fence
            return if image
            fence = nil if line.match?(/\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}\s*\z/)
          elsif marker = line.match(FENCE)
            return if image
            fence = marker[1]
          elsif image
            return unless line.strip == image[0]
            return if line.start_with?("    ") || line[/\A[ \t]*/].include?("\t")

            prefix = SummaryCleaner.content(body[0, offset].gsub(Markdown::IMAGE, "")).to_s.split("\n")
            return unless prefix == paragraphs.take(prefix.size)
            positions << prefix.size
          end
          offset += line.length
        end

        positions
      end
    end
  end
end
