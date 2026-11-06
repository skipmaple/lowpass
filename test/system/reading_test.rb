require "application_system_test_case"

# P0 出口：日刊按来源连续阅读，来源目录只定位，不隐藏其他来源。
# 集成测试只看得到 payload，实际滚动、历史与页内锚点仍在浏览器里验。
class ReadingTest < ApplicationSystemTestCase
  HN_TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  setup do
    sign_in_with_browser(users(:drew))
  end

  test "读一期日刊并定位另一个来源，其他来源仍可阅读" do
    visit daily_issue_path("2026-09-08")

    assert_text HN_TITLE

    click_on sources(:github).name

    assert_selector "article#item-#{items(:hn_one).id}", text: HN_TITLE
    assert_selector ".source-tab[aria-current='location']", text: sources(:github).name
    # fixture 里 GitHub Trending 那一栏是 failed：附录 B 的「本期抓取失败，已通知管理员」
    assert_text "本期抓取失败，已通知管理员"
  end

  test "来源地址经过页内锚点与刷新仍保留" do
    source = sources(:hackaday)
    visit daily_issue_path("2026-09-08")

    find(".source-tabs").click_on source.name
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_equal "source=#{source.id}", URI.parse(page.current_url).query

    find(".source-tail a[href='#source-directory']", match: :first).click
    current = URI.parse(page.current_url)
    assert_equal "source=#{source.id}", current.query
    assert_equal "source-directory", current.fragment

    refresh
    assert_selector ".source-tabs a", text: source.name
    assert_selector "article#item-#{items(:hn_one).id}", text: HN_TITLE
    assert_equal "source=#{source.id}", URI.parse(page.current_url).query
  end

  test "来源选择经过离开与浏览器前进后退仍保留" do
    source = sources(:hackaday)
    visit daily_issue_path("2026-09-08")

    find(".source-tabs").click_on source.name
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_selector ".source-tab[aria-current='location']", text: source.name

    within(".masthead-nav") { click_on "搜索" }
    assert_current_path search_path

    page.go_back
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_selector ".source-tab[aria-current='location']", text: source.name

    page.go_forward
    assert_current_path search_path

    page.go_back
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
    assert_selector ".source-tab[aria-current='location']", text: source.name
  end

  # D20：`/` 就是最新一期日刊，没有单独的首页
  test "首页落到最新一期" do
    visit root_path

    assert_current_path daily_issue_path("2026-09-08")
    assert_selector ".calendar-date", text: /09\s*\/\s*08/
  end

  # 附录 B：「这一页不存在。回到首页」。文案写在页面组件里（没有开 SSR），只有真的渲染出来才看得见
  test "不存在的地址给附录 B 的 404" do
    visit "/daily/nope"

    assert_text "这一页不存在。"

    click_on "回到首页"

    assert_current_path daily_issue_path("2026-09-08")
  end
end
