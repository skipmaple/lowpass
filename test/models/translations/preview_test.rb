require "test_helper"

class Translations::PreviewTest < ActiveSupport::TestCase
  test "冻结目标和操作且绑定管理员期选项与十五分钟有效期" do
    issue = issues(:daily_0908)
    user = users(:drew)
    preview = Translations::Preview.issue(issue, user: user, reassess: false)
    payload = Translations::Preview.verify(preview.fetch(:token), issue: issue, user: user)
    assert_equal [ items(:hn_one).translation_target ], payload.fetch("targets")
    assert_equal false, payload.fetch("reassess")
    assert ModelRequests.valid_operation?(payload.fetch("operation"))
    items(:hn_one).update!(title: "Changed original")
    assert_equal payload, Translations::Preview.verify(preview.fetch(:token), issue: issue, user: user)
    assert_raises(Translations::Preview::Invalid) { Translations::Preview.verify(preview.fetch(:token) + "tampered", issue: issue, user: user) }
    assert_raises(Translations::Preview::Invalid) { Translations::Preview.verify(preview.fetch(:token), issue: issue, user: users(:guest)) }
    assert_raises(Translations::Preview::Invalid) { Translations::Preview.verify(preview.fetch(:token), issue: issues(:weekly_w36), user: user) }
    travel 16.minutes do
      assert_raises(Translations::Preview::Invalid) { Translations::Preview.verify(preview.fetch(:token), issue: issue, user: user) }
    end
    assert_equal 0, ModelCall.count
    assert_equal 0, AuditLog.count
  end

  test "重新评估选项冻结且不覆盖已有译文" do
    item = items(:hn_one)
    item.store_translation(Translations::Parser::Result.new(decision: "unchanged", text: nil), target: item.translation_target, assessed_at: Time.current)
    assert_equal 0, Translations::Preview.issue(item.issue, user: users(:drew), reassess: false).fetch(:target_count)
    assert_equal 1, Translations::Preview.issue(item.issue, user: users(:drew), reassess: true).fetch(:target_count)
    item.update!(title_zh: "已有译文")
    assert_equal 0, Translations::Preview.issue(item.issue, user: users(:drew), reassess: true).fetch(:target_count)
  end
end
