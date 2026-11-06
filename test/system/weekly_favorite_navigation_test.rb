require "application_system_test_case"

class WeeklyFavoriteNavigationTest < ApplicationSystemTestCase
  test "收藏的周刊条目直达正文，重抓后仍在原板块时定位新记录" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    entries = (1..32).map do |rank|
      Adapters::Entry.new(title: "收藏资料 #{rank}", url: "https://example.com/ref-#{rank}", rank: rank,
        section: "工具", meta: { issue_no: 366, anchor: "工具" })
    end
    issue.replace_section!(source, entries, issue_no: 366)
    item = issue.items.find_by!(title: "收藏资料 20")
    favorite = Favorite.keep(users(:drew), item)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 900, deviceScaleFactor: 1, mobile: false)

    visit favorites_path
    click_on "所在期 · 2026年 · 第 36 周 · 工具"
    assert_current_path weekly_issue_path("2026-W36", section: "issue-366-工具")
    assert_selector "article#item-#{item.id}:focus"
    wait_until { evaluate_script("(() => { const top = document.getElementById('item-#{item.id}').getBoundingClientRect().top; return top >= 0 && top < 80 })()") }

    issue.replace_section!(source, entries, issue_no: 366)
    replacement = Favorite.live_items([ favorite ])[favorite.live_key]
    assert_not_equal item.id, replacement.id
    visit favorites_path
    click_on "所在期 · 2026年 · 第 36 周 · 工具"
    assert_selector "article#item-#{replacement.id}:focus"
    wait_until { evaluate_script("(() => { const top = document.getElementById('item-#{replacement.id}').getBoundingClientRect().top; return top >= 0 && top < 80 })()") }
    assert_equal "工具", favorite.reload.section
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
