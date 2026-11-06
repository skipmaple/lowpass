require "test_helper"
require "tmpdir"
require "digest"
require "open3"

class HistoricalWeeklyParagraphIndexTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir("paragraph-source-")
    FileUtils.mkdir_p(File.join(@dir, "docs"))
    @markdown = "# 科技爱好者周刊（第 412 期）：测试\n\n## 文章\n\n1、[标题](https://example.com/story)\n\n第一段 😀。\n\n第二段。\n"
    File.write(File.join(@dir, "docs/issue-412.md"), @markdown)
    system("git", "init", "-q", @dir, exception: true)
    system("git", "-C", @dir, "add", "docs/issue-412.md", exception: true)
    system("git", "-C", @dir, "-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-qm", "fixture", exception: true)
    @commit = `git -C #{@dir.shellescape} rev-parse HEAD`.strip
    parsed = Adapters::RuanyfWeekly::Markdown.parse(@markdown)
    entry = Adapters::RuanyfWeekly.allocate.send(:entry, parsed[:sections].flat_map { |s| s[:items] }.first, parsed, 412, 1)
    @row = { "period" => "2026-W38", "issue_id" => "issue", "source_id" => "source", "source_adapter" => "ruanyf_weekly", "item_id" => "item", "rank" => 1,
      "title" => entry.title.to_s.strip[0, 300], "url" => entry.url.to_s.strip[0, 2048], "section" => entry.section&.strip&.slice(0, 100),
      "content" => SummaryCleaner.content(entry.content).tr("\n", " "), "summary" => SummaryCleaner.clean(entry.summary),
      "meta" => { "issue_no" => 412, "image_urls" => entry.meta[:image_urls] || [] } }
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "固定版本和只读快照一致时只生成可逆边界及摘要" do
    result = generate
    assert_equal 1, result.fetch(:entries).size
    assert_equal [ "第一段 😀。".bytesize ], result.fetch(:entries).first.fetch(:offsets)
    assert_equal result, generate
    refute_includes JSON.generate(result), @row.fetch("content")
    refute_includes JSON.generate(result), @row.fetch("item_id")
  end

  test "源摘要不一致、正文或图片变化、已有图片位置均不生成" do
    assert_raises(ArgumentError) { generate(sha: "0" * 64) }
    [ { "content" => "被修改" }, { "summary" => "不匹配" }, { "meta" => @row.fetch("meta").merge("image_urls" => [ "https://example.com/x" ]) },
      { "meta" => @row.fetch("meta").merge("image_positions" => nil) } ].each do |change|
      assert_empty generate(rows: [ @row.merge(change) ]).fetch(:entries)
    end
    assert_raises(ArgumentError) { generate(rows: [ @row, @row ]) }
  end

  private
    def generate(rows: [ @row ], sha: Digest::SHA256.hexdigest(@markdown))
      HistoricalWeeklyParagraphIndex.generate(repository: @dir, snapshot: { "period" => "2026-W38", "issue_no" => 412, "rows" => rows },
        source_commit: @commit, source_sha256: sha, reviewed_ranks: [ 1 ])
    end
end
