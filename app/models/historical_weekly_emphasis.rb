require "digest"

# 第 416 期作者的独立加粗段落。仅在 D40 图文身份完整匹配、正文哈希一致时用于展示副本。
class HistoricalWeeklyEmphasis
  ENTRIES = {
    [ "2026-W43", 416, 2, "3d7ee822cbc4d9cf5d0215b598a72332252891ded786ccd74ae26907beecb970", [ 4 ] ] =>
      [ 5, 8, 11, 13, 15, 18, 20, 23, 26, 28, 31 ].freeze
  }.freeze

  def self.current
    @current ||= new(entries: ENTRIES)
  end

  def initialize(entries:)
    @entries = entries
  end

  def positions_for(item:, issue:, source:, verified_image_positions:)
    return unless issue.kind == "weekly" && issue.state == "published" && source.adapter == "ruanyf_weekly"
    return unless item.issue_id == issue.id && item.source_id == source.id && item.meta.is_a?(Hash)
    return if item.meta.key?("emphasis_positions") || !verified_image_positions.is_a?(Array)
    content = item.content
    return unless content.is_a?(String) && content.present? && content.valid_encoding? && content.length < SummaryCleaner::CONTENT_LIMIT

    key = [ issue.period_key, item.meta["issue_no"], item.rank, Digest::SHA256.hexdigest(content), verified_image_positions ]
    positions = @entries[key]
    positions.dup if positions && positions.all? { |position| position.is_a?(Integer) && position.between?(0, content.split("\n").size - 1) }
  end
end
