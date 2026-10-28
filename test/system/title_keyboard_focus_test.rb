require "application_system_test_case"

# 真实页面的标题通过原生 Tab 获焦；先收齐计算样式，RED 日志也能保留四个入口的实际状态。
class TitleKeyboardFocusTest < ApplicationSystemTestCase
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "日刊搜索收藏与周刊标题的键盘焦点沿用墨色 2px 轮廓" do
    weekly_url = "https://example.com/keyboard-focus-weekly"
    weekly = issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: "一个终端下的日志工具", section: "工具", rank: 1,
      url: weekly_url, url_hash: Digest::SHA256.hexdigest(weekly_url), fetched_at: Time.current,
      meta: { issue_no: 366, issue_title: "慢下来的理由", anchor: "工具" }
    )
    Favorite.keep(users(:drew), items(:hn_one))
    Search::Record.rebuild!
    sign_in_with_browser(users(:drew))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 900, deviceScaleFactor: 1, mobile: false)

    item = items(:hn_one)
    cases = [
      [ "daily", daily_issue_path("2026-09-08"), ".item-title > a.t[href='#{item.url}']", item.title ],
      [ "search", search_path(q: "terminal"), ".search-title > a.t[href='#{item.url}']", item.title ],
      [ "favorites", favorites_path, ".search-title > a.t[href='#{item.url}']", item.title ],
      [ "weekly", weekly_issue_path("2026-W36"), ".item-title > a.t[href='#{weekly.url}']", weekly.title ]
    ]
    states = {}
    cases.each do |name, path, selector, title|
      visit path
      assert_selector selector, text: title, exact_text: true
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      execute_script(<<~JS)
        window.titleFocusTabs = []
        document.addEventListener('keydown', event => {
          if (event.key === 'Tab') window.titleFocusTabs.push(event.isTrusted)
        }, { capture: true })
      JS
      tab_to_title(selector)
      evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
      states[name] = title_focus_state(name, path)
      root = page.driver.browser.execute_cdp("DOM.getDocument").fetch("root").fetch("nodeId")
      node = page.driver.browser.execute_cdp("DOM.querySelector", nodeId: root, selector: selector).fetch("nodeId")
      ax = page.driver.browser.execute_cdp("Accessibility.getPartialAXTree", nodeId: node, fetchRelatives: false).fetch("nodes").first
      assert_equal title, ax.dig("name", "value"), "#{name}：读屏名称保持原始标题"
      assert_equal "在新标签页打开", ax.dig("description", "value"), "#{name}：读屏器应获得新标签页提示"
    end

    diagnostic = "TITLE_KEYBOARD_FOCUS #{states.to_json}"
    puts diagnostic
    assert_equal 375, evaluate_script("innerWidth"), diagnostic
    states.each do |name, state|
      assert_equal state.fetch("expectedPath"), state.fetch("path"), "#{name}：读取真实页面；#{diagnostic}"
      assert state.fetch("focusVisible"), "#{name}：真实标题键盘焦点应可见；#{diagnostic}"
      assert_operator state.fetch("trustedTabs").length, :>, 0, "#{name}：应经过原生 Tab；#{diagnostic}"
      assert state.fetch("trustedTabs").all?, "#{name}：Tab 必须为浏览器可信事件；#{diagnostic}"
      assert state.fetch("inViewport"), "#{name}：获焦标题应在视口内；#{diagnostic}"
      assert_equal "在新标签页打开", state.fetch("description"), "#{name}：标题外链应提供读屏提示"
      assert_equal "_blank", state.fetch("target"), "#{name}：原文仍在新标签页打开"
      assert_equal [ "solid", "2px", "rgb(29, 29, 27)", "2px" ],
        state.fetch("outline").values_at("style", "width", "color", "offset"), "#{name}：沿用墨色 2px 轮廓与 2px 间距；#{diagnostic}"
    end
  end

  private
    def tab_to_title(selector)
      40.times do
        page.driver.browser.switch_to.active_element.send_keys(:tab)
        break if evaluate_script("document.activeElement.matches(#{selector.to_json})")
      end
      assert_selector "#{selector}:focus"
    end

    def title_focus_state(label, expected_path)
      evaluate_script(<<~JS)
        (() => {
          const title = document.activeElement
          const style = getComputedStyle(title)
          const box = title.getBoundingClientRect()
          return {
            label: #{label.to_json}, expectedPath: #{expected_path.to_json}, path: location.pathname + location.search,
            text: title.textContent.trim(), href: title.getAttribute('href'), target: title.getAttribute('target'),
            description: document.getElementById(title.getAttribute('aria-describedby'))?.textContent.trim() || '',
            focusVisible: title.matches(':focus-visible'), trustedTabs: window.titleFocusTabs,
            outline: { style: style.outlineStyle, width: style.outlineWidth, color: style.outlineColor, offset: style.outlineOffset },
            box: box.toJSON(),
            inViewport: box.width > 0 && box.height > 0 && box.left >= 0 && box.right <= innerWidth && box.top >= 0 && box.bottom <= innerHeight,
          }
        })()
      JS
    end
end
