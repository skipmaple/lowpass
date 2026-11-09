require "application_system_test_case"
require "digest"

class WeeklyReferenceLinksTest < ApplicationSystemTestCase
  # 无头 Linux 默认没有指针设备；显式模拟鼠标，再用 CDP 单独测试触屏。
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ], options: { name: :weekly_pointer_chrome } do |options|
    options.add_argument("--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4")
  end

  test "连续段落中的正文链接的触控区域不会互相覆盖" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    url = "https://example.com/neighboring-links"
    item = issue.items.create!(source: source, title: "连续链接", rank: 1, section: "文章", url: url,
      url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current, content: "第一段。\n第二段。",
      meta: { issue_no: 415, reference_links: [ [ 0, 0, 3, "https://example.com/a" ], [ 1, 0, 3, "https://example.com/b" ] ] })
    ImageDimension.stubs(:enqueue_for)
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    visit weekly_issue_path(issue.period_key)
    overlap = page.evaluate_script(<<~JS)
      (() => {
        const [a, b] = [...document.querySelectorAll('#item-#{item.id} .weekly-reference')].map(e => e.getBoundingClientRect())
        return { x: Math.min(a.right, b.right) - Math.max(a.left, b.left), y: Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) }
      })()
    JS
    assert overlap.fetch("x") <= 0 || overlap.fetch("y") <= 0, "链接触控区域重叠：#{overlap}"
  ensure
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "纯鼠标设备的短正文链接不撑高文本行" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    text = "这里有一份说明，值得继续阅读。"
    url = "https://example.com/inline-rhythm"
    issue.items.create!(source: source, title: "普通正文", rank: 1, section: "文章", url: url,
      url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current, content: text, meta: { issue_no: 415 })
    link_url = "https://example.com/inline-rhythm-link"
    item = issue.items.create!(source: source, title: "带链接正文", rank: 2, section: "文章", url: link_url,
      url_hash: Digest::SHA256.hexdigest(link_url), fetched_at: Time.current, content: text,
      meta: { issue_no: 415, reference_links: [ [ 0, 5, 7, "https://example.com/reference" ] ] })
    ImageDimension.stubs(:enqueue_for)

    [ 320, 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path(issue.period_key)
      geometry = page.evaluate_script(<<~JS)
        (() => {
          const paragraph = document.querySelector('#item-#{item.id} .item-content--weekly > p')
          const link = paragraph.querySelector('.weekly-reference')
          const normal = Array.from(document.querySelectorAll('.item-content--weekly > p')).find(p => p.textContent === paragraph.textContent && !p.querySelector('a'))
          return { height: paragraph.getBoundingClientRect().height, normalHeight: normal.getBoundingClientRect().height,
            targetHeight: link.getBoundingClientRect().height,
            fine: matchMedia('(hover: hover) and (pointer: fine)').matches, coarse: matchMedia('(any-pointer: coarse)').matches }
        })()
      JS
      assert geometry.fetch("fine"), "需要模拟鼠标：#{geometry}"
      assert_not geometry.fetch("coarse"), "不能模拟触屏：#{geometry}"
      assert_in_delta geometry.fetch("normalHeight"), geometry.fetch("height"), 1, "#{width}px 行距：#{geometry}"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "纯鼠标设备的长正文链接在窄屏自然换行" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    label = "VeryLongReference" * 12
    content = "请查看#{label}了解详情。"
    url = "https://example.com/long-inline-link"
    item = issue.items.create!(source: sources(:ruanyf), title: "长链接", rank: 1, section: "文章", url: url,
      url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current, content: content,
      meta: { issue_no: 415, reference_links: [ [ 0, 3, 3 + label.length, "https://example.com/docs" ] ] })
    ImageDimension.stubs(:enqueue_for)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: false)
    visit weekly_issue_path(issue.period_key)
    link = find("#item-#{item.id} .weekly-reference")
    assert_equal label, link.text
    assert_equal "inline", link.evaluate_script("getComputedStyle(this).display")
    assert_operator link.evaluate_script("this.getClientRects().length"), :>, 1
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

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

    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    [ 320, 375, 390, 481, 600, 768, 1024, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path(issue.period_key)
      row = find("#item-#{item.id}")
      links = row.all(".weekly-reference")
      assert page.evaluate_script("matchMedia('(any-pointer: coarse)').matches"), "#{width}px 需要模拟触屏"
      assert_equal %w[交互版 代码 手册], links.map(&:text)
      assert_equal [ "https://example.com/demo", "https://example.com/code", "https://example.com/docs" ], links.map { |link| link[:href] }
      assert_equal "结果：Alpha 的实现（交互版，代码）。查看手册。", row.find(".item-content--weekly").text.gsub("\n", "")
      assert links.all? { |link| link.evaluate_script("this.getBoundingClientRect().height") >= 44 }, "#{width}px 触控高度"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{width}px 横向溢出"
      row.all(".weekly-reference-group").each do |group|
        assert_equal 1, group.evaluate_script("this.getClientRects().length"), "#{width}px 括号或标点被拆开"
      end
    end
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 900, deviceScaleFactor: 1, mobile: false)
    visit weekly_issue_path(issue.period_key)
    row = find("#item-#{item.id}")
    execute_script("arguments[0].focus()", row.find(".item-title a"))
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    assert_selector "#item-#{item.id} .weekly-reference:focus", text: "交互版"
    assert_equal "solid", page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    assert page.evaluate_script("document.activeElement.matches(':focus-visible') && parseFloat(getComputedStyle(document.activeElement).outlineWidth) > 0")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    assert_selector "#item-#{item.id} .weekly-reference:focus", text: "代码"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_equal "inline", row.first(".weekly-reference").evaluate_script("getComputedStyle(this).display")
    assert_equal before, [ issue.reload.attributes, item.reload.attributes, Favorite.count ]
  ensure
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
