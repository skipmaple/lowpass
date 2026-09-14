require "test_helper"

# R-3.3 测试抓取是 JSON 端点：表单不离开，预览在客户端画
class Admin::Sources::TestFetchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:drew))
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "https://hackaday.com/feed/").to_return(body: file_fixture("rss/hackaday.xml").read)
  end

  test "成功回预览" do
    # 样本最新一条发布于 9月9日 15:30 UTC：时间要落在 window_hours 的窗口里，不然 7 条全被窗口滤掉
    travel_to Time.utc(2026, 9, 9, 16) do
      post admin_test_fetches_path, params: { adapter: "rss", publication: "daily", name: "Hackaday", config: { feed_url: "https://hackaday.com/feed/", count: "10", window_hours: "24" } }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert body["ok"]
    assert_equal 5, body["entries"].size
    assert_equal "Hackaday", body["feed_title"]
  end

  test "失败回可读的一句，仍是 200" do
    stub_request(:get, "https://hackaday.com/feed/").to_return(body: "<html></html>")

    post admin_test_fetches_path, params: { id: sources(:hackaday).id, adapter: "rss", publication: "daily", name: "Hackaday", config: { feed_url: "https://hackaday.com/feed/" } }, as: :json

    assert_response :success
    assert_equal "不是有效的 RSS/Atom，请检查地址。", response.parsed_body["error"]
    assert_equal "test", sources(:hackaday).fetch_runs.sole.trigger
  end

  # 适配器不在白名单里时不能去 constantize 它（nil / "foo" / "base" 分别是 NoMethodError、
  # NameError、ScriptError）：跟别的校验失败一样，200 加一句话
  test "适配器不合法也是 200 加一句失败" do
    post admin_test_fetches_path, params: { adapter: "foo", publication: "daily", name: "x", config: { feed_url: "https://hackaday.com/feed/" } }, as: :json

    assert_response :success
    assert_equal false, response.parsed_body["ok"]
    assert_equal "配置不完整：适配器无效", response.parsed_body["error"]
  end

  test "每用户每分钟 10 次" do
    10.times { post admin_test_fetches_path, params: { adapter: "rss", publication: "daily", config: { feed_url: "https://hackaday.com/feed/" } }, as: :json }
    post admin_test_fetches_path, params: { adapter: "rss", publication: "daily", config: { feed_url: "https://hackaday.com/feed/" } }, as: :json

    assert_response :too_many_requests
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    post admin_test_fetches_path, params: { adapter: "rss", publication: "daily", config: { feed_url: "https://hackaday.com/feed/" } }, as: :json
    assert_response :forbidden
  end

  # 限流按用户计数（by: Current.user.id）：登录墙必须排在限流前面，不然未登录的请求先撞上 nil.id
  test "未登录先去登录" do
    delete session_path
    post admin_test_fetches_path, params: { adapter: "rss", publication: "daily", config: { feed_url: "https://hackaday.com/feed/" } }, as: :json
    assert_redirected_to login_path
  end
end
