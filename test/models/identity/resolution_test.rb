require "test_helper"

# R-5.1 到 R-5.5：找人、合并、新建、刷新角色（设计 4.5）。四种结果各有一条，邮箱合并三种情形（AC-5.2、AC-5.3）都在
class Identity::ResolutionTest < ActiveSupport::TestCase
  def google(uid:, email:, verified: true, name: "Someone", image: nil)
    OmniAuth::AuthHash.new(provider: "google_oauth2", uid: uid, info: { name: name, email: verified ? email : nil, email_verified: verified, image: image })
  end

  def github(uid:, email:, verified: true, name: "Someone")
    emails = email ? [ { "email" => email, "primary" => true, "verified" => verified } ] : []
    OmniAuth::AuthHash.new(provider: "github", uid: uid, info: { nickname: name, name: name, email: email }, extra: { all_emails: emails })
  end

  test "再次登录：按 (provider, uid) 找到人，更新显示名与头像与邮箱" do
    result = Identity::Resolution.call(google(uid: "google-drew", email: "drew@example.com", name: "Drew L.", image: "https://lh3.example/new.png"))

    assert_equal :signed_in, result.outcome
    assert_equal users(:drew), result.user
    assert_equal "Drew L.", result.user.display_name
    assert_equal "https://lh3.example/new.png", result.user.avatar_url
    assert_in_delta Time.current, result.user.last_login_at, 5
    assert_equal 1, result.user.auth_identities.count
  end

  test "AC-5.2 已验证邮箱一致：新身份挂到现有用户" do
    result = Identity::Resolution.call(github(uid: "gh-drew", email: "Drew@example.com"))

    assert_equal :linked, result.outcome
    assert_equal users(:drew), result.user
    assert_equal %w[github google], result.user.auth_identities.order(:provider).pluck(:provider)
    assert result.user.auth_identities.find_by(provider: "github").email_verified
  end

  test "已验证邮箱但没人有：普通首次登录，不提示" do
    assert_difference -> { User.count }, 1 do
      result = Identity::Resolution.call(google(uid: "g-new", email: "new@x.io", name: "New"))

      assert_equal :created, result.outcome
      assert_equal "New", result.user.display_name
      assert_equal "new@x.io", result.user.email
      assert_equal "member", result.user.role
    end
  end

  test "AC-5.3 邮箱未验证：新建独立用户并标记无法合并，不并进同邮箱的人" do
    assert_difference -> { User.count }, 1 do
      result = Identity::Resolution.call(github(uid: "gh-x", email: "drew@example.com", verified: false))

      assert_equal :unmergeable, result.outcome
      assert_not_equal users(:drew), result.user
      assert_nil result.user.email
      assert_equal "member", result.user.role
    end
  end

  test "AC-5.3 邮箱缺失：同样新建并标记无法合并" do
    result = Identity::Resolution.call(github(uid: "gh-y", email: nil))

    assert_equal :unmergeable, result.outcome
    assert_nil result.user.email
    assert_not result.user.auth_identities.sole.email_verified
  end

  # 设计 L7：只跟已验证的身份邮箱比。先有人用未验证的 a@x 建了账号，真正的 a@x 用 Google 登录不能被并进去
  test "只跟已验证的身份邮箱合并" do
    squatter = Identity::Resolution.call(github(uid: "gh-squat", email: "victim@x.io", verified: false)).user
    victim = Identity::Resolution.call(google(uid: "g-victim", email: "victim@x.io")).user

    assert_not_equal squatter, victim
  end

  test "AC-5.4 白名单邮箱登录即成 admin；下次不在白名单就降回成员" do
    user = Identity::Resolution.call(github(uid: "gh-admin", email: "DREW@example.com")).user
    assert user.admin?

    Identity::Whitelist.stubs(:emails).returns([])
    assert_not Identity::Resolution.call(github(uid: "gh-admin", email: "drew@example.com")).user.admin?
  end

  test "整个过程在一个事务里：新建用户失败不留身份" do
    User.any_instance.stubs(:refresh_role!).raises(ActiveRecord::RecordInvalid)

    assert_raises(ActiveRecord::RecordInvalid) { Identity::Resolution.call(google(uid: "g-boom", email: "boom@x.io")) }
    assert_nil AuthIdentity.find_by(provider_uid: "g-boom")
  end
end
