require "test_helper"
require "digest"
require "json"

class HistoricalWeeklyReferenceLinksTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:weekly_w36)
    @source = sources(:ruanyf)
    @item = Item.new(id: Lowpass::Uuid.generate, issue: @issue, source: @source, rank: 2,
      title: "文章", url: "https://example.com/story", section: "文章",
      content: "查看代码。", meta: { "issue_no" => 415, "image_urls" => [ "https://example.com/a.webp" ] })
    identity = [ @issue.period_key, @source.adapter, 415, @issue.id, @source.id, @item.id, @item.rank, @item.title,
      @item.url, @item.section, Digest::SHA256.hexdigest(@item.content), Digest::SHA256.hexdigest(JSON.generate(@item.meta["image_urls"])) ]
    @index = HistoricalWeeklyReferenceLinks.new(entries: { Digest::SHA256.hexdigest(JSON.generate(identity)) => [ [ 0, 2, 4, "https://example.com/code" ] ] })
  end

  test "身份和正文完全匹配才提供链接，不更改原记录" do
    original = @item.attributes.deep_dup
    returned = @index.links_for(item: @item, issue: @issue, source: @source)
    assert_equal [ [ 0, 2, 4, "https://example.com/code" ] ], returned
    returned.first.last.replace("https://example.com/changed")
    assert_equal "https://example.com/code", @index.links_for(item: @item, issue: @issue, source: @source).first.last
    assert_equal original, @item.attributes
    @item.content = "查看正文。"
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
  end

  test "来源、图片或既有链接位置发生变化则回退" do
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/other.webp" ])
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/a.webp" ], "reference_links" => nil)
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
    @item.meta = @item.meta.except("reference_links")
    @issue.state = "generating"
    assert_nil @index.links_for(item: @item, issue: @issue, source: @source)
  end

  test "第 415 期索引的引用逐条对应固定原文，失配条目不入索引" do
    root = Rails.root.join("test/fixtures/files/ruanyf")
    source = root.join("issue-415-reference.md").read
    # 测试样本仅规范原文行尾空白；原始文件的哈希和来源见设计笔记。
    assert_equal "b8731938a386ba2a99bc150c7ae9e68ec0b4a7dbcc046d2f645ef4e0076c0abd", Digest::SHA256.hexdigest(source)
    items = Adapters::RuanyfWeekly::Markdown.parse(source)[:sections].flat_map { |section| section[:items] }
    evidence = JSON.parse(root.join("issue-415-reference-index.json").read)
    assert_equal 27, evidence.count { |row| row.fetch("matched") }
    assert_equal [ 6 ], evidence.reject { |row| row.fetch("matched") }.map { |row| row.fetch("rank") }
    assert_equal evidence.select { |row| row.fetch("matched") }.map { |row| row.fetch("fingerprint") }.sort,
      HistoricalWeeklyReferenceLinks::ENTRIES.keys.sort

    evidence.each do |row|
      body = items.fetch(row.fetch("rank") - 1).fetch(:summary)
      links = Adapters::RuanyfWeekly::ReferenceLinks.for(body: body, content: SummaryCleaner.content(body), issue_no: 415)
      assert links.present?, "第 #{row.fetch('rank')} 条应有可核对的原文链接"
      actual = HistoricalWeeklyReferenceLinks::ENTRIES[row.fetch("fingerprint")]
      if row.fetch("matched")
        assert_equal links, actual, "第 #{row.fetch('rank')} 条的引用位置或地址不一致"
      else
        assert_nil actual, "第 #{row.fetch('rank')} 条的已发布记录与原文不匹配"
      end
    end
  end
end
