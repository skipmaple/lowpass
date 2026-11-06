require "application_system_test_case"

class StartupRecoveryTest < ApplicationSystemTestCase
  setup { sign_in_with_browser(users(:drew)) }

  teardown do
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    if @suppress_resource_errors
      page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @suppress_resource_errors)
    end
  end

  test "入口加载失败有原生重载入口，恢复资源后保留查询并正常阅读" do
    [ 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: false)
      block_entry
      visit search_path(q: "Rust")

      assert_selector "#startup-recovery", text: "页面尚未加载完成", wait: 2
      assert_operator evaluate_script("document.querySelector('#startup-recovery h1').getBoundingClientRect().top"), :>=, 48
      assert_equal "heading", find("#startup-recovery h1").native.aria_role
      assert_no_selector "#app > *"
      assert_link "重新加载", href: search_path(q: "Rust")
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
      assert_operator evaluate_script("document.querySelector('#startup-recovery a').getBoundingClientRect().height"), :>=, 44

      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
      page.driver.browser.action.send_keys(:tab).perform
      assert_equal "重新加载", evaluate_script("document.activeElement.textContent")
      assert_equal "rgb(29, 29, 27)", evaluate_script("getComputedStyle(document.activeElement).outlineColor")
      page.driver.browser.action.send_keys(:enter).perform

      assert_selector "h1", text: "搜索"
      assert_field "q", with: "Rust"
      assert_no_selector ".startup-recovery"
    end
  end

  test "没有收到脚本错误事件时，等待过久仍给出手动重载入口" do
    # 阻断入口并吞掉资源错误事件，只检验独立的等待兜底；这不是实际网络挂起的模拟。
    @suppress_resource_errors = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS).fetch("identifier")
      window.addEventListener('error', event => {
        if (event.target.tagName === 'SCRIPT') event.stopImmediatePropagation()
      }, true)
    JS
    block_entry
    visit daily_issue_path("2026-09-08")

    assert_no_selector "#startup-recovery", wait: 0
    assert_selector "#startup-recovery", text: "页面尚未加载完成", wait: 10
    assert_link "重新加载", href: daily_issue_path("2026-09-08")

    # 真正加载迟到的模块，不替换 app DOM；新 query 避免复用浏览器已失败的模块记录。
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    execute_script(<<~JS)
      const entry = document.createElement('script')
      entry.type = 'module'
      entry.src = document.querySelector('script[data-startup-entry]').src + '?late-arrival=1'
      document.head.append(entry)
    JS
    assert_selector "h1", text: "9月8日"
    assert_no_selector ".startup-recovery"
    assert_equal 1, evaluate_script("document.querySelectorAll('main:not([hidden])').length")
  end

  private
    def block_entry
      page.driver.browser.execute_cdp("Network.enable")
      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*application-*.js" ])
    end
end
