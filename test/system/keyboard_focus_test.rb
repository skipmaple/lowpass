require "application_system_test_case"

class KeyboardFocusTest < ApplicationSystemTestCase
  setup { sign_in_with_browser(users(:drew)) }

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

  private
    def press(*keys)
      page.driver.browser.switch_to.active_element.send_keys(*keys)
    end
end
