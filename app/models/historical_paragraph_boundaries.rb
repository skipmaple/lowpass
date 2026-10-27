require "digest"
require "json"

# 旧刊段落只改变周刊页面副本；身份、原文或图片位置有任何歧义时保留原状。
class HistoricalParagraphBoundaries
  VERSION = 1
  MAX_FILES = 1024
  MAX_FILE_BYTES = 2.megabytes
  MAX_BOUNDARIES = 63
  SHA256 = /\A[0-9a-f]{64}\z/
  COMMIT = /\A[0-9a-f]{40}\z/
  PERIOD = /\A\d{4}-W\d{2}\z/

  class UniqueObject < Hash
    def []=(key, value)
      raise JSON::ParserError, "duplicate object key" if key?(key)
      super
    end
  end

  class << self
    def current
      @current ||= new(paths: Dir.glob(Rails.root.join("config/weekly_paragraph_boundaries/*.json")).sort)
    end
  end

  def initialize(paths:)
    @entries = load_entries(paths)
  end

  def content_for(item:, issue:, source:, meta:)
    return unless issue.kind == "weekly" && issue.state == "published" && source.adapter == "ruanyf_weekly"
    return unless item.issue_id == issue.id && item.source_id == source.id && item.meta.is_a?(Hash) && meta.is_a?(Hash)
    return if meta.key?("image_positions") || item.meta.key?("image_positions")
    return unless meta["issue_no"] == item.meta["issue_no"] && meta["image_urls"] == item.meta["image_urls"]

    number = item.meta["issue_no"]
    images = item.meta["image_urls"] || []
    content = item.content
    return unless number.is_a?(Integer) && number.positive? && item.rank.is_a?(Integer) && item.rank.positive? && images.is_a?(Array)
    return unless content.is_a?(String) && content.present? && content.valid_encoding? && !content.include?("\n") && content.bytesize <= 200_000

    key = digest([ issue.id, source.id, number, item.rank ])
    entry = @entries[key]
    return unless entry && entry[:period] == issue.period_key && entry[:issue_no] == number

    identity = [ issue.period_key, source.adapter, number, issue.id, source.id, item.id, item.rank, item.title, item.url, item.section,
      Digest::SHA256.hexdigest(content), digest(images) ]
    return unless digest(identity) == entry[:identity]

    replace_boundaries(content, entry[:offsets])
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError, ArgumentError
    nil
  end

  private
    def replace_boundaries(content, offsets)
      bytes = content.b
      return unless offsets.is_a?(Array) && offsets.size.between?(1, MAX_BOUNDARIES) && offsets.all? { |n| n.is_a?(Integer) }
      return unless offsets.each_cons(2).all? { |left, right| left < right }
      return unless offsets.all? { |n| n.positive? && n < bytes.bytesize - 1 && bytes.getbyte(n) == 32 && bytes.getbyte(n - 1) != 32 && bytes.getbyte(n + 1) != 32 }

      result = bytes.dup
      offsets.each { |n| result.setbyte(n, 10) }
      result.force_encoding(Encoding::UTF_8)
      result if result.valid_encoding? && result.tr("\n", " ").b == bytes
    end

    def load_entries(paths)
      raise ArgumentError if paths.size > MAX_FILES

      entries = {}
      paths.each do |path|
        text = File.read(path, MAX_FILE_BYTES + 1)
        raise ArgumentError if text.bytesize > MAX_FILE_BYTES
        manifest = JSON.parse(text, object_class: UniqueObject)
        raise ArgumentError unless valid_manifest?(manifest)

        manifest.fetch("entries").each do |row|
          raise ArgumentError unless valid_entry?(row) && !entries.key?(row.fetch("lookup_sha256"))
          entries[row.fetch("lookup_sha256")] = { period: manifest.fetch("period"), issue_no: manifest.fetch("issue_no"),
            identity: row.fetch("identity_sha256"), offsets: row.fetch("offsets") }
        end
      end
      entries
    rescue SystemCallError, JSON::ParserError, ArgumentError, TypeError, KeyError
      Rails.logger.warn("Historical paragraph index unavailable; using original presentation")
      {}
    end

    def valid_manifest?(manifest)
      manifest.is_a?(Hash) && manifest["version"] == VERSION && manifest["period"].is_a?(String) && PERIOD.match?(manifest["period"]) &&
        manifest["issue_no"].is_a?(Integer) && manifest["issue_no"].positive? && manifest["source_commit"].is_a?(String) && COMMIT.match?(manifest["source_commit"]) &&
        manifest["source_sha256"].is_a?(String) && SHA256.match?(manifest["source_sha256"]) && manifest["entries"].is_a?(Array)
    end

    def valid_entry?(row)
      row.is_a?(Hash) && row["rank"].is_a?(Integer) && row["rank"].positive? && row["lookup_sha256"].is_a?(String) && SHA256.match?(row["lookup_sha256"]) &&
        row["identity_sha256"].is_a?(String) && SHA256.match?(row["identity_sha256"]) && row["offsets"].is_a?(Array)
    end

    def digest(value)
      Digest::SHA256.hexdigest(JSON.generate(value))
    end
end
