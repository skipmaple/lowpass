require "application_system_test_case"
require "digest"
require "tempfile"

class HistoricalWeeklyOrderTest < ApplicationSystemTestCase
  test "未知尺寸的懒加载图片尚未开始加载时原图入口留在正文内" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    filler_url = "https://example.com/long-story"
    issue.items.create!(source: source, title: "长篇正文", rank: 1, section: "图片", url: filler_url,
      url_hash: Digest::SHA256.hexdigest(filler_url), fetched_at: Time.current,
      content: Array.new(180, "这是用于推迟图片加载的段落。").join("\n"), meta: { issue_no: 416 })
    image_url = "http://127.0.0.1:#{Capybara.current_session.server.port}/icon.png?deferred-image"
    url = "https://example.com/deferred-image"
    item = issue.items.create!(source: source, title: "延后加载的图片", rank: 2, section: "图片", url: url,
      url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current,
      content: "图片介绍。\n图片说明。", meta: { issue_no: 416, image_urls: [ image_url ], image_positions: [ 1 ] })
    ImageDimension.stubs(:enqueue_for)

    [ 320, 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 700, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path(issue.period_key)
      geometry = page.evaluate_script(<<~JS)
        (() => {
          const row = document.getElementById('item-#{item.id}'), image = row.querySelector('img')
          const content = row.querySelector('.item-content--weekly').getBoundingClientRect()
          const frame = row.querySelector('.item-media-frame').getBoundingClientRect()
          const link = row.querySelector('.item-media-original').getBoundingClientRect()
          return { complete: image.complete, top: frame.top, contentLeft: content.left, contentRight: content.right,
            frameWidth: frame.width, linkLeft: link.left, linkRight: link.right, linkWidth: link.width }
        })()
      JS
      assert_not geometry.fetch("complete"), "图片应仍在视口外等待加载：#{geometry}"
      assert_operator geometry.fetch("top"), :>, 700
      assert_operator geometry.fetch("linkWidth"), :>=, 44
      assert_operator geometry.fetch("linkLeft"), :>=, geometry.fetch("contentLeft") - 0.5, "#{width}px: #{geometry}"
      assert_operator geometry.fetch("linkRight"), :<=, geometry.fetch("contentRight") + 0.5, "#{width}px: #{geometry}"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

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
        assert_selector("#item-#{item.id} .item-media img", visible: :all) { |image| image.evaluate_script("this.complete && this.naturalWidth > 0") }
        assert_equal %w[p img p], row.all(".item-content--weekly p, .item-media img", visible: :all).map(&:tag_name)
        original = row.find("a.item-media-original")
        assert_equal "查看历史图片顺序配图的原图（新标签页）", original["aria-label"]
        assert_equal image_url, original[:href]
        geometry = original.evaluate_script(<<~JS)
          (() => {
            const link = this.getBoundingClientRect(), image = this.closest('figure').querySelector('img').getBoundingClientRect()
            const next = this.closest('.item-media').nextElementSibling.getBoundingClientRect()
            const content = this.closest('.item-content--weekly').getBoundingClientRect()
            return { width: link.width, height: link.height, imageBottom: image.bottom, linkTop: link.top, linkBottom: link.bottom, nextTop: next.top,
              linkLeft: link.left, linkRight: link.right, imageRight: image.right, contentLeft: content.left, contentRight: content.right, imageWidth: image.width }
          })()
        JS
        assert_operator geometry.fetch("width"), :>=, 44
        assert_operator geometry.fetch("height"), :>=, 44
        assert_operator geometry.fetch("linkTop"), :>=, geometry.fetch("imageBottom") - 0.5
        assert_operator geometry.fetch("nextTop"), :>=, geometry.fetch("linkBottom")
        assert_operator geometry.fetch("linkLeft"), :>=, geometry.fetch("contentLeft") - 0.5
        assert_operator geometry.fetch("linkRight"), :<=, geometry.fetch("contentRight") + 0.5
        assert_in_delta geometry.fetch("imageRight"), geometry.fetch("linkRight"), 0.5 if geometry.fetch("imageWidth") >= 44
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

  test "同一段落的多张图各有可触达的原图入口，不盖住图与后文" do
    sign_in_with_browser(users(:drew))
    issue = issues(:weekly_w36)
    source = sources(:ruanyf)
    image_base = "http://127.0.0.1:#{Capybara.current_session.server.port}/icon.png"
    images = [ "#{image_base}?one", "#{image_base}?two" ]
    url = "https://example.com/multiple-images"
    item = issue.items.create!(source: source, title: "多图", rank: 2, section: "图片", url: url,
      url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current,
      content: "图片介绍。\n图片说明。", meta: { issue_no: 416, image_urls: images, image_positions: [ 1, 1 ] })
    ImageDimension.stubs(:enqueue_for)

    [ 320, 375, 768, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path(issue.period_key)
      row = find("#item-#{item.id}")
      links = row.all("a.item-media-original")
      assert_equal images, links.map { |link| link[:href] }
      links.each_with_index do |link, index|
        assert_equal "查看多图配图 #{index + 1}的原图（新标签页）", link["aria-label"]
        assert_equal "_blank", link[:target]
        assert_equal "noopener noreferrer", link[:rel]
        geometry = link.evaluate_script(<<~JS)
          (() => {
            const r = this.getBoundingClientRect(), image = this.closest('figure').querySelector('img').getBoundingClientRect()
            const after = this.closest('.item-media').nextElementSibling.getBoundingClientRect()
            return { width: r.width, height: r.height, top: r.top, bottom: r.bottom, imageBottom: image.bottom, afterTop: after.top }
          })()
        JS
        assert_operator geometry.fetch("width"), :>=, 44
        assert_operator geometry.fetch("height"), :>=, 44
        assert_operator geometry.fetch("top"), :>=, geometry.fetch("imageBottom") - 0.5
        assert_operator geometry.fetch("afterTop"), :>=, geometry.fetch("bottom")
      end
      if width <= 767
        assert_operator links[1].evaluate_script("this.closest('figure').getBoundingClientRect().top"), :>=, links[0].evaluate_script("this.getBoundingClientRect().bottom")
      end
      if width == 1440
        execute_script("arguments[0].focus()", row.find(".item-title a"))
        page.driver.browser.switch_to.active_element.send_keys(:tab)
        assert_selector "#item-#{item.id} .item-mark:focus"
        page.driver.browser.switch_to.active_element.send_keys(:tab)
        assert_selector "#item-#{item.id} .item-media-original:focus"
        assert_equal "solid", evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
      end
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
