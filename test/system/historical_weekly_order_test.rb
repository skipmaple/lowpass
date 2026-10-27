require "application_system_test_case"
require "digest"
require "tempfile"

class HistoricalWeeklyOrderTest < ApplicationSystemTestCase
  test "匹配的历史索引把图片放回段落之间而不修改刊期" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    image_url = "http://127.0.0.1:#{Capybara.current_session.server.port}/icon.png"
    url = "https://example.com/historical-story"
    item = issue.items.create!(source: source, title: "历史图片顺序", rank: 1, section: "图片",
      url: url, url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current,
      content: "图片介绍。\n上图说明。", meta: { issue_no: 416, image_urls: [ image_url ] })
    key = [ issue.id, source.id, 416, item.rank ]
    identity = [ issue.period_key, source.adapter, 416, issue.id, source.id, item.id, item.rank, item.title, item.url, item.section,
      Digest::SHA256.hexdigest(item.content), Digest::SHA256.hexdigest(JSON.generate(item.meta.fetch("image_urls"))) ]
    manifest = { version: 1, period: issue.period_key, issue_no: 416, source_commit: "a" * 40, source_sha256: "b" * 64,
      entries: [ { lookup_sha256: Digest::SHA256.hexdigest(JSON.generate(key)), rank: item.rank,
        identity_sha256: Digest::SHA256.hexdigest(JSON.generate(identity)), positions: [ 1 ] } ] }
    ImageDimension.stubs(:enqueue_for)

    Tempfile.create([ "historical-weekly", ".json" ]) do |file|
      file.write(JSON.generate(manifest))
      file.flush
      HistoricalImagePositions.stubs(:current).returns(HistoricalImagePositions.new(paths: [ file.path ]))
      before = [ issue.reload.attributes, item.reload.attributes, Favorite.count ]

      [ 320, 375, 1440 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
        visit weekly_issue_path(issue.period_key)
        row = find("#item-#{item.id}")
        assert_selector "#item-#{item.id} .item-media img", count: 1, visible: :all
        assert_equal %w[p img p], row.all(".item-content--weekly p, .item-media img", visible: :all).map(&:tag_name)
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{width}px 横向溢出"
      end
      HistoricalImagePositions.stubs(:current).returns(HistoricalImagePositions.new(paths: []))
      visit weekly_issue_path(issue.period_key)
      row = find("#item-#{item.id}")
      assert_equal %w[p p img], row.all(".item-content--weekly p, .item-media img", visible: :all).map(&:tag_name)
      assert_equal before, [ issue.reload.attributes, item.reload.attributes, Favorite.count ]
      assert_not item.meta.key?("image_positions")
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
