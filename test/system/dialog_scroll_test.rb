require "application_system_test_case"

class DialogScrollTest < ApplicationSystemTestCase
  setup { sign_in_with_browser(users(:drew)) }
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "真实对话框锁住文档滚轮，取消后恢复滚动与原有overflow" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 700, deviceScaleFactor: 1, mobile: false)
    visit settings_path
    assert_selector "button", text: "注销", exact_text: true
    evaluate_async_script("document.fonts.ready.then(() => requestAnimationFrame(() => requestAnimationFrame(arguments[0])))")
    overflow = evaluate_script("[document.documentElement, document.body].map(node => node.style.overflow)")
    click_on "注销"
    assert_selector "[role=dialog]", text: "注销后无法恢复"
    reading = evaluate_script("scrollY")
    assert_operator reading, :>, 100, "真实设置页必须可向上滚动，避免空页面假阳性"
    execute_script("window.__dialogWheels = []; document.addEventListener('wheel', event => window.__dialogWheels.push(event.isTrusted), { passive: true })")

    wheel_up
    wait_until { evaluate_script("window.__dialogWheels.length") == 1 }
    evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
    assert_equal [ true ], evaluate_script("window.__dialogWheels")
    assert_in_delta reading, evaluate_script("scrollY"), 1, "确认期间可信滚轮不能滚动遮罩背后的设置页"

    within("[role=dialog]") { click_on "取消" }
    assert_no_selector "[role=dialog]"
    assert_equal overflow, evaluate_script("[document.documentElement, document.body].map(node => node.style.overflow)")
    assert_selector "button:focus", text: "注销", exact_text: true
    resumed = evaluate_script("scrollY")
    wheel_up
    wait_until { evaluate_script("scrollY") < resumed - 50 }
    assert_equal [ true, true ], evaluate_script("window.__dialogWheels")
  end

  private
    def wheel_up
      page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseWheel", x: 10, y: 10, deltaX: 0, deltaY: -350)
    end
end
