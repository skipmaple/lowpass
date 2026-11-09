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

  test "三主题减少动态时登录首帧直接显示品牌与可用登录按钮" do
    visit login_path
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    @first_frame_script = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS).fetch("identifier")
      requestAnimationFrame(function capture() {
        const card = document.querySelector('.login-card')
        const buttons = [...document.querySelectorAll('.login-button')]
        if (!card || buttons.length !== 2) return requestAnimationFrame(capture)
        const elements = [document.querySelector('.login-ground'), card, document.querySelector('.login-band'), document.querySelector('.login-body'), ...buttons]
        window.__loginFirstFrame = {
          theme: document.documentElement.dataset.theme,
          elements: elements.map(element => {
            const style = getComputedStyle(element)
            return { opacity: style.opacity, visibility: style.visibility, transform: style.transform, height: element.getBoundingClientRect().height }
          }),
          disabled: buttons.some(button => button.disabled),
          animations: card.getAnimations({ subtree: true }).filter(animation => animation.playState === 'running').length,
        }
      })
    JS
    %w[daybreak duet unfold].each do |theme|
      execute_script("localStorage.setItem('lowpass-theme', arguments[0])", theme)
      visit login_path
      assert_selector ".login-button", count: 2
      wait_until { evaluate_script("window.__loginFirstFrame !== undefined") }
      frame = evaluate_script("window.__loginFirstFrame")

      assert_equal theme, frame.fetch("theme")
      frame.fetch("elements").each do |element|
        assert_equal "1", element.fetch("opacity"), "#{theme} 首帧不能隐藏登录内容"
        assert_equal "visible", element.fetch("visibility")
        assert_equal "none", element.fetch("transform")
        assert_operator element.fetch("height"), :>, 0
      end
      assert_not frame.fetch("disabled")
      assert_equal 0, frame.fetch("animations")
    end
  ensure
    execute_script("localStorage.removeItem('lowpass-theme')")
  end
end
