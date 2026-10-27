require "application_system_test_case"

class ScheduledArchiveTest < ApplicationSystemTestCase
  test "未到日刊生成时间时归档和详情一致显示计划时间" do
    travel_to Time.utc(2026, 9, 8, 21) do
      Setting.set("daily_time", "07:30")
      sign_in_with_browser(users(:drew))

      [ 320, 375, 1440 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
        visit daily_issues_path(month: "2026-09")
        row = find(".archive-row", text: "9月9日")
        assert_selector ".archive-row", text: "待 07:30 生成"
        assert row.has_css?("svg[role='img'] title", text: "待生成", visible: :all)
        assert_not row.has_text?("缺期")
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        row.click
        assert_text "今日将于 07:30 生成"
        assert_link "阅读最新日刊"
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
