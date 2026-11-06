require "application_system_test_case"

class LoginLoadingTest < ApplicationSystemTestCase
  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    if @first_frame_script
      page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @first_frame_script)
    end
  end

  test "登录页不在入口启动后串行请求页面脚本" do
    visit login_path
    assert_selector ".login-button", count: 2

    extra_scripts = evaluate_script(<<~JS)
      (() => {
        const declared = new Set([...document.querySelectorAll('script[src]')].map(script => script.src))
        return performance.getEntriesByType('resource')
          .filter(entry => entry.initiatorType === 'script' && new URL(entry.name).origin === location.origin && !declared.has(entry.name))
          .map(entry => new URL(entry.name).pathname)
      })()
    JS
    assert_empty extra_scripts, "登录所需的页面脚本应与入口并行加载"
  end

  test "减少动态时日出从第一次计算样式就呈现终态" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    @first_frame_script = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS).fetch("identifier")
      requestAnimationFrame(function capture() {
        const sun = document.querySelector('.sunrise-sun')
        if (!sun) return requestAnimationFrame(capture)
        const transform = getComputedStyle(sun).transform
        window.__sunriseFirstFrame = {
          y: transform === 'none' ? 0 : new DOMMatrixReadOnly(transform).m42,
          ray: parseFloat(getComputedStyle(document.querySelector('.sunrise-ray')).strokeDashoffset),
          wave: parseFloat(getComputedStyle(document.querySelector('.sunrise-wave')).strokeDashoffset),
        }
      })
    JS
    visit login_path
    assert_selector ".login-button", count: 2
    wait_until { evaluate_script("window.__sunriseFirstFrame !== undefined") }
    frame = evaluate_script("window.__sunriseFirstFrame")

    assert_in_delta 0, frame.fetch("y"), 0.01, "减少动态时太阳不先藏在地平线下"
    assert_in_delta 0, frame.fetch("ray"), 0.01, "减少动态时光芒不先被裁去"
    assert_in_delta 0, frame.fetch("wave"), 0.01, "减少动态时水纹不先被裁去"
  end
end
