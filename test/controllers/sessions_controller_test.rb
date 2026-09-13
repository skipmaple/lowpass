require "test_helper"

# PRD 5.5 的登录流程：AC-5.1 到 AC-5.7，加取消、限流、登出
class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "AC-5.5 未登录访问受保护页跳登录页并带 next；登录后回到该页" do
    get daily_issue_path("2026-09-08")
    assert_redirected_to login_path(next: "/daily/2026-09-08")

    sign_in_as(users(:drew), next_path: "/daily/2026-09-08")
    assert_redirected_to daily_issue_path("2026-09-08")
    follow_redirect!
    assert_response :success
    assert_equal "Daily/Show", page_component
    assert_equal({ "display_name" => "Drew Lee", "avatar_url" => "https://avatars.example/drew.png", "email" => "drew@example.com", "admin" => true }, page_props["current_user"])
  end

  test "非 GET 请求撞登录墙只回登录页、不带 next" do
    post search_clicks_path, params: { item_id: "x", rank: 1, q: "x" }, as: :json

    assert_redirected_to login_path
  end

  test "登录页：未登录渲染 Login/Show，带 providers 与校验过的 next" do
    get login_path(next: "/weekly")

    assert_response :success
    assert_equal "Login/Show", page_component
    assert_equal %w[google_oauth2 github], page_props["providers"]
    assert_equal "/weekly", page_props["next"]
    assert_nil page_props["current_user"]
  end

  test "登录页的 next 是站外地址时当没有" do
    get login_path(next: "https://evil.example/")
    assert_nil page_props["next"]

    get login_path(next: "//evil.example")
    assert_nil page_props["next"]

    # 控制字符也不算站内地址：/\t//evil.example 过得了「单个 / 开头」这一关，却会让 redirect_to 抛异常
    get login_path(next: "/\t//evil.example")
    assert_nil page_props["next"]
  end

  test "已登录访问登录页跳首页" do
    sign_in_as(users(:drew))

    get login_path
    assert_redirected_to root_path
  end

  test "AC-5.1 新用户用 Google 登录：建用户、建会话、进首页" do
    mock_omniauth(:google_oauth2, OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "g-fresh",
      info: { name: "Fresh", email: "fresh@x.io", email_verified: true, image: nil }))

    assert_difference [ -> { User.count }, -> { Session.count } ], 1 do
      post "/auth/google_oauth2"
      follow_redirect!
    end

    assert_redirected_to root_path
    assert cookies[:session_token].present?
    user = User.find_by!(email: "fresh@x.io")
    assert_equal "member", user.role
    assert_equal user, Session.sole.user
  end

  test "AC-5.7 next 参数为站外地址时忽略、跳首页" do
    sign_in_as(users(:drew), next_path: "https://evil.example/")
    assert_redirected_to root_path

    sign_in_as(users(:drew), next_path: "//evil.example")
    assert_redirected_to root_path

    sign_in_as(users(:drew), next_path: "/\\evil.example")
    assert_redirected_to root_path
  end

  test "AC-5.3 GitHub 邮箱不可见：新建独立用户、跳设置页并提示无法合并" do
    mock_omniauth(:github, OmniAuth::AuthHash.new(provider: "github", uid: "gh-hidden", info: { nickname: "hidden", email: nil }, extra: { all_emails: [] }))

    assert_difference -> { User.count }, 1 do
      post "/auth/github", params: { origin: "/weekly" }
      follow_redirect!
    end

    assert_redirected_to settings_path
    assert_equal "这个邮箱无法自动合并。如果你之前用其他方式登录过，请改用原方式。", flash[:alert]
    assert cookies[:session_token].present?
  end

  test "AC-5.2 已验证邮箱一致：GitHub 身份并进 Google 用户，不新建" do
    mock_omniauth(:github, OmniAuth::AuthHash.new(provider: "github", uid: "gh-drew", info: { nickname: "drew", email: "drew@example.com" },
      extra: { all_emails: [ { "email" => "drew@example.com", "primary" => true, "verified" => true } ] }))

    assert_no_difference -> { User.count } do
      post "/auth/github"
      follow_redirect!
    end

    assert_redirected_to root_path
    assert_equal users(:drew), Session.sole.user
    assert_equal 2, users(:drew).auth_identities.count
  end

  test "AC-5.6 state 不匹配：不建会话，显示登录失败" do
    mock_omniauth(:google_oauth2, :csrf_detected)

    post "/auth/google_oauth2"
    follow_redirect!

    assert_redirected_to login_path
    assert_equal 0, Session.count
    assert_nil cookies[:session_token].presence
    follow_redirect!
    assert_equal "Login/Show", page_component
    assert_equal({ "alert" => "登录失败，请重试。" }, page_props["flash"])
  end

  test "用户取消授权：已取消登录" do
    mock_omniauth(:github, :access_denied)

    post "/auth/github"
    follow_redirect!
    follow_redirect!

    assert_equal({ "alert" => "已取消登录。" }, page_props["flash"])
    assert_equal 0, Session.count
  end

  test "没挂载的 provider 的回调当登录失败，不建会话" do
    get "/auth/nope/callback"

    assert_redirected_to login_path
    assert_equal 0, Session.count
    follow_redirect!
    assert_equal({ "alert" => "登录失败，请重试。" }, page_props["flash"])
  end

  test "R-5.9 同一 IP 一分钟内第 11 次回调被挡在 OmniAuth 之前" do
    mock_omniauth(:github, :invalid_credentials)
    10.times do
      get "/auth/github/callback"
      assert_redirected_to login_path
    end

    get "/auth/github/callback"

    assert_redirected_to "/login"
    follow_redirect!
    assert_equal({ "alert" => "操作过于频繁，请稍后再试。" }, page_props["flash"])
  end

  # OmniAuth 比对回调路径前先把结尾的 / 去掉、再 downcase（strategy.rb 的 current_path），
  # 这两种变形都照样走完换 token 那一步：限流的正则认不出来就等于加一个 / 或换个大小写就绕过去了
  test "R-5.9 回调带尾斜杠一样计数" do
    mock_omniauth(:github, :invalid_credentials)
    10.times do
      get "/auth/github/callback/"
      assert_redirected_to login_path
    end

    get "/auth/github/callback/"

    assert_redirected_to "/login"
    follow_redirect!
    assert_equal({ "alert" => "操作过于频繁，请稍后再试。" }, page_props["flash"])
  end

  test "R-5.9 回调大小写变形一样计数" do
    mock_omniauth(:github, :invalid_credentials)
    10.times do
      get "/auth/github/Callback"
      assert_redirected_to login_path
    end

    get "/auth/github/Callback"

    assert_redirected_to "/login"
    follow_redirect!
    assert_equal({ "alert" => "操作过于频繁，请稍后再试。" }, page_props["flash"])
  end

  # D11：cookie 里只有签名过的 token，浏览器读不到、跨站带不出去，最长活到 90 天的硬上限
  test "会话 cookie 的属性：HttpOnly、SameSite=Lax、到期日是硬上限" do
    sign_in_as(users(:drew))

    set_cookie = Array(response.headers["set-cookie"]).join("\n")
    assert_match(/session_token=/, set_cookie)
    assert_match(/httponly/i, set_cookie)
    assert_match(/samesite=lax/i, set_cookie)
    assert_match(/expires=#{Regexp.escape(Session.sole.expires_at.httpdate)}/i, set_cookie)
  end

  test "登出：删会话、清 cookie、再访问受保护页跳登录" do
    sign_in_as(users(:drew))
    assert_equal 1, Session.count

    delete session_path

    assert_redirected_to login_path
    assert_equal 0, Session.count
    get root_path
    assert_redirected_to login_path(next: "/")
  end

  test "过期的会话 cookie 当未登录" do
    sign_in_as(users(:drew))
    Session.sole.update_column(:last_seen_at, 31.days.ago)

    get daily_issue_path("2026-09-08")

    assert_redirected_to login_path(next: "/daily/2026-09-08")
  end

  test "每次访问续期，但一小时内不写库" do
    sign_in_as(users(:drew))
    session = Session.sole
    session.update_column(:last_seen_at, 2.hours.ago)

    get daily_issue_path("2026-09-08")

    assert_in_delta Time.current, session.reload.last_seen_at, 5
  end

  test "/up 不要登录" do
    get "/up"
    assert_response :success
  end
end
