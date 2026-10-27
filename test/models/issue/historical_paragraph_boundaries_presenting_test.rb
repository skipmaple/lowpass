require "test_helper"
require "tmpdir"
require "digest"

class Issue::HistoricalParagraphBoundariesPresentingTest < ActiveSupport::TestCase
  test "仅周刊页面副本恢复分段，最终图片位置覆盖时整条回退" do
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    item = items(:hn_one).dup
    item.update!(issue: issue, source: source, title: "旧刊", section: "文章", content: "第一段 第二段",
      meta: { issue_no: 412, image_urls: [ "https://cdn.example.com/cover.png" ] })
    hash = ->(value) { Digest::SHA256.hexdigest(JSON.generate(value)) }
    number = 412
    key = [ issue.id, source.id, number, item.rank ]
    identity = [ issue.period_key, source.adapter, number, issue.id, source.id, item.id, item.rank, item.title, item.url,
      item.section, Digest::SHA256.hexdigest(item.content), hash.call(item.meta["image_urls"]) ]
    manifest = { version: 1, period: issue.period_key, issue_no: number, source_commit: "a" * 40, source_sha256: "b" * 64,
      entries: [ { lookup_sha256: hash.call(key), rank: item.rank, identity_sha256: hash.call(identity), offsets: [ "第一段".bytesize ] } ] }
    Tempfile.create([ "paragraph-index", ".json" ]) do |file|
      file.write(JSON.generate(manifest))
      file.flush
      HistoricalParagraphBoundaries.stubs(:current).returns(HistoricalParagraphBoundaries.new(paths: [ file.path ]))
      ImageDimension.stubs(:enqueue_for)
      before = [ item.reload.attributes, issue.reload.attributes, Favorite.count ]
      props = -> { issue.weekly_section_props.flat_map { |section| section[:groups].flat_map { |group| group[:items] } }.find { |row| row[:id] == item.id } }
      assert_equal "第一段\n第二段", props.call[:content]
      positions = Object.new
      positions.define_singleton_method(:positions_for) { |item:, issue:, source:| item.id == key_item_id ? [ 1 ] : nil }
      positions.define_singleton_method(:key_item_id) { item.id }
      HistoricalImagePositions.stubs(:current).returns(positions)
      assert_equal "第一段 第二段", props.call[:content]
      assert_equal [ 1 ], props.call[:meta]["image_positions"]
      assert_equal before, [ item.reload.attributes, issue.reload.attributes, Favorite.count ]
    end
  end
end
