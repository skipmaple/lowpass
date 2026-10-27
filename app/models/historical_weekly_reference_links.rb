require "digest"
require "json"

# 仅在固定原文与已发布条目完整匹配时，为第 415 期两篇文章恢复正文链接。
class HistoricalWeeklyReferenceLinks
  ENTRIES = {
    "59ef50f3a75cc6d9532a63c0a709885190cdbc6c831a23f2b067a6c83acb5987" => [
      [ 6, 30, 40, "https://quesma.com/blog/invisible-cities-one-shot/" ],
      [ 7, 25, 28, "https://p.migdal.pl/invisible-cities-opus-5.5/" ],
      [ 7, 29, 31, "https://github.com/stared/invisible-cities-opus-5.5" ],
      [ 7, 51, 54, "https://p.migdal.pl/invisible-cities-astra/" ],
      [ 7, 55, 57, "https://github.com/stared/invisible-cities-astra" ]
    ].freeze,
    "504e2e68c8507ec11b6a1c775d4226b397cd2c29a82d89af58f9193eb4467618" => [
      [ 0, 8, 10, "https://deno.com/blog/cloudflare" ],
      [ 5, 19, 21, "https://news.ycombinator.com/item?id=50019911#50023277" ]
    ].freeze
  }.freeze

  def self.current
    @current ||= new(entries: ENTRIES)
  end

  def initialize(entries:)
    @entries = entries
  end

  def links_for(item:, issue:, source:)
    return unless issue.kind == "weekly" && issue.state == "published" && source.adapter == "ruanyf_weekly"
    return unless item.issue_id == issue.id && item.source_id == source.id && item.meta.is_a?(Hash)
    return if item.meta.key?("reference_links")
    content = item.content
    images = item.meta["image_urls"] || []
    return unless content.is_a?(String) && content.present? && content.valid_encoding? && content.length < SummaryCleaner::CONTENT_LIMIT
    return unless images.is_a?(Array) && images.all? { |image| image.is_a?(String) }

    identity = [ issue.period_key, source.adapter, item.meta["issue_no"], issue.id, source.id, item.id, item.rank, item.title,
      item.url, item.section, Digest::SHA256.hexdigest(content), Digest::SHA256.hexdigest(JSON.generate(images)) ]
    links = @entries[Digest::SHA256.hexdigest(JSON.generate(identity))]
    return unless links.is_a?(Array) && links.size.between?(1, 128)
    paragraphs = content.split("\n", -1)
    return unless links.each_with_index.all? do |link, i|
      next false unless link.is_a?(Array) && link.size == 4 && link.first(3).all? { |n| n.is_a?(Integer) }
      paragraph, start, finish, href = link
      next false unless paragraph.between?(0, paragraphs.size - 1) && start >= 0 && start < finish && finish <= paragraphs[paragraph].length
      next false unless href.is_a?(String) && Adapters::RuanyfWeekly::ReferenceLinks.absolute(href, item.meta["issue_no"]) == href
      i.zero? || paragraph > links[i - 1][0] || (paragraph == links[i - 1][0] && start >= links[i - 1][2])
    end
    links.map { |paragraph, start, finish, href| [ paragraph, start, finish, href.dup ] }
  rescue JSON::GeneratorError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    nil
  end
end
