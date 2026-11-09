require "application_system_test_case"
require "digest"

class WeeklyReadingActionsTest < ApplicationSystemTestCase
  test "三主题周刊从标题到正文再到收藏，编号对齐且没有重复操作" do
    sign_in_with_browser(users(:drew))
    item = issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "读完内容再决定收藏", rank: 1,
      section: "文章", url: "https://example.com/weekly-reading-actions",
      url_hash: Digest::SHA256.hexdigest("https://example.com/weekly-reading-actions"), fetched_at: Time.current,
      content: "　（1）\n第一段说明文章背景，读者可以先理解内容。\n（2）\n第二段提供结论，收藏应该跟在完整内容之后。",
      meta: { issue_no: 366, issue_title: "阅读与判断", image_urls: [] })
    %w[daybreak duet unfold].each do |theme|
      [ 390, 1440 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
        execute_script("localStorage.setItem('lowpass-theme', arguments[0])", theme)
        visit weekly_issue_path("2026-W36")
        row = find("#item-#{item.id}")
        assert_no_selector ".weekly-reading .directory-return"
        assert_no_selector "#item-#{item.id} .item-original-action"
        assert_equal item.url, row.find(".item-title a")[:href]
        evaluate_async_script("document.fonts.ready.then(arguments[0])")
        geometry = row.evaluate_script(<<~JS)
          (() => {
            const body = this.querySelector('.item-content--weekly').getBoundingClientRect();
            const button = this.querySelector('button.item-mark').getBoundingClientRect();
            const numbers = [...this.querySelectorAll('.weekly-paragraph-number')].map(p => p.getBoundingClientRect().left);
            return { left: body.left, right: body.right, bottom: body.bottom, button: button.toJSON(), numbers };
          })()
        JS
        assert_equal 2, geometry.fetch("numbers").length
        geometry.fetch("numbers").each { |left| assert_in_delta geometry.fetch("left"), left, 0.5 }
        assert_operator geometry.fetch("button").fetch("top"), :>=, geometry.fetch("bottom")
        assert_in_delta geometry.fetch("right"), geometry.fetch("button").fetch("right"), 0.5
        assert_operator geometry.fetch("button").fetch("height"), :>=, 44
        assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
        execute_script("arguments[0].scrollIntoView({ block: 'end', behavior: 'instant' }); window.scrollBy(0, 80)", row)
        save_screenshot(Rails.root.join("tmp/screenshots/weekly-actions-#{theme}-#{width}.png"))
        button = row.find("button.item-mark")
        button.click
        assert_selector "#item-#{item.id} .item-mark[data-on]"
        wait_for_favorite_requests(1)
        button.click
        assert_no_selector "#item-#{item.id} .item-mark[data-on]"
        wait_for_favorite_requests(2)
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
