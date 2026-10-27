require "digest"
require "json"

# 第 415 期的引用只在固定原文与已发布条目的完整身份一致时用于页面副本。
class HistoricalWeeklyQuotes
  ENTRIES = {
    "59ef50f3a75cc6d9532a63c0a709885190cdbc6c831a23f2b067a6c83acb5987" => [ [ 3, 6 ], [ 13, 20 ] ].freeze,
    "504e2e68c8507ec11b6a1c775d4226b397cd2c29a82d89af58f9193eb4467618" => [ [ 6, 11 ] ].freeze
  }.freeze

  def self.current
    @current ||= new(entries: ENTRIES)
  end

  def initialize(entries:)
    @entries = entries
  end

  def ranges_for(item:, issue:, source:)
    return unless issue.kind == "weekly" && issue.state == "published" && source.adapter == "ruanyf_weekly"
    return unless item.issue_id == issue.id && item.source_id == source.id && item.meta.is_a?(Hash)
    return if item.meta.key?("quote_ranges")
    content = item.content
    images = item.meta["image_urls"] || []
    return unless content.is_a?(String) && content.present? && content.valid_encoding? && content.length < SummaryCleaner::CONTENT_LIMIT
    return unless images.is_a?(Array) && images.all? { |image| image.is_a?(String) }

    identity = [ issue.period_key, source.adapter, item.meta["issue_no"], issue.id, source.id, item.id, item.rank, item.title,
      item.url, item.section, Digest::SHA256.hexdigest(content), Digest::SHA256.hexdigest(JSON.generate(images)) ]
    ranges = @entries[Digest::SHA256.hexdigest(JSON.generate(identity))]
    paragraphs = content.split("\n", -1)
    return unless ranges.is_a?(Array) && ranges.size.between?(1, 128)
    return unless ranges.each_with_index.all? do |range, index|
      range.is_a?(Array) && range.size == 2 && range.all? { |n| n.is_a?(Integer) } &&
        range[0] >= 0 && range[0] < range[1] && range[1] <= paragraphs.size &&
        (index.zero? || range[0] >= ranges[index - 1][1]) &&
        paragraphs[range[0]...range[1]].all? { |line| line.match?(/\A>(?: |\z)/) }
    end

    ranges.map(&:dup)
  rescue JSON::GeneratorError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    nil
  end
end
