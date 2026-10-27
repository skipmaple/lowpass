require "application_system_test_case"
require "digest"

class WeeklyReferenceLinksTest < ApplicationSystemTestCase
  test "正文链接在常用屏宽可识别、可键盘访问并保留阅读文字" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    body = "结果：Alpha 的实现（[交互版](https://example.com/demo)，[代码](https://example.com/code)）。\n\n> 查看[手册](https://example.com/docs)。"
    content = SummaryCleaner.content(body)
    references = Adapters::RuanyfWeekly::ReferenceLinks.for(body: body, content: content, issue_no: 415)
    quotes = Adapters::RuanyfWeekly::QuoteRanges.for(body: body, content: content)
    url = "https://example.com/reading-test"
    item = issue.items.create!(source: source, title: "阅读资料", rank: 1, section: "文章", url: url,
      url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current, content: content, meta: { issue_no: 415, reference_links: references, quote_ranges: quotes })
    ImageDimension.stubs(:enqueue_for)
    before = [ issue.reload.attributes, item.reload.attributes, Favorite.count ]

    [ 320, 375, 390, 481, 600, 768, 1024, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path(issue.period_key)
      row = find("#item-#{item.id}")
      links = row.all(".weekly-reference")
      assert_equal %w[交互版 代码 手册], links.map(&:text)
      assert_equal [ "https://example.com/demo", "https://example.com/code", "https://example.com/docs" ], links.map { |link| link[:href] }
      assert_equal "结果：Alpha 的实现（交互版，代码）。查看手册。", row.find(".item-content--weekly").text.gsub("\n", "")
      assert links.all? { |link| link.evaluate_script("this.getBoundingClientRect().height") >= 44 }, "#{width}px 触控高度"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{width}px 横向溢出"
      row.all(".weekly-reference-group").each do |group|
        assert_equal 1, group.evaluate_script("this.getClientRects().length"), "#{width}px 括号或标点被拆开"
      end
    end
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 900, deviceScaleFactor: 1, mobile: false)
    visit weekly_issue_path(issue.period_key)
    row = find("#item-#{item.id}")
    execute_script("arguments[0].focus()", row.find(".item-title a"))
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    assert_selector "#item-#{item.id} .weekly-reference:focus", text: "交互版"
    assert_equal "solid", page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    assert_selector "#item-#{item.id} .weekly-reference:focus", text: "代码"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_equal "inline", row.first(".weekly-reference").evaluate_script("getComputedStyle(this).display")
    assert_equal before, [ issue.reload.attributes, item.reload.attributes, Favorite.count ]
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
