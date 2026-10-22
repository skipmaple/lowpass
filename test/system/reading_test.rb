require "application_system_test_case"

# P0 出口：在真实浏览器里验证连续阅读、原生目录锚点与历史位置。
class ReadingTest < ApplicationSystemTestCase
  include ContinuousReadingHelpers
  HN_TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  test "栏尾返回目录保持原生历史，键盘可继续选择来源" do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    within("#source-directory") { click_on sources(:github).name }
    wait_for_reading_anchor("source-#{sources(:github).id}")
    history_length = evaluate_script("history.length")
    within("#source-#{sources(:github).id}") { click_on "返回来源目录" }
    wait_until { evaluate_script("document.activeElement.id") == "source-directory" }
    assert_equal "#source-directory", evaluate_script("location.hash")
    assert_equal history_length + 1, evaluate_script("history.length")
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    assert evaluate_script("document.activeElement.matches('#source-directory a:first-child')")
    page.go_back
    wait_until { evaluate_script("location.hash") == "#source-#{sources(:github).id}" }
    assert_selector ".daily-source", count: 3
  end

  test "目录跳转建立独立历史，后退与前进恢复相应来源和阅读位置" do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    assert_selector ".daily-source", count: 3
    history_length = evaluate_script("history.length")
    within("#source-directory") { click_on sources(:github).name }
    wait_until { evaluate_script("location.hash") == "#source-#{sources(:github).id}" }
    assert_equal history_length + 1, evaluate_script("history.length")
    wait_for_reading_anchor("source-#{sources(:github).id}")
    github_position = evaluate_script("scrollY")
    execute_script("document.querySelector('#source-directory a[href=\"#source-#{sources(:hackaday).id}\"]').click()")
    wait_until { evaluate_script("location.hash") == "#source-#{sources(:hackaday).id}" }
    assert_equal history_length + 2, evaluate_script("history.length")
    wait_for_reading_anchor("source-#{sources(:hackaday).id}")
    page.go_back
    wait_until { evaluate_script("location.hash") == "#source-#{sources(:github).id}" }
    wait_until { (evaluate_script("scrollY") - github_position).abs < 2 }
    page.go_forward
    wait_until { evaluate_script("location.hash") == "#source-#{sources(:hackaday).id}" }
    assert_text sources(:hackaday).name
  end

  test "从同源条目深链点击目录后，后退仍能回到原条目" do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
    source = sources(:github)
    item = Item.where(issue: issues(:daily_0908), source: source).order(:rank).offset(2).first!
    visit daily_issue_path("2026-09-08", source: source.id, anchor: "item-#{item.id}")
    assert_selector "#item-#{item.id}"
    wait_for_reading_anchor("item-#{item.id}")
    reading_position = evaluate_script("scrollY")
    history_length = evaluate_script("history.length")
    execute_script("document.querySelector('#source-directory a[href=\"#source-#{source.id}\"]').click()")
    wait_until { evaluate_script("location.hash") == "#source-#{source.id}" }
    assert_equal history_length + 1, evaluate_script("history.length")
    wait_for_reading_anchor("source-#{source.id}")
    page.go_back
    wait_until { evaluate_script("location.hash") == "#item-#{item.id}" }
    wait_until { (evaluate_script("scrollY") - reading_position).abs < 2 }
    assert_current_path daily_issue_path("2026-09-08", source: source.id)
  end

  test "来源目录焦点内的左右键不触发翻期" do
    Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    find("#source-directory a", match: :first).send_keys(:left, :right)
    assert_current_path daily_issue_path("2026-09-08")
  end

  test "目录跳转后收藏写回与离开后返回都保留来源 hash" do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
    source = sources(:github)
    item = Item.where(issue: issues(:daily_0908), source: source).order(:rank).first!
    visit daily_issue_path("2026-09-08")
    within("#source-directory") { click_on source.name }
    within("#source-#{source.id}") { find("button[aria-label='收藏：#{item.title}']").click }
    wait_until { users(:drew).favorites.exists?(url_hash: item.url_hash) }
    wait_for_favorite_requests(1)
    assert_equal "#source-#{source.id}", evaluate_script("location.hash")
    execute_script("document.querySelector('a[aria-label=搜索]').click()")
    assert_current_path search_path
    page.go_back
    wait_until { evaluate_script("location.hash") == "#source-#{source.id}" }
    within("#source-#{source.id}") { assert_selector "button[aria-label='取消收藏：#{item.title}'][data-on]" }
  end

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
    wait_for_reading_anchor("source-#{sources(:hackaday).id}")
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

  private
    def wait_for_reading_anchor(id)
      # 原生 hash 先变，Inertia 的加密历史、延迟锚点定位和滚动快照随后才完成。
      # 操作下一步前等待真正的阅读落点，不能把中间位置记成预期的恢复位置。
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      wait_until do
        evaluate_script(<<~JS)
          (() => {
            const target = document.getElementById(#{id.to_json})
            const top = target.getBoundingClientRect().top + scrollY - parseFloat(getComputedStyle(target).scrollMarginTop || 0)
            const expected = Math.min(top, document.documentElement.scrollHeight - innerHeight)
            return history.state?.page instanceof ArrayBuffer &&
              Math.abs(scrollY - expected) < 2 &&
              Math.abs(history.state.documentScrollPosition?.top - scrollY) < 2
          })()
        JS
      end
    end
end
