require "application_system_test_case"

class SearchInputLayoutTest < ApplicationSystemTestCase
  THEMES = %w[ daybreak duet unfold ].freeze
  HINT = "搜标题、摘要或来源。拼写不准也可以。".freeze

  test "三主题空词不预留清除位置，输入后仍可键盘清除" do
    sign_in_with_browser(users(:drew))
    THEMES.each do |theme|
      [ 320, 375, 1440 ].each do |width|
        visit_search(theme, width)
        assert_selector "#search-query:focus"
        geometry = evaluate_script(<<~JS)
          (() => {
            const node = document.querySelector('.search-field');
            const field = node.getBoundingClientRect(), style = getComputedStyle(node);
            const input = document.querySelector('.search-input').getBoundingClientRect();
            return { contentRight: field.right - parseFloat(style.borderRightWidth) - parseFloat(style.paddingRight),
                     inputRight: input.right, inputWidth: input.width,
                     paddingRight: parseFloat(getComputedStyle(document.querySelector('.search-input')).paddingRight),
                     documentWidth: document.documentElement.scrollWidth, viewportWidth: innerWidth };
          })()
        JS
        assert_in_delta geometry.fetch("contentRight"), geometry.fetch("inputRight"), 1, "#{theme} #{width}px: #{geometry}"
        assert_operator geometry.fetch("paddingRight"), :<, 44, "空词不应保留整个清除按钮的空位"
        assert_operator geometry.fetch("documentWidth"), :<=, geometry.fetch("viewportWidth")

        fill_in "搜索", with: "hello"
        assert_selector ".search-clear:not(:disabled)"
        clear_geometry = evaluate_script(<<~JS)
          (() => {
            const button = document.querySelector('.search-clear').getBoundingClientRect();
            const input = document.querySelector('.search-input').getBoundingClientRect();
            return { width: button.width, height: button.height, buttonLeft: button.left,
                     inputWidth: input.width, inputRight: input.right,
                     paddingRight: parseFloat(getComputedStyle(document.querySelector('.search-input')).paddingRight),
                     documentWidth: document.documentElement.scrollWidth, viewportWidth: innerWidth };
          })()
        JS
        assert_in_delta geometry.fetch("inputWidth"), clear_geometry.fetch("inputWidth"), 1, "#{theme} #{width}px: input changed size"
        assert_operator clear_geometry.fetch("width"), :>=, 44
        assert_operator clear_geometry.fetch("height"), :>=, 44
        assert_operator clear_geometry.fetch("inputRight") - clear_geometry.fetch("paddingRight"), :<=, clear_geometry.fetch("buttonLeft") + 1
        assert_operator clear_geometry.fetch("documentWidth"), :<=, clear_geometry.fetch("viewportWidth")
        fill_in "搜索", with: "long-search-" * 10
        assert_equal "long-search-" * 10, find("#search-query").value
        find("#search-query").send_keys(:tab)
        assert_selector ".search-clear:focus"
        page.driver.browser.switch_to.active_element.send_keys(:enter)
        assert_field "搜索", with: ""
        assert_selector "#search-query:focus"
        fill_in "搜索", with: "hello"
        find(".search-clear").click
        assert_field "搜索", with: ""
        assert_selector "#search-query:focus"
      end
    end
  end

  test "三主题完整显示搜索提示，输入与清除保持版面稳定" do
    sign_in_with_browser(users(:drew))
    THEMES.each do |theme|
      [ 320, 375, 480, 481, 600, 601, 768, 1440 ].each do |width|
        visit_search(theme, width)
        assert_field "搜索", placeholder: HINT
        if [ 320, 601 ].include?(width)
          tree = page.driver.browser.execute_cdp("Accessibility.getFullAXTree")
          search = tree.fetch("nodes").find { |node| node.dig("role", "value") == "searchbox" && node.dig("name", "value") == "搜索" }
          assert_equal HINT, search&.dig("description", "value")
        end
        if width <= 600
          assert_selector ".search-hint[aria-hidden='true']", text: HINT, visible: true
          details = evaluate_script(<<~JS)
            (() => {
              const hint = document.querySelector('.search-hint'), rect = hint.getBoundingClientRect();
              const range = document.createRange();
              range.selectNodeContents(hint);
              const textRects = Array.from(range.getClientRects());
              return { width: rect.width, scrollWidth: hint.scrollWidth,
                       textLeft: Math.min(...textRects.map(rect => rect.left)),
                       textRight: Math.max(...textRects.map(rect => rect.right)),
                       textBottom: Math.max(...textRects.map(rect => rect.bottom)), bottom: rect.bottom,
                       fieldLeft: document.querySelector('.search-field').getBoundingClientRect().left,
                       headRight: document.querySelector('.search-head').getBoundingClientRect().right,
                       height: document.querySelector('.search-head').getBoundingClientRect().height };
            })()
          JS
          assert_operator details.fetch("scrollWidth"), :<=, details.fetch("width") + 1
          assert_in_delta details.fetch("fieldLeft"), details.fetch("textLeft"), 1, "#{theme} #{width}px"
          assert_operator details.fetch("textRight"), :<=, details.fetch("headRight") + 1
          assert_operator details.fetch("textBottom"), :<=, details.fetch("bottom") + 1
          fill_in "搜索", with: "测试"
          assert_selector ".search-hint", visible: true
          assert_in_delta details.fetch("height"), evaluate_script("document.querySelector('.search-head').getBoundingClientRect().height"), 0.5
          find(".search-clear").click
          assert_field "搜索", with: ""
          assert_in_delta details.fetch("height"), evaluate_script("document.querySelector('.search-head').getBoundingClientRect().height"), 0.5
        else
          assert_selector ".search-hint", visible: false
        end
        assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{theme} #{width}px"
      end
    end
  end

  test "三主题筛选组换行后保留间隔且不遮挡操作" do
    sign_in_with_browser(users(:drew))
    THEMES.each do |theme|
      [ 481, 601 ].each do |width|
        visit_search(theme, width)
        groups = evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('.filters .filter-group')).map((group) => {
            const rect = group.getBoundingClientRect();
            return { top: rect.top, bottom: rect.bottom };
          })
        JS
        assert_equal 3, groups.length
        groups.each_cons(2) do |a, b|
          next unless b.fetch("top") > a.fetch("top") + 1
          assert_operator b.fetch("top") - a.fetch("bottom"), :>=, 8, "#{theme} #{width}px"
          assert_operator b.fetch("top") - a.fetch("bottom"), :<=, 24, "#{theme} #{width}px"
        end
        assert_selector ".filters a", minimum: 7
        assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{theme} #{width}px"
      end
    end
  end

  test "三主题强制颜色下保留完整提示与可见焦点" do
    sign_in_with_browser(users(:drew))
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    THEMES.each do |theme|
      visit_search(theme, 320)
      assert_selector ".search-hint", text: HINT, visible: true
      assert_selector "#search-query:focus"
      styles = evaluate_script(<<~JS)
        (() => {
          const input = document.querySelector('.search-input');
          const placeholder = getComputedStyle(input, '::placeholder');
          const focus = getComputedStyle(document.querySelector('.search-field'));
          return { color: placeholder.color, opacity: placeholder.opacity,
                   outlineStyle: focus.outlineStyle, outlineWidth: focus.outlineWidth };
        })()
      JS
      assert styles.fetch("opacity") == "0" || styles.fetch("color").match?(/rgba\([^)]*,\s*0\)/), styles.inspect
      assert_equal "solid", styles.fetch("outlineStyle")
      assert_equal "2px", styles.fetch("outlineWidth")
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private
    def visit_search(theme, width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      execute_script("localStorage.setItem('lowpass-theme', arguments[0])", theme)
      visit search_path
      assert_selector "html[data-theme='#{theme}']", visible: :all
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
    end
end
