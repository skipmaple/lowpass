require "test_helper"

# R-5.6 / D11：30 天滑动、90 天硬上限；last_seen_at 至多每小时写一次
class SessionTest < ActiveSupport::TestCase
  test "新会话带 24 位 token、到期日是 90 天后" do
    session = users(:drew).sessions.create!

    assert_equal 24, session.token.length
    assert_in_delta 90.days.from_now, session.expires_at, 5
    assert_in_delta Time.current, session.last_seen_at, 5
    assert_includes Session.active, session
  end

  test "30 天没来就不再有效" do
    session = users(:drew).sessions.create!
    session.update_column(:last_seen_at, 31.days.ago)

    assert_not_includes Session.active, session
  end

  test "过了硬上限即使天天来也失效" do
    session = users(:drew).sessions.create!
    session.update_columns(expires_at: 1.minute.ago, last_seen_at: Time.current)

    assert_not_includes Session.active, session
  end

  test "touch_last_seen! 一小时内不写库，过了才写" do
    session = users(:drew).sessions.create!
    session.update_column(:last_seen_at, 30.minutes.ago)

    assert_no_changes -> { session.reload.last_seen_at } do
      session.touch_last_seen!
    end

    session.update_column(:last_seen_at, 2.hours.ago)
    session.touch_last_seen!
    assert_in_delta Time.current, session.reload.last_seen_at, 5
  end

  test "cleanup 删掉过期与久未访问的会话" do
    live = users(:drew).sessions.create!
    idle = users(:drew).sessions.create!.tap { |s| s.update_column(:last_seen_at, 31.days.ago) }
    expired = users(:guest).sessions.create!.tap { |s| s.update_column(:expires_at, 1.day.ago) }

    Session.cleanup

    assert Session.exists?(live.id)
    assert_not Session.exists?(idle.id)
    assert_not Session.exists?(expired.id)
  end

  test "用户删了会话跟着没" do
    user = User.create!(display_name: "临时")
    user.sessions.create!
    user.destroy!

    assert_equal 0, Session.where(user_id: user.id).count
  end
end
