require "application_system_test_case"

class TableFocusTest < ApplicationSystemTestCase
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "跨断点往返保持第二行编辑及下一Tab的记录" do
    sign_in_with_browser(users(:drew))
    [ [ 1024, 1025 ], [ 1025, 1024 ] ].each do |before, after|
      viewport(before)
      visit admin_sources_path
      href = edit_admin_source_path(sources(:github))
      tab_to("a[href='#{href}']")
      viewport(after)
      assert_active("a[href='#{href}']")
      page.driver.browser.switch_to.active_element.send_keys(:tab)
      assert_active("a[href='#{admin_source_runs_path(sources(:github))}']")
    end
  end

  test "跨断点保留更多操作内按钮的可见焦点且不提交抓取" do
    sign_in_with_browser(users(:drew))
    [ [ 1024, 1025 ], [ 1025, 1024 ] ].each do |before, after|
      viewport(before)
      visit admin_sources_path
      tab_to(".sources-table .admin-details > summary")
      page.driver.browser.switch_to.active_element.send_keys(:enter, :tab)
      assert_active(".sources-table .admin-details button", text: "测试抓取")
      viewport(after)
      assert_active(".sources-table .admin-details[open] button", text: "测试抓取")
    end
  end

  test "只读用户详情消失后保留该行且不抢表外焦点" do
    sign_in_with_browser(users(:drew))
    viewport(1024)
    visit admin_users_path
    tab_to(".users-table .management-row-details > summary", text: "登录详情", row_text: "Drew Lee")
    viewport(1025)
    assert_active(".users-table [role='row'][tabindex='-1']")
    assert_includes evaluate_script("document.activeElement.textContent"), "Drew Lee"
    assert_equal "rgb(29, 29, 27)", evaluate_script("getComputedStyle(document.activeElement).outlineColor"), "行焦点沿用墨色"
    assert_equal "2px", evaluate_script("getComputedStyle(document.activeElement).outlineWidth"), "行焦点沿用2px线宽"
    viewport(1024)
    assert_active(".users-table .management-row-details > summary", text: "登录详情")
    tab_to("a[aria-current='page']", text: "用户")
    viewport(1025)
    assert_active("a[aria-current='page']", text: "用户")
  end

  private
    def viewport(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1100, deviceScaleFactor: 1, mobile: false)
      evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
    end

    def tab_to(selector, text: nil, row_text: nil)
      100.times do
        matches = evaluate_script("document.activeElement.matches(#{selector.to_json}) && #{text ? "document.activeElement.textContent.trim() === #{text.to_json}" : 'true'} && #{row_text ? "document.activeElement.closest('.management-row, [role=row]')?.textContent.includes(#{row_text.to_json})" : 'true'}")
        return if matches
        page.driver.browser.switch_to.active_element.send_keys(:tab)
      end
      flunk "Tab未到达 #{selector} #{text}"
    end

    def assert_active(selector, text: nil)
      assert evaluate_script("document.activeElement.matches(#{selector.to_json})"), "#{selector}：实际焦点 #{evaluate_script('document.activeElement.outerHTML')}"
      assert_equal text, evaluate_script("document.activeElement.textContent.trim()") if text
      assert evaluate_script("document.activeElement.matches(':focus-visible')"), "恢复的焦点可见"
    end
end
