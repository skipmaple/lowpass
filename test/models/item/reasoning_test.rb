require "test_helper"

class Item::ReasoningTest < ActiveSupport::TestCase
  setup { @item = items(:hn_one) }

  test "新旧条目拒写只更新判断记录而不改任一历史字段" do
    [ {}, { reason: "旧理由", interest_tag: "前端开发", title_zh: "旧标题译文", summary_zh: "旧说明译文", reason_generated_at: 2.days.ago } ].each do |fields|
      @item.update!(fields)
      before_item, before_issue = @item.attributes, @item.issue.attributes
      marker = @item.record_reason_abstention(assessed_at: Time.current)
      assert_equal @item.id, marker.item_id
      assert_equal before_item, @item.reload.attributes
      assert_equal before_issue, @item.issue.reload.attributes
    end
    assert_equal 1, ReasonAbstention.where(item_id: @item.id).count
  end

  test "重复拒写刷新唯一记录即使关联先前缓存为空" do
    other = Item.find(@item.id)
    assert_nil other.reason_abstention
    first = @item.record_reason_abstention(assessed_at: 1.hour.ago)
    second = other.record_reason_abstention(assessed_at: Time.current)
    assert_equal first.id, second.id
    assert_equal second.assessed_at, ReasonAbstention.find(first.id).assessed_at
  end

  test "成功保存与删除判断在同一事务且失败保留旧内容" do
    marker = @item.record_reason_abstention(assessed_at: Time.current)
    before = @item.reload.attributes
    relation = ReasonAbstention.where(item_id: @item.id)
    ReasonAbstention.stubs(:where).with(item_id: @item.id).returns(relation)
    relation.stubs(:delete_all).raises(ActiveRecord::StatementInvalid, "storage failure")
    assert_raises(ActiveRecord::StatementInvalid) { @item.store_generated_reason(generated, generated_at: Time.current) }
    assert_equal before, @item.reload.attributes
    assert ReasonAbstention.exists?(marker.id)
  end

  test "成功清除缓存过的判断且仅写本条需要的合规译文" do
    @item.update!(summary_zh: "旧说明译文")
    @item.record_reason_abstention(assessed_at: Time.current)
    assert @item.reason_abstention
    stamp = Time.current.change(usec: 0)
    assert_nil @item.store_generated_reason(generated, generated_at: stamp)
    @item.reload
    assert_equal generated.reason, @item.reason
    assert_equal "标题译文", @item.title_zh
    assert_equal "旧说明译文", @item.summary_zh
    assert_equal stamp, @item.reason_generated_at
    assert_nil @item.reason_abstention
    assert_not ReasonAbstention.exists?(item_id: @item.id)
  end

  test "先后完成的合法结果生效且旧实例不决定判断是否存在" do
    stale = Item.find(@item.id)
    assert_nil stale.reason_abstention
    @item.record_reason_abstention(assessed_at: Time.current)
    stale.store_generated_reason(generated, generated_at: Time.current)
    assert_not ReasonAbstention.exists?(item_id: @item.id)
    stale.record_reason_abstention(assessed_at: Time.current)
    assert ReasonAbstention.exists?(item_id: @item.id)
    assert_equal generated.reason, @item.reload.reason
  end

  private
    def generated
      Reasons::Parser::Result.new(decision: "generated", reason: "前端开发可考察这个终端工具的调试流程与使用边界。", interest_tag: "前端开发", title_zh: "标题译文", summary_zh: "本条不需要的说明译文")
    end
end
