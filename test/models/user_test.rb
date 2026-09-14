require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "fixture 的角色" do
    assert users(:drew).admin?
    assert_not users(:guest).admin?
  end

  # R-5.5：任一已验证身份的邮箱在白名单里就是 admin；白名单由 ENV["ADMIN_EMAILS"] 给（test_helper 设了 drew@example.com）
  test "refresh_role! 按已验证身份的邮箱对白名单" do
    guest = users(:guest)
    guest.refresh_role!
    assert_equal "member", guest.role

    guest.auth_identities.create!(provider: "google", provider_uid: "g-guest", email: "Drew@Example.com", email_verified: true, linked_at: Time.current)
    guest.refresh_role!
    assert_equal "admin", guest.reload.role
  end

  test "未验证的邮箱在白名单里也不算" do
    user = users(:nomail)
    user.auth_identities.create!(provider: "google", provider_uid: "g-nomail", email: "drew@example.com", email_verified: false, linked_at: Time.current)
    user.refresh_role!
    assert_equal "member", user.role
  end

  test "白名单里的人被移出后下次刷新降回成员" do
    Identity::Whitelist.stubs(:emails).returns([])
    drew = users(:drew)
    drew.refresh_role!
    assert_equal "member", drew.reload.role
  end

  test "显示名长度与角色取值有校验" do
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(display_name: "x" * 101) }
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(display_name: "a", role: "root") }
  end
end
