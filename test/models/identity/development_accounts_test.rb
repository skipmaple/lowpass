require "test_helper"

class Identity::DevelopmentAccountsTest < ActiveSupport::TestCase
  setup do
    @previous_admin_email = ENV["DEV_LOGIN_ADMIN_EMAIL"]
    @previous_whitelist = ENV["ADMIN_EMAILS"]
    ENV.delete("DEV_LOGIN_ADMIN_EMAIL")
    Rails.env.stubs(:development?).returns(true)
  end

  teardown do
    ENV["DEV_LOGIN_ADMIN_EMAIL"] = @previous_admin_email
    ENV["ADMIN_EMAILS"] = @previous_whitelist
  end

  test "默认用白名单的管理员及独立读者，不在浏览登录页时创建用户" do
    assert_no_difference [ -> { User.count }, -> { AuthIdentity.count }, -> { Session.count } ] do
      assert_equal [
        { role: "admin", name: "Drew Lee", email: "drew@example.com" },
        { role: "reader", name: "普通读者", email: "reader@lowpass.test" }
      ], Identity::DevelopmentAccounts.call
    end
  end

  test "指定管理员邮箱归一化后仍必须在白名单中" do
    ENV["ADMIN_EMAILS"] = "drew@example.com,admin@lowpass.test"
    ENV["DEV_LOGIN_ADMIN_EMAIL"] = " ADMIN@LOWPASS.TEST "

    assert_equal({ role: "admin", name: "开发管理员", email: "admin@lowpass.test" }, Identity::DevelopmentAccounts.call.first)

    ENV["DEV_LOGIN_ADMIN_EMAIL"] = "outsider@lowpass.test"
    assert_equal [ "reader" ], Identity::DevelopmentAccounts.call.pluck(:role)
  end

  test "没有白名单时只提供读者，读者邮箱在白名单时不假称普通读者" do
    ENV.delete("ADMIN_EMAILS")
    assert_equal [ "reader" ], Identity::DevelopmentAccounts.call.pluck(:role)

    ENV["ADMIN_EMAILS"] = "reader@lowpass.test"
    assert_equal [ "admin" ], Identity::DevelopmentAccounts.call.pluck(:role)
  end

  test "已有开发身份沿用其名字，优先级与实际登录一致" do
    users(:guest).auth_identities.create!(provider: "developer", provider_uid: "drew@example.com",
      email: "drew@example.com", email_verified: true, linked_at: Time.current)

    assert_equal "客人", Identity::DevelopmentAccounts.call.first.fetch(:name)
  end

  test "不会把未验证邮箱用户的名字带到新登录身份" do
    users(:guest).update!(email: "reader@lowpass.test")
    auth_identities(:guest_github).update!(email: "reader@lowpass.test", email_verified: false)

    assert_equal "普通读者", Identity::DevelopmentAccounts.call.last.fetch(:name)
  end

  test "读者账号若已关联管理员身份，不提供误标为普通读者的入口" do
    users(:drew).auth_identities.create!(provider: "developer", provider_uid: "reader@lowpass.test",
      email: "reader@lowpass.test", email_verified: true, linked_at: Time.current)

    assert_equal [ "admin" ], Identity::DevelopmentAccounts.call.pluck(:role)
  end

  test "开发环境之外不提供快捷账号" do
    Rails.env.stubs(:development?).returns(false)

    assert_empty Identity::DevelopmentAccounts.call
  end
end
