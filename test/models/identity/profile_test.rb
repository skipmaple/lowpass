require "test_helper"

# 三家 provider 的资料位置不一样，差异只在 Profile 里
class Identity::ProfileTest < ActiveSupport::TestCase
  test "Google：info.email 只在已验证时才有值，email_verified 是原始布尔" do
    profile = Identity::Profile.from(OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "g1",
      info: { name: "Drew Lee", email: "Drew@Example.com", email_verified: true, image: "https://lh3.example/a.png" }))

    assert_equal "google", profile.provider
    assert_equal "g1", profile.uid
    assert_equal "Drew Lee", profile.display_name
    assert_equal "https://lh3.example/a.png", profile.avatar_url
    assert_equal "drew@example.com", profile.email
    assert profile.email_verified?
  end

  test "Google 邮箱未验证时 info.email 为空、视为无邮箱" do
    profile = Identity::Profile.from(OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "g2",
      info: { name: "X", email: nil, unverified_email: "x@y.io", email_verified: false }))

    assert_nil profile.email
    assert_not profile.email_verified?
  end

  # R-5.4：只认 /user/emails 里 primary && verified 的那条；info.email 与公开资料里的 email 不算数
  test "GitHub 取 primary 且 verified 的邮箱" do
    profile = Identity::Profile.from(OmniAuth::AuthHash.new(provider: "github", uid: "42",
      info: { nickname: "octo", name: nil, email: "public@x.io", image: "https://avatars.example/42" },
      extra: { all_emails: [ { "email" => "old@x.io", "primary" => false, "verified" => true }, { "email" => "Me@X.io", "primary" => true, "verified" => true } ] }))

    assert_equal "github", profile.provider
    assert_equal "me@x.io", profile.email
    assert profile.email_verified?
    assert_equal "octo", profile.display_name
  end

  test "GitHub 主邮箱未验证或列表为空都视为无邮箱" do
    unverified = Identity::Profile.from(OmniAuth::AuthHash.new(provider: "github", uid: "43", info: { nickname: "a", email: "a@x.io" },
      extra: { all_emails: [ { "email" => "a@x.io", "primary" => true, "verified" => false } ] }))
    hidden = Identity::Profile.from(OmniAuth::AuthHash.new(provider: "github", uid: "44", info: { nickname: "b", email: "b@x.io" }, extra: { all_emails: [] }))

    assert_nil unverified.email
    assert_not unverified.email_verified?
    assert_nil hidden.email
    assert_not hidden.email_verified?
  end

  test "developer 的邮箱视为已验证，名字空时退到邮箱前段" do
    profile = Identity::Profile.from(OmniAuth::AuthHash.new(provider: "developer", uid: "dev@x.io", info: { name: "", email: "dev@x.io" }))

    assert_equal "developer", profile.provider
    assert_equal "dev@x.io", profile.email
    assert profile.email_verified?
    assert_equal "dev", profile.display_name
    assert_nil profile.avatar_url
  end

  test "没有任何名字时叫读者" do
    profile = Identity::Profile.from(OmniAuth::AuthHash.new(provider: "github", uid: "45", info: {}, extra: { all_emails: [] }))

    assert_equal "读者", profile.display_name
  end

  test "不认识的策略名报错" do
    assert_raises(ArgumentError) { Identity::Profile.from(OmniAuth::AuthHash.new(provider: "twitter", uid: "1", info: {})) }
  end
end
