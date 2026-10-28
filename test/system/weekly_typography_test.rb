require "application_system_test_case"

class WeeklyTypographyTest < ApplicationSystemTestCase
  test "周刊正文在桌面和窄屏保持可读字号并完整显示" do
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    text = "阅读不只是寻找答案，也是给自己时间理解新的观点。" * 8
    url = "https://example.com/weekly-reading"
    item = issue.items.create!(source: source, title: "阅读与思考", section: "文章", rank: 1,
      url: url, url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current,
      content: "#{text}\n\n第二段保留完整的中文与 English 内容。", meta: { issue_no: 366, issue_title: "阅读与思考" })
    sign_in_with_browser(users(:drew))

    [ [ 320, 16 ], [ 375, 16 ], [ 1440, 18 ], [ 1920, 18 ] ].each do |width, size|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path("2026-W36")
      paragraph = find("#item-#{item.id} .item-content--weekly p", match: :first)
      assert_equal text, paragraph.text
      geometry = paragraph.evaluate_script(<<~JS)
        (() => {
          const node = this.querySelector('span'), style = getComputedStyle(node), r = this.getBoundingClientRect()
          return { size: parseFloat(style.fontSize), line: parseFloat(style.lineHeight), width: r.width,
            overflow: document.documentElement.scrollWidth > innerWidth }
        })()
      JS
      assert_equal size, geometry.fetch("size"), "#{width}px 正文字号"
      assert_operator geometry.fetch("line"), :>=, size * 1.7, "#{width}px 行距"
      assert_operator geometry.fetch("width"), :<=, width
      assert_not geometry.fetch("overflow"), "#{width}px 无横向溢出"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
