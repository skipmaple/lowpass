require "application_system_test_case"

class SearchInputLayoutTest < ApplicationSystemTestCase
  test "空搜索词不占用清除按钮的空间，输入后仍可键盘清除" do
    sign_in_with_browser(users(:drew))
    [ 320, 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit search_path
      assert_selector "#search-query:focus"
      geometry = evaluate_script(<<~JS)
        (() => {
          const field = document.querySelector('.search-field').getBoundingClientRect();
          const input = document.querySelector('.search-input').getBoundingClientRect();
          return { fieldRight: field.right, inputRight: input.right, inputWidth: input.width,
                   documentWidth: document.documentElement.scrollWidth, viewportWidth: innerWidth };
        })()
      JS
      assert_in_delta geometry.fetch("fieldRight"), geometry.fetch("inputRight"), 1, "width #{width}: #{geometry}"
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
      assert_in_delta geometry.fetch("inputWidth"), clear_geometry.fetch("inputWidth"), 1, "width #{width}: input changed size"
      assert_operator clear_geometry.fetch("width"), :>=, 44
      assert_operator clear_geometry.fetch("height"), :>=, 44
      assert_operator clear_geometry.fetch("inputRight") - clear_geometry.fetch("paddingRight"), :<=, clear_geometry.fetch("buttonLeft")
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
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "窄屏完整显示搜索提示，输入和清除时版面保持稳定" do
    sign_in_with_browser(users(:drew))
    [ 320, 375, 480, 481, 600, 601, 768, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit search_path
      assert_field "搜索", placeholder: "搜标题、摘要或来源。拼写不准也可以。"
      if [ 320, 601 ].include?(width)
        tree = page.driver.browser.execute_cdp("Accessibility.getFullAXTree")
        search = tree.fetch("nodes").find { |node| node.dig("role", "value") == "searchbox" && node.dig("name", "value") == "搜索" }
        assert_equal "搜标题、摘要或来源。拼写不准也可以。", search&.dig("description", "value")
      end
      if width <= 600
        assert_selector ".search-hint[aria-hidden='true']", text: "搜标题、摘要或来源。拼写不准也可以。", visible: true
        evaluate_async_script("document.fonts.ready.then(arguments[0])")
        details = evaluate_script(<<~JS)
          (() => {
            const hint = document.querySelector('.search-hint');
            const rect = hint.getBoundingClientRect();
            const range = document.createRange();
            range.selectNodeContents(hint);
            const textRects = Array.from(range.getClientRects());
            return { width: rect.width, scrollWidth: hint.scrollWidth,
                     textLeft: textRects[0].left, textRight: textRects[0].right,
                     textLines: textRects.length, inputLeft: document.querySelector('.search-input').getBoundingClientRect().left,
                     height: document.querySelector('.search-head').getBoundingClientRect().height };
          })()
        JS
        assert_operator details.fetch("scrollWidth"), :<=, details.fetch("width") + 1
        assert_equal 1, details.fetch("textLines"), "width #{width}: hint must fit on one line"
        assert_in_delta details.fetch("inputLeft"), details.fetch("textLeft"), 1
        assert_operator details.fetch("textRight"), :<=, width - 24
        fill_in "搜索", with: "测试"
        assert_selector ".search-hint", visible: true
        assert_in_delta details.fetch("height"), evaluate_script("document.querySelector('.search-head').getBoundingClientRect().height"), 0.5
        find(".search-clear").click
        assert_field "搜索", with: ""
        assert_in_delta details.fetch("height"), evaluate_script("document.querySelector('.search-head').getBoundingClientRect().height"), 0.5
      else
        assert_selector ".search-hint", visible: false
      end
      assert evaluate_script("document.documentElement.scrollWidth <= innerWidth")
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "筛选组换行后保持紧凑且不遮挡操作" do
    sign_in_with_browser(users(:drew))
    [ 481, 601 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit search_path
      groups = evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.filters .filter-group')).map((group) => {
          const rect = group.getBoundingClientRect();
          return { top: rect.top, bottom: rect.bottom };
        })
      JS
      assert_equal 3, groups.length
      groups.each_cons(2) do |a, b|
        next unless b.fetch("top") > a.fetch("top") + 1
        assert_in_delta 20, b.fetch("top") - a.fetch("bottom"), 1, "width #{width}"
      end
      assert_selector ".filters a", minimum: 7
      assert evaluate_script("document.documentElement.scrollWidth <= innerWidth")
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "强制颜色下保留完整提示与可见焦点" do
    sign_in_with_browser(users(:drew))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: false)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    visit search_path
    assert_selector ".search-hint", text: "搜标题、摘要或来源。拼写不准也可以。", visible: true
    styles = evaluate_script(<<~JS)
      (() => {
        const input = document.querySelector('.search-input');
        const placeholder = getComputedStyle(input, '::placeholder');
        const focus = getComputedStyle(input);
        return { color: placeholder.color, opacity: placeholder.opacity,
                 outlineStyle: focus.outlineStyle, outlineWidth: focus.outlineWidth };
      })()
    JS
    assert styles.fetch("opacity") == "0" || styles.fetch("color").match?(/rgba\([^)]*,\s*0\)/), styles.inspect
    assert_equal "solid", styles.fetch("outlineStyle")
    assert_equal "2px", styles.fetch("outlineWidth")
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
