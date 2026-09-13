require "test_helper"

class Admin::SourcesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "/admin 落到信息源列表" do
    get "/admin"
    assert_redirected_to admin_sources_path
  end

  test "列表：全部源、适配器选项与汇总" do
    get admin_sources_path

    assert_response :success
    assert_equal "Admin/Sources/Index", page_component
    assert_equal [ "Hacker News", "GitHub Trending", "Hackaday", "阮一峰科技爱好者周刊" ], page_props["sources"].map { |s| s["name"] }
    assert_equal "正常", page_props["sources"].first["health_label"]
    assert_equal "4 个来源 · 3 个日刊 · 1 个周刊", page_props["summary"]
    assert_nil page_props["daily_time"]
  end

  test "新建页带适配器选项与空表单" do
    get new_admin_source_path

    assert_equal "Admin/Sources/Form", page_component
    assert_nil page_props.dig("source", "id")
    assert_equal "rss", page_props.dig("source", "adapter")
    assert_equal %w[ hacker_news github_trending rss ruanyf_weekly ], page_props["adapters"].map { |a| a["key"] }
    assert_equal({}, page_props["errors"])
  end

  test "新建：保存、审计、回列表" do
    assert_difference [ -> { Source.count }, -> { AuditLog.count } ], 1 do
      post admin_sources_path, params: { source: { name: "命令行周报", adapter: "rss", publication: "weekly", sort_order: "2", config: { feed_url: "https://w.example/feed", count: "20" } } }
    end

    assert_redirected_to admin_sources_path
    assert_equal "已保存 命令行周报", flash[:notice]
    source = Source.find_by!(name: "命令行周报")
    assert_equal({ "feed_url" => "https://w.example/feed", "count" => 20 }, source.config)
    log = AuditLog.sole
    assert_equal "source.create", log.action
    assert_equal "Source##{source.id}", log.target
    assert_equal users(:drew), log.user
  end

  test "新建：校验失败回到表单，错误按字段" do
    post admin_sources_path, params: { source: { name: "Hacker News", adapter: "hacker_news", publication: "daily", sort_order: "1", config: { count: "0" } } }

    assert_redirected_to new_admin_source_path
    follow_redirect!
    assert_equal "Admin/Sources/Form", page_component
    assert_equal [ "名称已存在" ], page_props.dig("errors", "name")
    assert_equal [ "1 到 100" ], page_props.dig("errors", "config.count")
    assert_equal 0, AuditLog.count
  end

  test "编辑页带现有值" do
    get edit_admin_source_path(sources(:hackaday))

    assert_equal "Admin/Sources/Form", page_component
    assert_equal "Hackaday", page_props.dig("source", "name")
    assert_equal 24, page_props.dig("source", "config", "window_hours")
  end

  test "更新：适配器不可改，审计记变更" do
    patch admin_source_path(sources(:hackaday)), params: { source: { name: "Hackaday Blog", adapter: "hacker_news", publication: "daily", sort_order: "5", config: { feed_url: "https://hackaday.com/feed/", count: "12", window_hours: "36" } } }

    assert_redirected_to admin_sources_path
    source = sources(:hackaday).reload
    assert_equal "rss", source.adapter
    assert_equal "Hackaday Blog", source.name
    assert_equal 12, source.config["count"]
    assert_equal "source.update", AuditLog.sole.action
    assert_equal [ "Hackaday", "Hackaday Blog" ], AuditLog.sole.payload["name"]
  end

  test "更新失败回编辑页" do
    patch admin_source_path(sources(:hackaday)), params: { source: { name: "", publication: "daily", sort_order: "3", config: { feed_url: "https://hackaday.com/feed/" } } }

    assert_redirected_to edit_admin_source_path(sources(:hackaday))
  end

  test "没有这个源 404" do
    get edit_admin_source_path("nope")

    assert_response :not_found
    assert_equal "Errors/NotFound", page_component
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    get admin_sources_path
    assert_response :forbidden
    assert_equal "Errors/Forbidden", page_component
  end

  test "未登录先去登录" do
    delete session_path
    get admin_sources_path
    assert_redirected_to login_path(next: "/admin/sources")
  end
end
