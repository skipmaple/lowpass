require "test_helper"

class Item::TranslatingTest < ActiveSupport::TestCase
  setup { @item = items(:hn_one) }

  test "资格与理由和画像解耦但不扩大周刊中文隐藏范围" do
    InterestArea.update_all(enabled: false)
    @item.record_reason_abstention(assessed_at: Time.current)
    assert @item.needs_translation?
    assert_equal "title", @item.translation_field
    assert_equal [ @item.id ], Translations.targets(@item.issue).map { |target| target.fetch("item_id") }
    @item.update!(hidden: true)
    assert_not @item.needs_translation?
    @item.update!(hidden: false, title: "已有中文")
    assert_not @item.needs_translation?
    @item.update!(title: "English", issue: issues(:weekly_w36))
    assert_not @item.needs_translation?
  end

  test "简介只在有非中文原文的日刊Trending出现" do
    @item.update!(source: sources(:github), title: "octo/tool", summary: nil)
    assert_nil @item.translation_field
    @item.update!(summary: "A small tool")
    assert_equal "summary", @item.translation_field
    @item.update!(summary: "已有中文简介")
    assert_nil @item.translation_field
  end

  test "保留原文有终态且不touch任何内容，失败重评不删除旧结论" do
    target = @item.translation_target
    before = @item.attributes
    issue_before = @item.issue.attributes
    result = Translations::Parser::Result.new(decision: "unchanged", text: nil)
    assert @item.store_translation(result, target: target, assessed_at: Time.current)
    assert_equal before, @item.reload.attributes
    assert_equal issue_before, @item.issue.reload.attributes
    assert_not @item.needs_translation?
    assert @item.needs_translation?(reassess: true)
    assert_equal 1, TranslationPreservation.where(item: @item).count
    @item.update!(title: "A changed title")
    assert @item.needs_translation?
    assert_not @item.store_translation(result, target: target, assessed_at: Time.current)
    assert_equal 1, TranslationPreservation.where(item: @item).count
  end

  test "合规译文仅写对应字段并保留拒写判断和理由时间" do
    @item.record_reason_abstention(assessed_at: Time.current)
    target = @item.translation_target
    original = @item.attributes.except("title_zh", "updated_at")
    issue_before = @item.issue.attributes
    result = Translations::Parser::Result.new(decision: "translated", text: "一条中文标题")
    assert @item.store_translation(result, target: target, assessed_at: Time.current)
    assert_equal "一条中文标题", @item.reload.title_zh
    assert_equal original, @item.attributes.except("title_zh", "updated_at")
    assert_equal issue_before, @item.issue.reload.attributes
    assert @item.reason_abstention
    assert_not @item.needs_translation?
    assert_not @item.store_translation(result, target: target, assessed_at: Time.current)
  end

  test "保存前重新核对源配置而不接受旧目标" do
    target = @item.translation_target
    @item.source.update!(enabled: false)
    # 停用不改变已发布内容的资格；适配器身份改变才使原输出失效。
    assert @item.needs_translation?
    @item.source.update_columns(publication: "weekly")
    result = Translations::Parser::Result.new(decision: "translated", text: "不应写入")
    assert_not @item.store_translation(result, target: target, assessed_at: Time.current)
    assert_nil @item.reload.title_zh
  end
end
