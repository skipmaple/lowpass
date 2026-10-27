require "application_system_test_case"
require "digest"
require "tempfile"

class HistoricalWeeklyParagraphsTest < ApplicationSystemTestCase
  test "匹配旧刊只恢复展示分段，不改记录并保留目录与收藏" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    content = "第一段讲清楚背景与前因。 第二段描述😀具体变化，保留原有文字。 第三段给出结论。"
    url = "https://example.com/old-paragraphs"
    item = issue.items.create!(source: source, title: "历史正文", rank: 1, section: "文章", url: url,
      url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current, content: content, meta: { issue_no: 412, image_urls: [] })
    Search::Record.rebuild!
    hash = ->(value) { Digest::SHA256.hexdigest(JSON.generate(value)) }
    identity = [ issue.period_key, source.adapter, 412, issue.id, source.id, item.id, item.rank, item.title, item.url, item.section,
      Digest::SHA256.hexdigest(content), hash.call([]) ]
    first = "第一段讲清楚背景与前因。"
    second = "第二段描述😀具体变化，保留原有文字。"
    manifest = { version: 1, period: issue.period_key, issue_no: 412, source_commit: "a" * 40, source_sha256: "b" * 64,
      entries: [ { lookup_sha256: hash.call([ issue.id, source.id, 412, item.rank ]), rank: item.rank,
        identity_sha256: hash.call(identity), offsets: [ first.bytesize, first.bytesize + 1 + second.bytesize ] } ] }
    ImageDimension.stubs(:enqueue_for)

    Tempfile.create([ "paragraphs", ".json" ]) do |file|
      file.write(JSON.generate(manifest))
      file.flush
      HistoricalParagraphBoundaries.stubs(:current).returns(HistoricalParagraphBoundaries.new(paths: [ file.path ]))
      search_before = Search::Record.order(:id).map(&:attributes)
      before = [ item.reload.attributes, issue.reload.attributes, Favorite.count ]
      [ 320, 375, 1440 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
        visit weekly_issue_path(issue.period_key)
        row = find("#item-#{item.id}")
        assert_equal [ first, second, "第三段给出结论。" ], row.all(".item-content--weekly > p").map(&:text)
        assert_selector "#item-#{item.id} .item-mark", visible: true
        assert_selector ".weekly-directory", visible: true
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{width}px 横向溢出"
        row.find(:xpath, "./ancestor::section[1]").find(".directory-return").click
        assert_selector ".weekly-directory nav:focus"
        find(".weekly-directory nav:focus").click_on "文章"
        assert_selector "#item-#{item.id}", visible: true
        execute_script("arguments[0].focus()", row.find(".item-title a"))
        page.driver.browser.switch_to.active_element.send_keys(:tab)
        assert_selector "#item-#{item.id} .item-mark:focus"
      end
      assert_equal before, [ item.reload.attributes, issue.reload.attributes, Favorite.count ]
      visit search_path(q: "历史正文")
      assert_selector ".search-row", text: "历史正文"
      assert_equal search_before, Search::Record.order(:id).map(&:attributes)
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
