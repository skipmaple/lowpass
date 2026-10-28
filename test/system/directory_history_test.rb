require "application_system_test_case"

class DirectoryHistoryTest < ApplicationSystemTestCase
  include ContinuousReadingHelpers

  setup do
    prepare_continuous_issue
    entries = (1..20).map do |rank|
      Adapters::Entry.new(title: "周刊阅读条目 #{rank}", url: "https://example.com/directory-history/#{rank}",
        section: "工具", rank: rank, content: "这是用来核对跨页返回时阅读位置的完整段落。" * 12,
        meta: { issue_no: 366, issue_title: "保持阅读的位置", anchor: "工具" })
    end
    issues(:weekly_w36).replace_section!(sources(:ruanyf), entries, issue_no: 366)
    sign_in_with_browser(users(:drew))
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  [ :daily, :weekly ].each do |publication|
    test "#{publication} 目录展开后跨页返回恢复展开状态及条目相对视口位置" do
      [ 375, 1440 ].each do |width|
        viewport(width)
        path, directory, target = reading_case(publication)
        visit search_path
        visit path
        assert_selector "details:has(##{directory}):not([open])"
        if width == 375
          find("details:has(##{directory}) > summary").click
        else
          find(".directory-return", match: :first).click
        end
        assert_selector "details:has(##{directory})[open]"
        destination = find("##{directory} a", match: :first)
        hash = URI(destination[:href]).fragment
        destination.click
        wait_until { evaluate_script("location.hash") == "##{hash}" }
        evaluate_async_script("document.fonts.ready.then(arguments[0])")
        execute_script("window.scrollTo(0, window.scrollY + document.getElementById(arguments[0]).getBoundingClientRect().top - 180)", "item-#{target.id}")
        wait_until { (item_top(target) - 180).abs < 2 }
        position = item_top(target)
        wait_until { (evaluate_script("history.state?.documentScrollPosition?.top || 0") - evaluate_script("scrollY")).abs < 2 }

        # 使用真实站内链接，不让 WebDriver 为点击页首搜索先把阅读位置滚回顶部。
        execute_script("document.querySelector('a[aria-label=搜索]').click()")
        assert_current_path search_path
        page.go_back
        assert_current_path path
        assert_selector "details:has(##{directory})[open]"
        wait_until { (item_top(target) - position).abs < 2 }
        assert_in_delta position, item_top(target), 2, "#{publication} #{width}px：返回应落在原文的同一位置"
      end
    end
  end

  test "目录深链直接显示落点，普通新访问仍默认收起" do
    [ 375, 1440 ].each do |width|
      viewport(width)
      [ :daily, :weekly ].each do |publication|
        path, directory = reading_case(publication)
        visit "#{path}##{directory}"
        assert_selector "details:has(##{directory})[open]"
        assert_selector "##{directory} a", minimum: 1
        wait_until { evaluate_script("(() => { const rect = document.getElementById('#{directory}').getBoundingClientRect(); return rect.top >= 0 && rect.top < innerHeight })()") }
        visit path
        assert_selector "details:has(##{directory}):not([open])"
        assert_no_selector "##{directory}", visible: true
      end
    end
  end

  private
    def reading_case(publication)
      if publication == :daily
        target = issues(:daily_0908).items.where(source: sources(:hn)).order(:rank).offset(5).first!
        [ daily_issue_path("2026-09-08"), "source-directory", target ]
      else
        target = issues(:weekly_w36).items.order(:rank).offset(5).first!
        [ weekly_issue_path("2026-W36"), "directory-#{sources(:ruanyf).id}-366", target ]
      end
    end

    def item_top(item)
      evaluate_script("document.getElementById('item-#{item.id}').getBoundingClientRect().top")
    end

    def viewport(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
    end
end
