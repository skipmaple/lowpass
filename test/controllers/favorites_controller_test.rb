require "test_helper"

# 收藏页的 props 契约与书签的两个动作（PRD 5.10，AC-10.x）
class FavoritesControllerTest < ActionDispatch::IntegrationTest
  TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  setup do
    sign_in_as(users(:drew))
    @item = items(:hn_one)
  end

  def replace_hn_column
    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Another", url: "https://h.example/other", rank: 1) ])
  end

  # ── 收藏页 ──

  test "没有收藏：空列表，带去最新日刊要的键（AC-10.10）" do
    get favorites_path

    assert_response :success
    assert_equal "Favorites/Index", page_component
    assert_equal [], page_props["entries"]
    assert_equal [], page_props["favorites"]
    assert_equal 1, page_props["page"]
    assert_equal 0, page_props["pages"]
    assert_equal "2026-09-08", page_props["latest_daily_key"]
    assert_equal "06:00", page_props["daily_time"]
  end

  test "日刊收藏的一行：刊物、来源、所在期落到那一栏的那一条、原文" do
    Favorite.keep(users(:drew), @item)

    get favorites_path

    entry = page_props["entries"].sole
    assert_equal @item.url_hash, entry["url_hash"]
    assert_equal "daily", entry["publication"]
    assert_equal "Hacker News", entry["source_name"]
    assert_equal "2026年9月8日", entry.dig("where", "label")
    assert_equal daily_issue_path("2026-09-08", source: sources(:hn).id, anchor: "item-#{@item.id}"), entry.dig("where", "href")
    assert_equal "https://example.com/termlog", entry["url"]
    assert_equal TITLE, entry["title"]
    assert_nil entry["title_zh"]
    assert_nil entry["snippet"]
    assert_nil entry["summary_zh"]
    assert_equal [ @item.url_hash ], page_props["favorites"]
    assert_equal 1, page_props["pages"]
  end

  test "周刊收藏的所在期落到板块锚点（AC-10.8）" do
    weekly = index_item("Zed", issue: issues(:weekly_w36), source: sources(:ruanyf), section: "工具", summary: "一个用 Rust 写的代码编辑器。",
                        meta: { "issue_no" => 366, "anchor" => "工具" })
    Favorite.keep(users(:drew), weekly)

    get favorites_path

    entry = page_props["entries"].sole
    assert_equal "weekly", entry["publication"]
    assert_equal "阮一峰科技爱好者周刊", entry["source_name"]
    assert_equal "2026年 · 第 36 周 · 工具", entry.dig("where", "label")
    assert_equal weekly_issue_path("2026-W36", anchor: "issue-366-工具"), entry.dig("where", "href")
    assert_equal "一个用 Rust 写的代码编辑器。", entry["snippet"]
  end

  test "摘要片段不超过 160 字" do
    Favorite.keep(users(:drew), index_item("Long one", summary: "word " * 90))

    get favorites_path

    snippet = page_props["entries"].sole["snippet"]
    assert_operator snippet.length, :<=, 160
    assert snippet.end_with?("…")
  end

  test "收藏之后才生成的译文也显示" do
    Favorite.keep(users(:drew), @item)
    @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器", summary_zh: "一个用 Rust 写的终端日志查看器。")

    get favorites_path

    entry = page_props["entries"].sole
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", entry["title_zh"]
    assert_equal "一个用 Rust 写的终端日志查看器。", entry["summary_zh"]
  end

  # AC-10.3 重抓把条目行换掉、新内容不含这条链接：收藏仍在，用收藏时的快照；所在期打开那一栏，不带条目锚点
  test "条目被重抓换掉后，收藏行用快照" do
    @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器", summary_zh: "一个用 Rust 写的终端日志查看器。")
    Favorite.keep(users(:drew), @item)
    replace_hn_column

    get favorites_path

    entry = page_props["entries"].sole
    assert_equal TITLE, entry["title"]
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", entry["title_zh"]
    assert_equal "一个用 Rust 写的终端日志查看器。", entry["summary_zh"]
    assert_equal "Hacker News", entry["source_name"]
    assert_equal "2026年9月8日", entry.dig("where", "label")
    assert_equal daily_issue_path("2026-09-08", source: sources(:hn).id), entry.dig("where", "href")
    assert_equal "https://example.com/termlog", entry["url"]
  end

  test "别人的收藏看不到（AC-10.6）" do
    Favorite.keep(users(:guest), @item)

    get favorites_path

    assert_equal [], page_props["entries"]
    assert_equal [], page_props["favorites"]
  end

  test "被下架的条目不出现，恢复上架后回来（AC-10.13）" do
    Favorite.keep(users(:drew), @item)
    @item.update!(hidden: true)

    get favorites_path
    assert_equal [], page_props["entries"]
    assert_equal 0, page_props["pages"]

    @item.update!(hidden: false)
    get favorites_path
    assert_equal [ TITLE ], page_props["entries"].map { |entry| entry["title"] }
  end

  test "按收藏时间倒序，每页 20 条；页码越界跳到最后一页" do
    21.times { |n| travel_to(Time.utc(2026, 9, 9, 0, n)) { Favorite.keep(users(:drew), index_item("Item #{n}")) } }

    get favorites_path
    assert_equal 20, page_props["entries"].size
    assert_equal "Item 20", page_props["entries"].first["title"]
    assert_equal 1, page_props["page"]
    assert_equal 2, page_props["pages"]

    get favorites_path(page: 2)
    assert_equal [ "Item 0" ], page_props["entries"].map { |entry| entry["title"] }
    assert_equal 2, page_props["page"]

    get favorites_path(page: 9)
    assert_redirected_to favorites_path(page: 2)
  end

  test "不是正整数的页码当第 1 页" do
    Favorite.keep(users(:drew), @item)

    get favorites_path(page: "abc")
    assert_equal 1, page_props["page"]

    get favorites_path, params: { page: [ "2" ] }
    assert_equal 1, page_props["page"]

    # 下限也夹住：0 与负数带进 OFFSET 是负的偏移，会炸成 500
    get favorites_path(page: 0)
    assert_equal 1, page_props["page"]

    get favorites_path(page: -3)
    assert_equal 1, page_props["page"]
  end

  # 空列表也算一页：越界的页码一律跳走，不带进 OFFSET（超出 bigint 会炸成 500）
  test "没有收藏时页码越界跳回第 1 页" do
    get favorites_path(page: "99999999999999999999")
    assert_redirected_to favorites_path(page: 1)

    get favorites_path(page: 5)
    assert_redirected_to favorites_path(page: 1)
  end

  # ── 书签的两个动作 ──

  test "POST 收藏一条条目（AC-10.1）" do
    post favorites_path, params: { item_id: @item.id }, as: :json

    assert_response :created
    assert_equal({ "url_hash" => @item.url_hash }, response.parsed_body)
    favorite = users(:drew).favorites.sole
    assert_equal @item.url_hash, favorite.url_hash
    assert_equal TITLE, favorite.title
  end

  test "重复收藏不报错也不多一条（R-10.5）" do
    2.times { post favorites_path, params: { item_id: @item.id }, as: :json }

    assert_response :created
    assert_equal 1, Favorite.count
  end

  test "不存在或已下架的条目收藏不了" do
    post favorites_path, params: { item_id: "nope" }, as: :json
    assert_response :not_found

    @item.update!(hidden: true)
    post favorites_path, params: { item_id: @item.id }, as: :json
    assert_response :not_found

    post favorites_path, as: :json
    assert_response :not_found
    assert_equal 0, Favorite.count
  end

  # AC-10.4 取消是真删；凭回来的凭据恢复，还是原来那一条
  test "DELETE 取消并给回恢复凭据，POST 凭据原样恢复" do
    favorite = travel_to(3.days.ago) { Favorite.keep(users(:drew), @item) }

    delete favorite_path(@item.url_hash), as: :json

    assert_response :success
    undo = response.parsed_body["undo"]
    assert undo.present?
    assert_equal 0, Favorite.count

    post favorites_path, params: { undo: undo }, as: :json

    assert_response :created
    assert_equal({ "url_hash" => @item.url_hash }, response.parsed_body)
    restored = Favorite.sole
    assert_equal favorite.id, restored.id
    assert_equal favorite.created_at, restored.created_at
  end

  test "条目被重抓换掉之后照样能恢复" do
    Favorite.keep(users(:drew), @item)
    delete favorite_path(@item.url_hash), as: :json
    undo = response.parsed_body["undo"]
    replace_hn_column

    post favorites_path, params: { undo: undo }, as: :json

    assert_response :created
    assert_equal TITLE, Favorite.sole.title
  end

  test "无效的凭据恢复不了" do
    post favorites_path, params: { undo: "nope" }, as: :json

    assert_response :not_found
    assert_equal 0, Favorite.count
  end

  test "取消一条不存在的收藏不报错；别人的收藏删不掉" do
    Favorite.keep(users(:guest), @item)

    delete favorite_path(@item.url_hash), as: :json

    assert_response :no_content
    assert_equal 1, users(:guest).favorites.count
  end

  test "恢复凭据不进请求日志" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("undo" => "secret")["undo"]
  end

  test "一分钟 60 次以上回 429（AC-10.11）" do
    60.times { post favorites_path, params: { item_id: "nope" }, as: :json }

    post favorites_path, params: { item_id: @item.id }, as: :json
    assert_response :too_many_requests
    assert_equal 0, Favorite.count

    delete favorite_path(@item.url_hash), as: :json
    assert_response :too_many_requests
  end

  test "收藏页本身不限流" do
    61.times { get favorites_path }

    assert_response :success
  end

  test "未登录：收藏页跳登录并带 next（AC-10.7），书签的动作回 401" do
    delete session_path

    get favorites_path
    assert_redirected_to login_path(next: "/favorites")

    post favorites_path, params: { item_id: @item.id }, as: :json
    assert_response :unauthorized

    delete favorite_path(@item.url_hash), as: :json
    assert_response :unauthorized
    assert_equal 0, Favorite.count
  end
end
