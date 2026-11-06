require "digest"
require "json"
require "open3"

# 离线生成展示索引：调用方只传已经逐条核对过的序号；不读取线上或保存正文。
class HistoricalWeeklyParagraphIndex
  def self.generate(repository:, snapshot:, source_commit:, source_sha256:, reviewed_ranks:)
    period = snapshot.fetch("period")
    number = snapshot.fetch("issue_no")
    rows = snapshot.fetch("rows")
    raise ArgumentError, "invalid snapshot" unless period.is_a?(String) && period.match?(/\A\d{4}-W\d{2}\z/) && number.is_a?(Integer) && number.positive? && rows.is_a?(Array) && rows.any?
    raise ArgumentError, "ambiguous snapshot" unless rows.all? { |row| row["period"] == period && row["source_adapter"] == "ruanyf_weekly" && row.dig("meta", "issue_no") == number } &&
      rows.map { |row| row.values_at("issue_id", "source_id") }.uniq.one? && rows.map { |row| row["rank"] }.uniq.size == rows.size && rows.map { |row| row["item_id"] }.uniq.size == rows.size
    raise ArgumentError, "invalid reviewed ranks" unless reviewed_ranks.is_a?(Array) && reviewed_ranks.uniq == reviewed_ranks && reviewed_ranks.all? { |rank| rank.is_a?(Integer) && rank.positive? }
    raise ArgumentError, "invalid source version" unless source_commit.match?(/\A[0-9a-f]{40}\z/) && source_sha256.match?(/\A[0-9a-f]{64}\z/)

    env = { "GIT_NO_LAZY_FETCH" => "1", "GIT_TERMINAL_PROMPT" => "0", "GIT_ALTERNATE_OBJECT_DIRECTORIES" => nil, "GIT_OBJECT_DIRECTORY" => nil }
    alternate, _, alternate_status = Open3.capture3(env, "git", "--no-replace-objects", "-C", repository, "rev-parse", "--git-path", "objects/info/alternates")
    raise ArgumentError, "alternate object store" unless alternate_status.success? && !File.exist?(File.expand_path(alternate.strip, repository))
    type, _, type_status = Open3.capture3(env, "git", "--no-replace-objects", "-C", repository, "cat-file", "-t", source_commit)
    raise ArgumentError, "source is not a commit" unless type_status.success? && type.strip == "commit"
    source, _, status = Open3.capture3(env, "git", "--no-replace-objects", "-C", repository, "show", "#{source_commit}:docs/issue-#{number}.md")
    source.force_encoding(Encoding::UTF_8)
    raise ArgumentError, "source does not match commit or digest" unless status.success? && source.valid_encoding? && Digest::SHA256.hexdigest(source) == source_sha256
    parsed = Adapters::RuanyfWeekly::Markdown.parse(source)
    raise ArgumentError, "issue mismatch" unless parsed[:issue_no] == number

    adapter = Adapters::RuanyfWeekly.allocate
    upstream = parsed[:sections].flat_map { |section| section[:items] }.each_with_index.map do |item, index|
      entry = adapter.send(:entry, item, parsed, number, index + 1)
      { rank: entry.rank, title: entry.title.to_s.strip[0, 300], url: entry.url.to_s.strip[0, 2048], section: entry.section&.strip&.slice(0, 100),
        content: SummaryCleaner.content(entry.content).to_s, summary: SummaryCleaner.clean(entry.summary), images: entry.meta[:image_urls] || [] }
    end
    entries = rows.sort_by { |row| row["rank"] }.filter_map do |row|
      next unless reviewed_ranks.include?(row["rank"])
      candidates = upstream.select { |entry| [ entry[:rank], entry[:title], entry[:url], entry[:section] ] == row.values_at("rank", "title", "url", "section") }
      next unless candidates.one? && !row.fetch("meta").key?("image_positions")
      entry = candidates.first
      next unless entry[:summary] == row["summary"] && entry[:images] == (row.dig("meta", "image_urls") || [])
      content = row["content"]
      paragraphs = entry[:content].split("\n", -1)
      next unless content.is_a?(String) && !content.include?("\n") && paragraphs.size.between?(2, 64) && paragraphs.none?(&:empty?) && paragraphs.join(" ") == content

      at = 0
      offsets = paragraphs[0...-1].map { |paragraph| at += paragraph.bytesize; boundary = at; at += 1; boundary }
      next unless offsets.each_cons(2).all? { |left, right| left < right } && offsets.all? { |n| n.positive? && n < content.bytesize - 1 && content.b.getbyte(n) == 32 && content.b.getbyte(n - 1) != 32 && content.b.getbyte(n + 1) != 32 }
      bytes = content.b.dup
      offsets.each { |n| bytes.setbyte(n, 10) }
      result = bytes.force_encoding(Encoding::UTF_8)
      next unless result.valid_encoding? && result.split("\n", -1) == paragraphs && result.tr("\n", " ").b == content.b

      digest = ->(value) { Digest::SHA256.hexdigest(JSON.generate(value)) }
      identity = [ period, "ruanyf_weekly", number, *row.values_at("issue_id", "source_id", "item_id", "rank", "title", "url", "section"),
        Digest::SHA256.hexdigest(content), digest.call(entry[:images]) ]
      lookup = row.values_at("issue_id", "source_id") + [ number, row.fetch("rank") ]
      { lookup_sha256: digest.call(lookup), rank: row.fetch("rank"), identity_sha256: digest.call(identity), offsets: offsets }
    end
    raise ArgumentError, "duplicate lookup" unless entries.map { |row| row[:lookup_sha256] }.uniq.size == entries.size

    { version: 1, period: period, issue_no: number, source_commit: source_commit, source_sha256: source_sha256, entries: entries }
  end
end
