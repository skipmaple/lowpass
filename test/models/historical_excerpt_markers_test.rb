require "test_helper"
require "digest"
require "json"

class HistoricalExcerptMarkersTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:daily_0908)
    @item = items(:hn_one)
    @item.update!(summary: "The article continues")
    @identity = Digest::SHA256.hexdigest(JSON.generate([ @issue.period_key, @issue.id, @item.source_id, @item.id,
      @item.rank, @item.title, @item.url, @item.summary ]))
  end

  test "完整身份匹配时只在展示副本补回源站省略提示" do
    assert defined?(HistoricalExcerptMarkers), "展示规则尚不存在"
    markers = HistoricalExcerptMarkers.new(fingerprints: [ @identity ])
    assert_equal "The article continues …", markers.summary_for(item: @item, issue: @issue)
    assert_equal "The article continues", @item.reload.summary
  end

  test "身份或期刊状态变化时不追加" do
    assert defined?(HistoricalExcerptMarkers), "展示规则尚不存在"
    markers = HistoricalExcerptMarkers.new(fingerprints: [ @identity ])
    [ :title, :url, :rank, :source_id, :id, :summary ].each do |field|
      copy = @item.dup
      copy.id = @item.id
      copy.public_send("#{field}=", field == :rank ? 99 : "changed")
      assert_nil markers.summary_for(item: copy, issue: @issue), field
    end
    different_issue = @issue.dup
    different_issue.id = @issue.id
    different_issue.state = "generating"
    assert_nil markers.summary_for(item: @item, issue: different_issue)
    different_issue.state = "published"
    different_issue.period_key = "2026-09-09"
    assert_nil markers.summary_for(item: @item, issue: different_issue)
    different_issue.period_key = @issue.period_key
    different_issue.kind = "weekly"
    assert_nil markers.summary_for(item: @item, issue: different_issue)
    different_issue.kind = "daily"
    different_issue.id = "other-issue"
    assert_nil markers.summary_for(item: @item, issue: different_issue)
    @item.summary = ""
    assert_nil markers.summary_for(item: @item, issue: @issue)
    @item.summary = "\xFF".b.force_encoding(Encoding::UTF_8)
    assert_nil markers.summary_for(item: @item, issue: @issue)
    @item.summary = "The article continues"
    @item.title = "\xFF".b.force_encoding(Encoding::UTF_8)
    assert_nil markers.summary_for(item: @item, issue: @issue)
  end

  test "期刊页面只展示副本，不修改期、条目和搜索索引" do
    assert defined?(HistoricalExcerptMarkers), "展示规则尚不存在"
    markers = HistoricalExcerptMarkers.new(fingerprints: [ @identity ])
    before_item = @item.reload.attributes
    before_issue = @issue.reload.attributes
    before_search = Search::Record.where(item_id: @item.id).pluck(:id, :updated_at)
    HistoricalExcerptMarkers.expects(:current).at_least_once.returns(markers)
    row = @issue.items_by_source.fetch(@item.source_id).find { |entry| entry[:id] == @item.id }
    assert_equal "The article continues …", row[:summary]
    assert_equal before_item, @item.reload.attributes
    assert_equal before_issue, @issue.reload.attributes
    assert_equal before_search, Search::Record.where(item_id: @item.id).pluck(:id, :updated_at)
  end
end
