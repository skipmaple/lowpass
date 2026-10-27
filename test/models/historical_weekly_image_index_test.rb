require "test_helper"
require "digest"
require "tmpdir"
require "open3"

class HistoricalWeeklyImageIndexTest < ActiveSupport::TestCase
  SOURCE = <<~MARKDOWN
    # 科技爱好者周刊（第 416 期）：测试

    ## 图片

    1、[测试](https://example.com/story)

    介绍。

    ![图](https://example.com/a.png)

    说明。
  MARKDOWN

  setup do
    @repo = Dir.mktmpdir("weekly-source-git-")
    FileUtils.mkdir_p(File.join(@repo, "docs"))
    File.write(File.join(@repo, "docs", "issue-416.md"), SOURCE)
    system("git", "-C", @repo, "init", "-q", exception: true)
    system("git", "-C", @repo, "add", "docs/issue-416.md", exception: true)
    system("git", "-C", @repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "fixture", exception: true)
    @commit, status = Open3.capture2("git", "-C", @repo, "rev-parse", "HEAD")
    raise "fixture commit unavailable" unless status.success?
    @commit.strip!
    parsed = Adapters::RuanyfWeekly::Markdown.parse(SOURCE)
    entry = Adapters::RuanyfWeekly.allocate.send(:entry, parsed[:sections].first[:items].first, parsed, 416, 1)
    urls = entry.meta.fetch(:image_urls)
    @row = { "issue_id" => "issue-secret", "source_id" => "source-secret", "item_id" => "item-secret",
      "rank" => 1, "title" => entry.title.to_s.strip[0, 300], "url" => entry.url.to_s.strip[0, 2048],
      "section" => entry.section&.strip&.slice(0, 100), "content_sha256" => Digest::SHA256.hexdigest(SummaryCleaner.content(entry.content).to_s),
      "images_sha256" => Digest::SHA256.hexdigest(JSON.generate(urls)), "image_count" => urls.size, "positions_present" => false }
    @snapshot = { "period" => "2026-W43", "issue_no" => 416, "rows" => [ @row ] }
    @sha = Digest::SHA256.hexdigest(SOURCE)
  end

  teardown { FileUtils.remove_entry(@repo) }

  test "固定原文与快照匹配时可重复生成且输出不泄露快照" do
    result = generate
    assert_equal result, generate
    assert_equal 1, result.fetch(:entries).size
    assert_equal [ 1 ], result.fetch(:entries).first.fetch(:positions)
    json = JSON.generate(result)
    [ "issue-secret", "source-secret", "item-secret", "https://example.com", "介绍" ].each { |secret| assert_not_includes json, secret }
  end

  test "来源摘要错误拒绝执行，内容或图片变化跳过" do
    assert_raises(ArgumentError) { generate(source_sha256: "0" * 64) }
    assert_raises(ArgumentError) { generate(source_commit: "a" * 40) }
    tree, status = Open3.capture2("git", "-C", @repo, "rev-parse", "HEAD^{tree}")
    assert status.success?
    assert_raises(ArgumentError) { generate(source_commit: tree.strip) }
    %w[content_sha256 images_sha256 title].each do |field|
      original = @row[field]
      @row[field] = "changed"
      assert_empty generate.fetch(:entries)
      @row[field] = original
    end
  end

  test "快照中重复条目或已有位置不得生成" do
    @snapshot["rows"] << @row.dup
    assert_empty generate.fetch(:entries)
    @snapshot["rows"].pop
    @row["positions_present"] = true
    assert_empty generate.fetch(:entries)
  end

  private
    def generate(source_sha256: @sha, source_commit: @commit)
      HistoricalWeeklyImageIndex.generate(repository: @repo, snapshot: @snapshot, source_commit: source_commit, source_sha256: source_sha256)
    end
end
