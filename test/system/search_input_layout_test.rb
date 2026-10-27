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
end
