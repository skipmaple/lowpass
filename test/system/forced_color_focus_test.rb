require "application_system_test_case"

class ForcedColorFocusTest < ApplicationSystemTestCase
  setup { sign_in_with_browser(users(:drew)) }

  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  %w[daybreak duet unfold].each do |theme|
    test "#{theme} 高对比模式下选中项与键盘焦点同时可见" do
      execute_script("localStorage.setItem('lowpass-theme', #{theme.to_json})")
      browser = page.driver.browser
      browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
      visit search_path
      assert_field "搜索"
      visual = evaluate_script(<<~JS)
        (() => {
          const search = document.querySelector('.search-input');
          const wordmark = document.querySelector('.footer-wordmark');
          return { search: getComputedStyle(search).color, wordmark: getComputedStyle(wordmark).color,
                   text: getComputedStyle(document.body).color, canvas: getComputedStyle(document.documentElement).backgroundColor };
        })()
      JS
      assert_equal visual.fetch("text"), visual.fetch("search"), "搜索文字应采用系统前景色"
      assert_equal visual.fetch("text"), visual.fetch("wordmark"), "页脚刊名应采用系统前景色"
      fill_in "搜索", with: "Rust"
      clear_colors = evaluate_script("[getComputedStyle(document.querySelector('.search-clear')).color, getComputedStyle(document.querySelector('.search-clear svg')).stroke]")
      assert_equal clear_colors.first, clear_colors.last, "清除图标应继承按钮的系统色"
      find(".search-clear").click
      assert_field "搜索", with: ""
      selected = find(".filters nav[aria-label='刊物'] .seg-item[aria-current='true']")
      before = evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", selected)
      find_field("搜索").send_keys(:tab, :tab)
      assert_selector ".filters nav[aria-label='刊物'] .seg-item[aria-current='true']:focus-visible"
      focused = evaluate_script(<<~JS, selected)
        (() => { const s = getComputedStyle(arguments[0]); return { offset: s.outlineOffset, border: getComputedStyle(arguments[0], '::after').borderTopWidth }; })()
      JS
      assert_equal "3px", before, "选中项应有内侧标记"
      assert_equal "2px", focused.fetch("offset"), "焦点应在选中标记之外"
      assert_equal "3px", focused.fetch("border"), "焦点出现时仍要保留选中标记"

      browser.action.send_keys(:tab, :tab, :tab).perform
      assert_selector ".chips button:focus-visible", text: sources(:hn).name
      browser.action.send_keys(:space).perform
      assert_selector ".chips button[aria-pressed='true']:focus-visible", text: sources(:hn).name
      chip = find(".chips button[aria-pressed='true']", text: sources(:hn).name)
      assert_equal "2px", evaluate_script("getComputedStyle(arguments[0]).outlineOffset", chip)
      assert_equal "3px", evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", chip)
    end
    test "#{theme} 窄屏展开筛选后，选中与键盘焦点仍可同时辨认" do
      execute_script("localStorage.setItem('lowpass-theme', #{theme.to_json})")
      browser = page.driver.browser
      browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: false)
      visit search_path
      find(".filter-toggle").click
      target = find(".filters nav[aria-label='刊物'] .seg-item[aria-current='true']")
      find_field("搜索").click
      8.times do
        break if evaluate_script("document.activeElement === arguments[0]", target)
        browser.action.send_keys(:tab).perform
      end
      assert_selector ".filters nav[aria-label='刊物'] .seg-item[aria-current='true']:focus-visible"
      assert_equal "2px", evaluate_script("getComputedStyle(arguments[0]).outlineOffset", target)
      assert_equal "3px", evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", target)
      assert evaluate_script("document.documentElement.scrollWidth <= innerWidth")
    end

    test "#{theme} 后台选中导航也保留独立的键盘焦点" do
      execute_script("localStorage.setItem('lowpass-theme', #{theme.to_json})")
      browser = page.driver.browser
      browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
      visit "/admin"
      target = find(".admin-nav-item[aria-current='page']")
      30.times do
        break if evaluate_script("document.activeElement === arguments[0]", target)
        browser.action.send_keys(:tab).perform
      end
      assert_selector ".admin-nav-item[aria-current='page']:focus-visible"
      assert_equal "2px", evaluate_script("getComputedStyle(arguments[0]).outlineOffset", target)
      assert_equal "3px", evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", target)
    end

    test "#{theme} 高对比模式下日刊来源链接和失败状态的图标继承系统色" do
      execute_script("localStorage.setItem('lowpass-theme', #{theme.to_json})")
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
      visit daily_issue_path("2026-09-08")
      assert_selector ".source-foot svg"
      assert_selector ".source-state-failed svg"
      icons = evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.source-foot svg, .source-state-failed svg')).map(icon => ({
          stroke: getComputedStyle(icon).stroke, color: getComputedStyle(icon).color
        }))
      JS
      assert icons.all? { |icon| icon.fetch("stroke") == icon.fetch("color") }, icons.inspect
      assert_selector ".source-state-failed", text: "本期抓取失败，已通知管理员"
    end

    test "#{theme} 高对比模式下来源标题与分隔线仍可辨认" do
      execute_script("localStorage.setItem('lowpass-theme', #{theme.to_json})")
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
      visit daily_issue_path("2026-09-08")
      assert_selector ".daily-source h2", count: 3
      values = evaluate_script(<<~JS)
        [...document.querySelectorAll('.daily-source')].map(section => ({
          title: getComputedStyle(section.querySelector('h2')).color,
          rule: getComputedStyle(section.querySelector('.daily-source-rule')).borderTopColor,
          canvas: getComputedStyle(document.documentElement).backgroundColor
        }))
      JS
      values.each do |value|
        assert_not_equal value.fetch("canvas"), value.fetch("title")
        assert_not_equal value.fetch("canvas"), value.fetch("rule")
      end
    end

    test "#{theme} 高对比模式下缺页图标及返回入口保持可辨认" do
      execute_script("localStorage.setItem('lowpass-theme', #{theme.to_json})")
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
      visit "/this-page-does-not-exist"
      assert_selector ".error-art svg"
      values = evaluate_script(<<~JS)
        (() => {
          const svg = document.querySelector('.error-art svg');
          return { color: getComputedStyle(svg).color, stroke: getComputedStyle(svg).stroke,
                   canvas: getComputedStyle(document.documentElement).backgroundColor };
        })()
      JS
      assert_equal values.fetch("color"), values.fetch("stroke")
      assert_not_equal values.fetch("canvas"), values.fetch("stroke")
      assert_link "回到首页", href: root_path
    end

    test "#{theme} 正常配色下搜索文字及页脚刊名仍沿用主题墨色" do
      execute_script("localStorage.setItem('lowpass-theme', #{theme.to_json})")
      visit search_path
      assert_field "搜索"
      colors = evaluate_script(<<~JS)
        (() => {
          const ink = getComputedStyle(document.body).color;
          return [ink, getComputedStyle(document.querySelector('.search-input')).color,
            getComputedStyle(document.querySelector('.footer-wordmark')).color];
        })()
      JS
      assert_equal [ colors.first ] * 3, colors
    end
  end
end
