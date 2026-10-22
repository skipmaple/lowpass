require "application_system_test_case"

# P0 出口：在真实浏览器里验证连续阅读、原生目录锚点与历史位置。
class ReadingTest < ApplicationSystemTestCase
  include ContinuousReadingHelpers
  HN_TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  test "键盘选择目录后焦点进入来源，Tab 继续正文而非回到顶部目录" do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    find("#source-directory a[href='#source-#{sources(:github).id}']").send_keys(:enter)
    wait_until { evaluate_script("document.activeElement.id") == "source-#{sources(:github).id}" }
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    assert evaluate_script("document.activeElement.matches('#source-#{sources(:github).id} .item-title a')")
    assert_operator evaluate_script("scrollY"), :>, 500
  end

  test "三个来源连续可读，目录跳转保留之前的内容" do
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    assert_text HN_TITLE
    assert_selector ".daily-source", count: 3
    within("#source-directory") { click_on sources(:github).name }
    assert_current_path(daily_issue_path("2026-09-08")) { |url| url.fragment == "source-#{sources(:github).id}" }
    assert_text HN_TITLE
    within("#source-#{sources(:github).id}") { assert_text "本期抓取失败，已通知管理员" }
    refresh
    assert_selector ".daily-source", count: 3
    assert_current_path(daily_issue_path("2026-09-08")) { |url| url.fragment == "source-#{sources(:github).id}" }
  end

  test "旧来源深链仍定位且条目锚点优先" do
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08", source: sources(:hackaday).id)
    wait_until { evaluate_script("Math.abs(window.scrollY - Math.min(document.querySelector('#source-#{sources(:hackaday).id}').getBoundingClientRect().top + window.scrollY - 24, document.documentElement.scrollHeight - innerHeight)) < 2") }
    visit daily_issue_path("2026-09-08", source: sources(:hackaday).id, anchor: "item-#{items(:hn_one).id}")
    wait_until { evaluate_script("document.querySelector('#item-#{items(:hn_one).id}').getBoundingClientRect().top >= 0") }
    assert_text HN_TITLE
    visit search_path
    visit daily_issue_path("2026-09-08", source: sources(:hackaday).id, anchor: "item-replaced")
    wait_until { evaluate_script("Math.abs(window.scrollY - Math.min(document.querySelector('#source-#{sources(:hackaday).id}').getBoundingClientRect().top + window.scrollY - 24, document.documentElement.scrollHeight - innerHeight)) < 2") }
  end

  test "来源目录之后继续阅读，离开再后退恢复阅读位置" do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    within("#source-directory") { click_on sources(:hackaday).name }
    assert_current_path(daily_issue_path("2026-09-08")) { |url| url.fragment == "source-#{sources(:hackaday).id}" }
    wait_until { evaluate_script("Math.abs(document.querySelector('#source-#{sources(:hackaday).id}').getBoundingClientRect().top - 24) < 2") }
    execute_script("window.scrollBy(0, 100)")
    reading_position = evaluate_script("window.scrollY")
    wait_until { evaluate_script("window.history.state.documentScrollPosition?.top") == reading_position }
    # 点击可见导航前浏览器可能会滚回顶部，直接发起同样的 Inertia 访问保存当前位置。
    execute_script("document.querySelector('a[aria-label=搜索]').click()")
    assert_current_path search_path
    page.go_back
    assert_selector ".daily-source", count: 3
    wait_until { (evaluate_script("window.scrollY") - reading_position).abs < 2 }
  end

  # D20：`/` 就是最新一期日刊，没有单独的首页
  test "首页落到最新一期" do
    sign_in_with_browser(users(:drew))
    visit root_path

    assert_current_path daily_issue_path("2026-09-08")
    assert_text "9月8日"
  end

  # 附录 B：「这一页不存在。回到首页」。文案写在页面组件里（没有开 SSR），只有真的渲染出来才看得见
  test "不存在的地址给附录 B 的 404" do
    sign_in_with_browser(users(:drew))
    visit "/daily/nope"

    assert_text "这一页不存在。"

    click_on "回到首页"

    assert_current_path daily_issue_path("2026-09-08")
  end
end
