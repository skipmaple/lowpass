require "test_helper"

class ReasonAbstentionTest < ActiveSupport::TestCase
  test "判断记录独立计时且不触碰条目或刊期" do
    item = items(:hn_one)
    before_item, before_issue = item.attributes, item.issue.attributes
    marker = ReasonAbstention.create!(item: item, assessed_at: Time.current)

    assert_match(/\A[0-9a-z]{25}\z/, marker.id)
    assert_equal before_item, item.reload.attributes
    assert_equal before_issue, item.issue.reload.attributes
    assert_not ReasonAbstention.new.valid?
  end

  test "数据库禁止重复和孤儿判断" do
    marker = ReasonAbstention.create!(item: items(:hn_one), assessed_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ReasonAbstention.transaction(requires_new: true) { marker.dup.save!(validate: false) }
    end
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ReasonAbstention.transaction(requires_new: true) do
        ReasonAbstention.new(item_id: Lowpass::Uuid.generate, assessed_at: Time.current).save!(validate: false)
      end
    end
    assert_raises(ActiveRecord::NotNullViolation) do
      ReasonAbstention.transaction(requires_new: true) { marker.update_column(:assessed_at, nil) }
    end
  end

  test "待处理范围排除合法拒写隐藏周刊与已有理由" do
    pending = items(:hn_one)
    declined = copy_item("declined")
    ReasonAbstention.create!(item: declined, assessed_at: Time.current)
    hidden = copy_item("hidden", hidden: true)
    ReasonAbstention.create!(item: hidden, assessed_at: Time.current)
    copy_item("weekly", issue: issues(:weekly_w36), source: sources(:ruanyf))
    written = copy_item("written", reason: "历史推荐理由")
    retained = copy_item("retained", reason: "保留历史理由")
    ReasonAbstention.create!(item: retained, assessed_at: Time.current)

    assert_equal [ pending.id ], Item.pending_reasons.pluck(:id)
    assert_equal [ written.id ], Item.reusable_reasons.pluck(:id)
    hidden.update!(hidden: false)
    assert_not Item.pending_reasons.exists?(hidden.id)
    assert hidden.reason_abstention
  end

  test "清理九十天账本不删除拒写判断" do
    item = items(:hn_one)
    marker = ReasonAbstention.create!(item: item, assessed_at: 91.days.ago)
    call = ModelCall.create!(item: item, issue: item.issue, status: "abstained", created_at: 91.days.ago)
    assert_equal 9, call.status.length
    ModelCall.cleanup
    assert_not ModelCall.exists?(call.id)
    assert ReasonAbstention.exists?(marker.id)
  end

  test "直接删除重抓替换和删除刊期均由外键清理判断" do
    item = copy_item("delete")
    marker = ReasonAbstention.create!(item: item, assessed_at: Time.current)
    item.destroy!
    assert_not ReasonAbstention.exists?(marker.id)

    old = items(:hn_one)
    ReasonAbstention.create!(item: old, assessed_at: Time.current)
    old.issue.replace_section!(old.source, [ Adapters::Entry.new(title: "New item", url: "https://example.test/new", rank: 1) ])
    assert_not ReasonAbstention.exists?(item_id: old.id)
    replacement = old.issue.items.find_by!(source: old.source)
    assert_nil replacement.reason_abstention
    marker = ReasonAbstention.create!(item: replacement, assessed_at: Time.current)
    old.issue.destroy!
    assert_not ReasonAbstention.exists?(marker.id)
  end

  test "abstained 入账且数据库仍拒绝未知状态" do
    ModelCall.create!(item: items(:hn_one), status: "abstained")
    assert_raises(ActiveRecord::StatementInvalid) do
      ModelCall.transaction(requires_new: true) { ModelCall.last.update_column(:status, "unknown") }
    end
  end

  private
    def copy_item(key, **attributes)
      item = items(:hn_one).dup
      item.assign_attributes(url: "https://example.test/#{key}", url_hash: Digest::SHA256.hexdigest(key), **attributes)
      item.save!
      item
    end
end
