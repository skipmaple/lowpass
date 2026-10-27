require "digest"
require "json"
require "uri"
require "ipaddr"

# 已核对的旧刊展示位置只进入 props，不改已发布条目；任何不可信状态都保留原展示。
class HistoricalImagePositions
  VERSION = 1
  MAX_FILES = 1024
  MAX_FILE_BYTES = 2.megabytes
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
      @current ||= new(paths: Dir.glob(Rails.root.join("config/weekly_image_positions/*.json")).sort)
    end
  end

  def initialize(paths:)
    @entries = load_entries(paths)
  end

  def positions_for(item:, issue:, source:)
    return unless issue.kind == "weekly" && issue.state == "published" && source.adapter == "ruanyf_weekly"
    return unless item.issue_id == issue.id && item.source_id == source.id && item.meta.is_a?(Hash)
    return if item.meta.key?("image_positions")

    number = item.meta["issue_no"]
    images = item.meta["image_urls"]
    content = item.content
    return unless number.is_a?(Integer) && number.positive? && item.rank.is_a?(Integer) && item.rank.positive?
    return unless content.is_a?(String) && content.present? && content.encode(Encoding::UTF_16LE).bytesize / 2 < 50_000
    return unless images.is_a?(Array) && images.size.between?(1, 128) && images.uniq.size == images.size && images.all? { |url| http_image?(url) }

    paragraphs = content.split("\n", -1)
    return if paragraphs.any?(&:empty?)
    key = digest([ issue.id, source.id, number, item.rank ])
    entry = @entries[key]
    return unless entry && entry[:period] == issue.period_key && entry[:issue_no] == number

    identity = [ issue.period_key, source.adapter, number, issue.id, source.id, item.id, item.rank, item.title, item.url, item.section,
      Digest::SHA256.hexdigest(content), digest(images) ]
    positions = entry[:positions]
    return unless digest(identity) == entry[:identity] && valid_positions?(positions, images.size, paragraphs.size)

    positions.dup
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    nil
  end

  private
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
            identity: row.fetch("identity_sha256"), positions: row.fetch("positions") }
        end
      end
      entries
    rescue SystemCallError, JSON::ParserError, ArgumentError, TypeError, KeyError
      Rails.logger.warn("Historical image position index unavailable; using original presentation")
      {}
    end

    def valid_manifest?(manifest)
      manifest.is_a?(Hash) && manifest["version"] == VERSION && manifest["period"].is_a?(String) && PERIOD.match?(manifest["period"]) &&
        manifest["issue_no"].is_a?(Integer) && manifest["issue_no"].positive? && manifest["source_commit"].is_a?(String) && COMMIT.match?(manifest["source_commit"]) &&
        manifest["source_sha256"].is_a?(String) && SHA256.match?(manifest["source_sha256"]) && manifest["entries"].is_a?(Array)
    end

    def valid_entry?(row)
      row.is_a?(Hash) && row["rank"].is_a?(Integer) && row["rank"].positive? && row["lookup_sha256"].is_a?(String) && SHA256.match?(row["lookup_sha256"]) &&
        row["identity_sha256"].is_a?(String) && SHA256.match?(row["identity_sha256"]) && row["positions"].is_a?(Array)
    end

    def http_image?(value)
      return false unless value.is_a?(String) && value.match?(%r{\Ahttps?://}i)

      uri = URI.parse(value)
      return false unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.port.between?(0, 65_535)
      host = uri.host
      return false if host.include?("%")
      last_label = host.delete_suffix(".").split(".").last
      IPAddr.new(host) if last_label&.match?(/\A(?:[0-9]+|0x[0-9a-f]+)\z/i)
      true
    rescue URI::InvalidURIError, IPAddr::InvalidAddressError
      false
    end

    def valid_positions?(positions, image_count, paragraph_count)
      positions.size == image_count && positions.all? { |value| value.is_a?(Integer) && value.between?(0, paragraph_count) } && positions == positions.sort
    end

    def digest(value)
      Digest::SHA256.hexdigest(JSON.generate(value))
    end
end
