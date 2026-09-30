require "test_helper"

# 注销（R-5.11、AC-5.8、AC-5.10、D33）：DELETE /user 删掉当前用户，回登录页
class UsersControllerTest < ActionDispatch::IntegrationTest
  test "AC-5.8 注销：删掉用户、两个登录身份与全部会话，回登录页并提示；另一台设备下次访问跳登录页" do
    drew = users(:drew)
    drew.auth_identities.create!(provider: "github", provider_uid: "github-drew", email: "drew@example.com", email_verified: true, linked_at: Time.current)
    other_device = open_session { |device| device.extend(AuthenticationTestHelpers).sign_in_as(drew) }
    sign_in_as(drew)

    assert_no_difference [ "Issue.count", "Item.count" ] do
      delete user_path
    end

    assert_redirected_to login_path
    follow_redirect!
    assert_equal "Login/Show", page_component
    assert_equal "已注销账号。", page_props.dig("flash", "notice")
    assert_not User.exists?(drew.id)
    assert_empty AuthIdentity.where(user_id: drew.id)
    assert_empty Session.where(user_id: drew.id)

    get settings_path
    assert_redirected_to login_path(next: "/settings")
    other_device.get settings_path
    other_device.assert_redirected_to login_path(next: "/settings")
  end

  test "AC-5.10 注销后用同一个 Google 账号再登录：建新用户，白名单不变仍是管理员（D33）" do
    drew = users(:drew)
    auth = identity_auth(auth_identities(:drew_google))
    sign_in_as(drew)
    delete user_path

    mock_omniauth(:google_oauth2, auth)
    assert_difference -> { User.count }, 1 do
      post "/auth/google_oauth2"
      follow_redirect!
    end

    fresh = User.find_by!(email: "drew@example.com")
    assert_not_equal drew.id, fresh.id
    assert fresh.admin?
    get settings_path
    assert_equal %w[ google ], page_props["identities"].select { |identity| identity["linked_at_label"] }.map { |identity| identity["provider"] }
  end

  test "成员注销不影响别人" do
    sign_in_as(users(:guest))

    assert_difference -> { User.count }, -1 do
      delete user_path
    end

    assert User.exists?(users(:drew).id)
    assert users(:drew).auth_identities.exists?
  end

  test "未登录的 DELETE 只回登录页，什么都不删" do
    assert_no_difference [ "User.count", "AuthIdentity.count" ] do
      delete user_path
    end

    assert_redirected_to login_path
  end
end
