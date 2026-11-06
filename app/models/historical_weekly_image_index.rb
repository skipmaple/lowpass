require "digest"
require "json"
require "open3"

# 离线构建工具：从本地 Git 对象库读取指定提交的原文，不触发延迟下载。
class HistoricalWeeklyImageIndex
  def self.generate(repository:, snapshot:, source_commit:, source_sha256:)
    period = snapshot.fetch("period")
    number = snapshot.fetch("issue_no")
    rows = snapshot.fetch("rows")
    raise ArgumentError, "invalid snapshot" unless period.match?(/\A\d{4}-W\d{2}\z/) && number.is_a?(Integer) && number.positive? && rows.is_a?(Array)
    raise ArgumentError, "invalid source version" unless source_commit.match?(/\A[0-9a-f]{40}\z/) && source_sha256.match?(/\A[0-9a-f]{64}\z/)
    git_env = { "GIT_NO_LAZY_FETCH" => "1", "GIT_TERMINAL_PROMPT" => "0" }
    type, _, type_status = Open3.capture3(git_env, "git", "--no-replace-objects", "-C", repository, "cat-file", "-t", source_commit)
    raise ArgumentError, "source is not a commit" unless type_status.success? && type.strip == "commit"
    source, _, status = Open3.capture3(git_env,
      "git", "--no-replace-objects", "-C", repository, "show", "#{source_commit}:docs/issue-#{number}.md")
    source.force_encoding(Encoding::UTF_8)
    raise ArgumentError, "source does not match commit or digest" unless status.success? && source.valid_encoding? && Digest::SHA256.hexdigest(source) == source_sha256
    parsed = Adapters::RuanyfWeekly::Markdown.parse(source)
    raise ArgumentError, "issue mismatch" unless parsed[:issue_no] == number
    raise ArgumentError, "ambiguous issue or source" unless rows.map { |row| row.values_at("issue_id", "source_id") }.uniq.one?

    adapter = Adapters::RuanyfWeekly.allocate
    upstream = parsed[:sections].flat_map { |section| section[:items] }.each_with_index.map do |item, index|
      entry = adapter.send(:entry, item, parsed, number, index + 1)
      urls = entry.meta[:image_urls] || []
      content = SummaryCleaner.content(entry.content).to_s
      { "rank" => entry.rank, "title" => entry.title.to_s.strip[0, 300], "url" => entry.url.to_s.strip[0, 2048],
        "section" => entry.section&.strip&.slice(0, 100), "content_sha256" => Digest::SHA256.hexdigest(content),
        "images_sha256" => Digest::SHA256.hexdigest(JSON.generate(urls)), "image_count" => urls.size,
        "content" => content, "urls" => urls, "positions" => entry.meta[:image_positions] }
    end
    key = ->(row) { row.values_at("rank", "title", "section", "url") }
    upstream_by_key = upstream.group_by(&key)
    snapshot_by_key = rows.group_by(&key)
    entries = rows.filter_map do |row|
      candidates = upstream_by_key.fetch(key.call(row), [])
      next unless candidates.one? && snapshot_by_key.fetch(key.call(row)).one?
      fresh = candidates.first
      next unless row["positions_present"] == false && row.values_at("content_sha256", "images_sha256", "image_count") == fresh.values_at("content_sha256", "images_sha256", "image_count")
      positions = fresh["positions"]
      paragraphs = fresh["content"].split("\n", -1)
      next unless fresh["image_count"].between?(1, 128) && fresh["content"].present? && fresh["content"].encode(Encoding::UTF_16LE).bytesize / 2 < 50_000 && paragraphs.none?(&:empty?)
      next unless positions.is_a?(Array) && positions.size == fresh["image_count"] && positions.all? { |p| p.is_a?(Integer) && p.between?(0, paragraphs.size) } && positions == positions.sort

      identity = [ period, "ruanyf_weekly", number, *row.values_at("issue_id", "source_id", "item_id", "rank", "title", "url", "section", "content_sha256", "images_sha256") ]
      lookup = row.values_at("issue_id", "source_id") + [ number, row.fetch("rank") ]
      { lookup_sha256: Digest::SHA256.hexdigest(JSON.generate(lookup)), rank: row.fetch("rank"),
        identity_sha256: Digest::SHA256.hexdigest(JSON.generate(identity)), positions: positions }
    end
    raise ArgumentError, "duplicate lookup" unless entries.map { |row| row[:lookup_sha256] }.uniq.size == entries.size

    { version: 1, period: period, issue_no: number, source_commit: source_commit, source_sha256: source_sha256, entries: entries }
  end
end
