require "test_helper"
require "tmpdir"
require "digest"

class HistoricalImagePositionsTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:weekly_w36)
    @source = sources(:ruanyf)
    @item = Item.new(id: Lowpass::Uuid.generate, issue: @issue, source: @source, rank: 26,
      title: "法国的公路路标", url: "https://example.com/story", section: "图片",
      content: "介绍。\n说明。", meta: { "issue_no" => 416, "image_urls" => [ "https://example.com/a.webp" ] })
    @dir = Dir.mktmpdir("historical-image-positions-")
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "完整匹配只返回位置，不修改条目、期或收藏" do
    index = index_with(@item, [ 1 ])
    original = @item.attributes.deep_dup
    assert_no_changes -> { [ Item.count, Issue.count, Favorite.count ] } do
      assert_equal [ 1 ], index.positions_for(item: @item, issue: @issue, source: @source)
    end
    assert_equal original, @item.attributes
  end

  test "身份、正文或图片序列变化均不复用旧索引" do
    index = index_with(@item, [ 1 ])
    changes = {
      "id" => Lowpass::Uuid.generate, "issue_id" => Lowpass::Uuid.generate,
      "source_id" => Lowpass::Uuid.generate, "rank" => 27, "title" => "另一标题",
      "url" => "https://example.com/other", "section" => "其他", "content" => "修改正文"
    }
    changes.each do |attribute, value|
      original = @item.public_send(attribute)
      @item.public_send("#{attribute}=", value)
      assert_nil index.positions_for(item: @item, issue: @issue, source: @source), attribute
      @item.public_send("#{attribute}=", original)
    end
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/b.webp" ])
    assert_nil index.positions_for(item: @item, issue: @issue, source: @source)
  end

  test "已有位置键无论值是否有效都不覆盖" do
    index = index_with(@item, [ 1 ])
    [ nil, [], [ 2 ], "invalid" ].each do |value|
      @item.meta = @item.meta.merge("image_positions" => value)
      assert_nil index.positions_for(item: @item, issue: @issue, source: @source), value.inspect
    end
  end

  test "非已发布周刊或非阮一峰来源不应用" do
    index = index_with(@item, [ 1 ])
    @issue.state = "generating"
    assert_nil index.positions_for(item: @item, issue: @issue, source: @source)
    @issue.state = "published"
    @issue.kind = "daily"
    assert_nil index.positions_for(item: @item, issue: @issue, source: @source)
    @issue.kind = "weekly"
    @source.adapter = "rss"
    assert_nil index.positions_for(item: @item, issue: @issue, source: @source)
  end

  test "图片 URL、位置、段落和 UTF-16 长度不可信时回退" do
    bad_urls = [ [], [ "javascript:alert(1)" ], [ "https://example.com:99999/a" ], [ "http://%00/x" ],
      [ "http://foo%2fbar/x" ], [ "http://256.1.1.1/x" ], [ "http://foo.123/x" ], [ "http://0x100000000/x" ], [ "http://1.2.3.0x100/x" ],
      [ "https://example.com/a", "https://example.com/a" ], Array.new(129) { |i| "https://example.com/#{i}" } ]
    bad_urls.each do |urls|
      @item.meta = @item.meta.merge("image_urls" => urls)
      assert_nil index_with(@item, Array.new(urls.size, 0)).positions_for(item: @item, issue: @issue, source: @source), urls.inspect
    end
    @item.meta = @item.meta.merge("image_urls" => [ "https://example.com/a.webp" ])
    [ [], [ -1 ], [ 3 ], [ 0.5 ], [ "1" ] ].each do |positions|
      assert_nil index_with(@item, positions).positions_for(item: @item, issue: @issue, source: @source), positions.inspect
    end
    [ "前\n\n后", "前\n", "😀" * 25_000 ].each do |content|
      @item.content = content
      assert_nil index_with(@item, [ 0 ]).positions_for(item: @item, issue: @issue, source: @source), content.first(10).inspect
    end
    @item.content = "😀" * 24_999
    assert_equal [ 0 ], index_with(@item, [ 0 ]).positions_for(item: @item, issue: @issue, source: @source)
  end

  test "索引缺失损坏未知版本与重复键均回退" do
    assert_nil HistoricalImagePositions.new(paths: [ File.join(@dir, "missing.json") ]).positions_for(item: @item, issue: @issue, source: @source)
    file = File.join(@dir, "index.json")
    [ "{", '{"version":1,"version":1,"entries":[]}', JSON.generate(manifest(@item, [ 1 ]).merge(version: 2)) ].each do |body|
      File.write(file, body)
      assert_nil HistoricalImagePositions.new(paths: [ file ]).positions_for(item: @item, issue: @issue, source: @source)
    end
    duplicate = manifest(@item, [ 1 ])
    duplicate[:entries] << duplicate[:entries].first
    File.write(file, JSON.generate(duplicate))
    assert_nil HistoricalImagePositions.new(paths: [ file ]).positions_for(item: @item, issue: @issue, source: @source)
    duplicate[:entries].pop
    File.write(file, JSON.generate(duplicate))
    second = File.join(@dir, "second.json")
    File.write(second, JSON.generate(duplicate))
    assert_nil HistoricalImagePositions.new(paths: [ file, second ]).positions_for(item: @item, issue: @issue, source: @source)
  end

  private
    def index_with(item, positions)
      file = File.join(@dir, "index.json")
      File.write(file, JSON.generate(manifest(item, positions)))
      HistoricalImagePositions.new(paths: [ file ])
    end

    def manifest(item, positions)
      images = item.meta["image_urls"]
      number = item.meta["issue_no"]
      key = [ @issue.id, @source.id, number, item.rank ]
      identity = [ @issue.period_key, @source.adapter, number, @issue.id, @source.id, item.id, item.rank, item.title, item.url,
        item.section, Digest::SHA256.hexdigest(item.content), Digest::SHA256.hexdigest(JSON.generate(images)) ]
      { version: 1, period: @issue.period_key, issue_no: number, source_commit: "a" * 40, source_sha256: "b" * 64,
        entries: [ { lookup_sha256: Digest::SHA256.hexdigest(JSON.generate(key)), rank: item.rank,
          identity_sha256: Digest::SHA256.hexdigest(JSON.generate(identity)), positions: positions } ] }
    end
end
