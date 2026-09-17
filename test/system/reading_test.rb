require "application_system_test_case"

# P0 出口：真的在浏览器里读一期日刊。切来源是页面本地状态（条目全在 props 里，不回服务端），
# 集成测试只看得到第一屏的 payload，验不出切换这件事。
class ReadingTest < ApplicationSystemTestCase
  HN_TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  setup do
    sign_in_with_browser(users(:drew))
  end

  test "读一期日刊并切到另一个来源" do
    visit daily_issue_path("2026-09-08")

    assert_text HN_TITLE

    click_on sources(:github).name

    assert_no_text HN_TITLE
    # fixture 里 GitHub Trending 那一栏是 failed：附录 B 的「今日抓取失败，已通知管理员」
    assert_text "今日抓取失败，已通知管理员"
  end

  test "来源地址经过页内锚点与刷新仍保留" do
    source = sources(:hackaday)
    visit daily_issue_path("2026-09-08")

    find(".source-tabs").click_on source.name
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_equal "source=#{source.id}", URI.parse(page.current_url).query

    click_on "返回来源目录"
    current = URI.parse(page.current_url)
    assert_equal "source=#{source.id}", current.query
    assert_equal "source-directory", current.fragment

    refresh
    assert_selector "[role='tab'][aria-selected='true']", text: source.name
    assert_equal "source=#{source.id}", URI.parse(page.current_url).query
  end

  test "来源选择经过离开与浏览器前进后退仍保留" do
    source = sources(:hackaday)
    visit daily_issue_path("2026-09-08")

    find(".source-tabs").click_on source.name
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_selector "[role='tab'][aria-selected='true']", text: source.name

    find("a[aria-label='搜索']").click
    assert_current_path search_path

    page.go_back
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_selector "[role='tab'][aria-selected='true']", text: source.name

    page.go_forward
    assert_current_path search_path

    page.go_back
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_selector "[role='tab'][aria-selected='true']", text: source.name
  end

  # D20：`/` 就是最新一期日刊，没有单独的首页
  test "首页落到最新一期" do
    visit root_path

    assert_current_path daily_issue_path("2026-09-08")
    assert_text "9月8日"
  end

  # 附录 B：「这一页不存在。回到首页」。文案写在页面组件里（没有开 SSR），只有真的渲染出来才看得见
  test "不存在的地址给附录 B 的 404" do
    visit "/daily/nope"

    assert_text "这一页不存在。"

    click_on "回到首页"

    assert_current_path daily_issue_path("2026-09-08")
  end
end
