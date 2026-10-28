require "application_system_test_case"

class KeyboardFocusTest < ApplicationSystemTestCase
  setup do
    # Chrome 标签页复用会积累到历史容量上限，先隔离本例的原生锚点历史。
    page.driver.browser.execute_cdp("Page.resetNavigationHistory")
    sign_in_with_browser(users(:drew))
  end

  test "重抓选源的双向 Tab 边界跟随已选来源" do
    visit admin_issues_path(month: "2026-09")
    within(:xpath, "//*[@role='row'][.//*[text()='2026-09-08']]") { click_on "重抓某源" }
    assert_selector "[role='dialog'] button:focus", text: "取消", exact_text: true
    press([ :shift, :tab ])
    assert_selector "[role='dialog'] input:focus:checked[value='#{sources(:hn).id}']"
    press(:down)
    selected = "[role='dialog'] input:focus:checked[value='#{sources(:github).id}']"
    assert_selector selected
    press([ :shift, :tab ])
    assert_selector "[role='dialog'] button:focus", text: "重抓 GitHub Trending", exact_text: true
    press(:tab)
    assert_selector selected
    press(:tab)
    assert_selector "[role='dialog'] button:focus", text: "取消", exact_text: true
    press(:tab)
    press(:tab)
    assert_selector selected
    press(:escape)
    assert_no_selector "[role='dialog']"
    assert_selector "button:focus", text: "重抓某源", exact_text: true
  end

  test "账户按钮方向键只打开一次菜单并停在首尾项" do
    visit favorites_path
    20.times do
      break if evaluate_script("document.activeElement.matches('button[aria-label=账户]')")
      press(:tab)
    end
    assert_selector "button[aria-label='账户']:focus"
    press(:down)
    assert_selector "[role='menuitem']:focus", text: "账户信息", exact_text: true
    press(:end)
    assert_selector "[role='menuitem']:focus", text: "登出", exact_text: true
    press(:home)
    assert_selector "[role='menuitem']:focus", text: "账户信息", exact_text: true
    press(:escape)
    assert_selector "button[aria-label='账户']:focus"
    press(:up)
    assert_selector "[role='menuitem']:focus", text: "登出", exact_text: true
    press(:escape)
    assert_no_selector "[role='menu']"
    assert_selector "button[aria-label='账户']:focus"
  end

  [ 375, 1440 ].each do |width|
    [ "no-preference", "reduce" ].each do |motion|
      test "#{width}px #{motion} 返回周刊目录及下一次 Tab 的完整焦点轮廓可见" do
        url = "https://example.com/directory-focus"
        issues(:weekly_w36).items.create!(
          source: sources(:ruanyf), title: "一个终端下的日志工具", section: "工具", rank: 1,
          url: url, url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current,
          content: Array.new(24, "目录链接让读者在长篇周刊中跳到板块，再返回目录继续选择。" * 4).join("\n\n"),
          meta: { issue_no: 366, issue_title: "慢下来的理由", anchor: "工具" }
        )
        browser = page.driver.browser
        browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
        browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: motion } ])
        visit weekly_issue_path("2026-W36")
        assert_selector ".weekly-directory"
        evaluate_async_script("document.fonts.ready.then(arguments[0])")
        execute_script(<<~JS)
          window.directoryKeys = []
          document.addEventListener('keydown', event => {
            window.directoryKeys.push({ key: event.key, trusted: event.isTrusted })
          }, { capture: true })
        JS

        tab_to(".weekly-directory > summary")
        press(:return)
        assert_selector ".weekly-directory[open]"
        press(:tab)
        assert_selector ".anchor-chip:first-child:focus"
        group_hash = find(".anchor-chip", match: :first)["href"].split("#", 2).last
        history_length = evaluate_script("history.length")
        press(:return)
        wait_until { evaluate_script("location.hash") == "##{group_hash}" }
        assert_equal history_length + 1, evaluate_script("history.length")

        tab_to(".directory-return")
        directory_hash = find(".directory-return", match: :first)["href"].split("#", 2).last
        press(:return)
        assert_selector ".weekly-directory[open] > .anchors:focus"
        wait_until { evaluate_script("location.hash") == "##{directory_hash}" }
        assert_equal history_length + 2, evaluate_script("history.length")
        returned = directory_focus_state
        press(:tab)
        assert_selector ".anchor-chip:first-child:focus"
        first_chip = directory_focus_state
        states = { width: width, motion: motion, returned: returned, first_chip: first_chip }
        diagnostic = "DIRECTORY_KEYBOARD_FOCUS #{states.to_json}"
        puts diagnostic

        browser.navigate.back
        wait_until { evaluate_script("location.hash") == "##{group_hash}" }
        browser.navigate.forward
        wait_until { evaluate_script("location.hash") == "##{directory_hash}" }
        assert_equal weekly_issue_path("2026-W36"), evaluate_script("location.pathname")
        assert_equal width, evaluate_script("innerWidth")
        assert evaluate_script("window.directoryKeys.every(event => event.trusted)"), diagnostic
        assert_operator evaluate_script("window.directoryKeys.filter(event => event.key === 'Enter').length"), :>=, 2, diagnostic
        [ returned, first_chip ].each do |state|
          assert state.fetch("focusVisible"), diagnostic
          assert state.fetch("outlineVisible"), diagnostic
          assert_operator state.fetch("perimeter").fetch("top"), :>=, 0, "完整焦点轮廓不能裁在视口上沿；#{diagnostic}"
          assert state.fetch("inViewport"), "完整焦点轮廓四边应在视口内；#{diagnostic}"
        end
      ensure
        browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
        browser&.execute_cdp("Emulation.setEmulatedMedia", features: [])
      end
    end
  end

  private
    def tab_to(selector)
      40.times do
        break if evaluate_script("document.activeElement.matches(#{selector.to_json})")
        press(:tab)
      end
      assert_selector "#{selector}:focus"
    end

    def directory_focus_state
      evaluate_script(<<~JS)
        (() => {
          const element = document.activeElement
          const style = getComputedStyle(element)
          const box = element.getBoundingClientRect()
          const extent = Math.max(0, parseFloat(style.outlineWidth) + parseFloat(style.outlineOffset))
          const perimeter = { top: box.top - extent, right: box.right + extent, bottom: box.bottom + extent, left: box.left - extent }
          return {
            tag: element.tagName, text: element.textContent.trim(), hash: location.hash,
            focusVisible: element.matches(':focus-visible'),
            outlineVisible: style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0,
            outline: { style: style.outlineStyle, width: style.outlineWidth, offset: style.outlineOffset, color: style.outlineColor },
            box: box.toJSON(), perimeter,
            inViewport: box.width > 0 && box.height > 0 && perimeter.top >= 0 && perimeter.left >= 0 && perimeter.right <= innerWidth && perimeter.bottom <= innerHeight,
          }
        })()
      JS
    end

    def press(*keys)
      page.driver.browser.switch_to.active_element.send_keys(*keys)
    end
end
