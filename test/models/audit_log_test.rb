require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  test "Audit.record 记下操作者、动作、对象与内容" do
    Current.session = users(:drew).sessions.create!

    log = Audit.record("source.update", "Source##{sources(:hn).id}", { "name" => [ "HN", "Hacker News" ] })

    assert_equal users(:drew), log.user
    assert_equal "source.update", log.action
    assert_equal "Source##{sources(:hn).id}", log.target
    assert_equal({ "name" => [ "HN", "Hacker News" ] }, log.payload)
  ensure
    Current.reset
  end

  test "没有当前用户（console）也能记，操作者为空" do
    log = Audit.record("settings.update", "Setting#daily_time", { "daily_time" => [ "06:00", "06:30" ] })

    assert_nil log.user
  end

  test "审计写失败只报告，不抛出" do
    AuditLog.stubs(:create!).raises(ActiveRecord::StatementInvalid, "boom")

    assert_nil Audit.record("source.update", "Source#x")
  end

  test "cleanup 删 90 天前的记录" do
    old = AuditLog.create!(action: "a", target: "b", created_at: 91.days.ago)
    fresh = AuditLog.create!(action: "a", target: "b")

    AuditLog.cleanup

    assert_not AuditLog.exists?(old.id)
    assert AuditLog.exists?(fresh.id)
  end

  test "用户删了记录留着、操作者置空" do
    user = User.create!(display_name: "临时")
    log = AuditLog.create!(user: user, action: "a", target: "b")
    user.destroy!

    assert_nil log.reload.user_id
  end
end
