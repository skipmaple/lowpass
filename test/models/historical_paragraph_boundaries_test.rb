require "test_helper"
require "tmpdir"
require "digest"

class HistoricalParagraphBoundariesTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:weekly_w36)
    @source = sources(:ruanyf)
    @item = Item.new(id: Lowpass::Uuid.generate, issue: @issue, source: @source, rank: 2,
      title: "测试😀", url: "https://example.com/story", section: "文章",
      content: "甲😀乙 后 e\u0301字", meta: { "issue_no" => 412, "image_urls" => [ "https://example.com/a.webp" ] })
    @dir = Dir.mktmpdir("historical-paragraphs-")
    @offsets = [ "甲😀乙".bytesize, "甲😀乙 后".bytesize ]
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "严格匹配仅在副本恢复段落，UTF-8 与原文字节可逆" do
    index = index_with(@offsets)
    before = @item.attributes.deep_dup
    result = index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
    assert_equal "甲😀乙\n后\ne\u0301字", result
    assert_equal @item.content, result.tr("\n", " ")
    assert_equal before, @item.attributes
  end

  test "最终元数据只要有图片位置键，全部回退" do
    index = index_with(@offsets)
    [ nil, [], [ 0 ], "invalid" ].each do |value|
      assert_nil index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta.merge("image_positions" => value))
    end
  end

  test "身份、正文、图片及刊期变化全部回退" do
    index = index_with(@offsets)
    { "id" => Lowpass::Uuid.generate, "issue_id" => Lowpass::Uuid.generate, "source_id" => Lowpass::Uuid.generate,
      "rank" => 3, "title" => "不同标题", "url" => "https://example.com/other", "section" => "不同板块", "content" => "正文变化" }.each do |attr, value|
      original = @item.public_send(attr)
      @item.public_send("#{attr}=", value)
      assert_nil index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta), attr
      @item.public_send("#{attr}=", original)
    end
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/other.webp" ])
    assert_nil index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
    @issue.state = "generating"
    assert_nil index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
  end

  test "已有换行、连续空格、其他刊物或来源均回退" do
    [ "前\n后", "前  后" ].each do |content|
      @item.content = content
      index = index_with([ "前".bytesize ])
      assert_nil index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
    end
    @item.content = "甲😀乙 后 e\u0301字"
    index = index_with(@offsets)
    @issue.kind = "daily"
    assert_nil index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
    @issue.kind = "weekly"
    @source.adapter = "rss"
    assert_nil index.content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
  end

  test "异常偏移、段数、索引损坏和重复键全部回退" do
    [ [], [ 0 ], [ 1 ], [ @item.content.bytesize - 1 ], [ @offsets.first, @offsets.first ], @offsets.reverse,
      [ "7" ], [ 1.5 ], Array.new(64, @offsets.first) ].each do |offsets|
      assert_nil index_with(offsets).content_for(item: @item, issue: @issue, source: @source, meta: @item.meta), offsets.inspect
    end
    path = File.join(@dir, "bad.json")
    [ "{", '{"version":1,"version":1,"entries":[]}', JSON.generate(manifest(@offsets).merge(version: 2)) ].each do |text|
      File.write(path, text)
      assert_nil HistoricalParagraphBoundaries.new(paths: [ path ]).content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
    end
    data = manifest(@offsets)
    data[:entries] << data[:entries].first
    File.write(path, JSON.generate(data))
    assert_nil HistoricalParagraphBoundaries.new(paths: [ path ]).content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
    data[:entries].pop
    File.write(path, JSON.generate(data))
    second = File.join(@dir, "second.json")
    File.write(second, JSON.generate(data))
    assert_nil HistoricalParagraphBoundaries.new(paths: [ path, second ]).content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
    assert_nil HistoricalParagraphBoundaries.new(paths: [ File.join(@dir, "missing.json") ]).content_for(item: @item, issue: @issue, source: @source, meta: @item.meta)
  end

  private
    def index_with(offsets)
      path = File.join(@dir, "index.json")
      File.write(path, JSON.generate(manifest(offsets)))
      HistoricalParagraphBoundaries.new(paths: [ path ])
    end

    def manifest(offsets)
      number = @item.meta.fetch("issue_no")
      key = [ @issue.id, @source.id, number, @item.rank ]
      identity = [ @issue.period_key, @source.adapter, number, @issue.id, @source.id, @item.id, @item.rank, @item.title, @item.url,
        @item.section, Digest::SHA256.hexdigest(@item.content), Digest::SHA256.hexdigest(JSON.generate(@item.meta.fetch("image_urls"))) ]
      { version: 1, period: @issue.period_key, issue_no: number, source_commit: "a" * 40, source_sha256: "b" * 64,
        entries: [ { lookup_sha256: Digest::SHA256.hexdigest(JSON.generate(key)), rank: @item.rank,
          identity_sha256: Digest::SHA256.hexdigest(JSON.generate(identity)), offsets: offsets } ] }
    end
end
