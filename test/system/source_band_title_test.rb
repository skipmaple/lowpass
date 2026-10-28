require "application_system_test_case"

# 真实周刊阅读标题：已载入文楷后量文字行，避免只检查 CSS 属性却漏掉末行孤字。
class SourceBandTitleTest < ApplicationSystemTestCase
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "降级周刊原文标题在手机不留末行孤字且外链箭头独立" do
    original_url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md"
    title = "科技爱好者周刊（第 366 期）：慢下来的理由"
    issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: title, rank: 1,
      url: original_url, url_hash: Digest::SHA256.hexdigest(original_url), fetched_at: Time.current,
      meta: { issue_no: 366, issue_title: "慢下来的理由", degraded: true }
    )
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "https://avatars.example/drew.png" ])
    sign_in_with_browser(users(:drew))

    [ 390, 320, 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path("2026-W36")
      assert_selector ".source-state .source-foot", text: title
      evaluate_async_script(<<~JS)
        const done = arguments[0], title = document.querySelector('.source-state .source-foot > span')
        Promise.all([...title.querySelectorAll('span')].map(run => document.fonts.load(getComputedStyle(run).font, run.textContent)))
          .then(() => document.fonts.ready).then(() => requestAnimationFrame(() => requestAnimationFrame(done)))
      JS
      layout = degraded_title_layout

      assert_equal title, layout.fetch("text"), "#{width}px：保留完整原文标题"
      assert_equal original_url, layout.fetch("href"), "#{width}px：保留原文地址"
      assert_equal "_blank", layout.fetch("target"), "#{width}px：保留新窗口操作"
      assert_includes layout.fetch("rel").split, "noopener"
      assert_includes layout.fetch("rel").split, "noreferrer"
      assert_operator layout.fetch("lines").last.fetch("text").scan(/\X/).length, :>=, 2,
        "#{width}px：原标题末行不能只剩一个字（#{layout.fetch('lines').map { |line| line.fetch('text') }.inspect}）"
      assert_operator layout.fetch("overflow"), :<=, 0, "#{width}px：页面不横向溢出"
      assert_operator layout.fetch("linkHeight"), :>=, 44, "#{width}px：保留44px点击区"
      assert layout.fetch("arrowSeparate"), "#{width}px：箭头不侵占标题文字"
      assert layout.fetch("arrowInsideLink"), "#{width}px：箭头仍在外链目标内"
    end
  ensure
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
  end

  test "周刊主题高于来源事实，窄屏完整换行且不留末行孤字" do
    original_url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md"
    theme = "在复杂的工程系统里慢下来的理由"
    issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: "科技爱好者周刊（第 366 期）：#{theme}", rank: 1,
      url: original_url, url_hash: Digest::SHA256.hexdigest(original_url), fetched_at: Time.current,
      meta: { issue_no: 366, issue_title: theme, degraded: true }
    )
    sign_in_with_browser(users(:drew))

    [ 320, 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path("2026-W36")
      assert_selector "h2.source-band-title", text: theme
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      layout = source_title_layout

      assert_equal theme, layout.fetch("text"), "#{width}px：主题完整"
      assert_operator layout.fetch("fontSize").to_f, :>, layout.fetch("metaFontSize").to_f, "#{width}px：主题高于来源事实"
      assert_operator layout.fetch("overflow"), :<=, 0, "#{width}px：页面不横向溢出"
      assert_operator layout.fetch("lines").last.length, :>=, 2, "#{width}px：主题末行不能只剩一个汉字（#{layout.fetch('lines').inspect}）"
      assert_selector ".source-band-meta", text: sources(:ruanyf).name
      assert_selector ".source-band-issue", text: "第 366 期"
      assert_selector ".source-band-link[href='#{original_url}'][target='_blank']", text: "原文"
    end
  end

  test "周刊原文链接在屏幕与打印均跟随墨色，屏幕保留透明纸面" do
    original_url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md"
    issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: "科技爱好者周刊（第 366 期）：慢下来的理由", rank: 1,
      url: original_url, url_hash: Digest::SHA256.hexdigest(original_url), fetched_at: Time.current,
      meta: { issue_no: 366, issue_title: "慢下来的理由", degraded: true }
    )
    sign_in_with_browser(users(:drew))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    visit weekly_issue_path("2026-W36")
    assert_selector ".source-band-title", text: "慢下来的理由"
    assert_selector ".source-band-link[href='#{original_url}'][target='_blank']", text: "原文"
    evaluate_async_script("document.fonts.ready.then(arguments[0])")

    states = {}
    [ "print", "screen" ].each do |media|
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: media)
      evaluate_async_script("const done = arguments[0]; requestAnimationFrame(() => requestAnimationFrame(() => done()))")
      evaluate_async_script("const done = arguments[0]; Promise.all(document.querySelector('.source-band-link').getAnimations().map(animation => animation.finished)).then(() => done())")
      states[media] = source_band_colors
    end
    diagnostic = "实际媒体与颜色 #{states.to_json}"
    assert_equal [ true, false ], states.fetch("print").values_at("print", "screen"), diagnostic
    assert_equal [ false, true ], states.fetch("screen").values_at("print", "screen"), diagnostic
    assert_equal "rgb(29, 29, 27)", states.fetch("print").fetch("band"), diagnostic
    assert_equal "rgb(29, 29, 27)", states.fetch("screen").fetch("band"), diagnostic
    assert_equal "rgba(0, 0, 0, 0)", states.fetch("screen").fetch("background"), diagnostic

    states.each do |media, state|
      expected = state.fetch("band")
      assert_equal expected, state.fetch("link"), "#{media}：原文链接自身应跟随横带颜色；#{diagnostic}"
      assert_equal expected, state.fetch("text"), "#{media}：原文文字应跟随横带颜色；#{diagnostic}"
      assert_operator state.fetch("pathStrokes").length, :>, 0, "#{media}：应测量真实箭头 path；#{diagnostic}"
      state.fetch("pathStrokes").each do |stroke|
        assert_equal expected, stroke, "#{media}：实际箭头 path stroke 应跟随横带颜色；#{diagnostic}"
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  test "有主题时100字符英文来源名完整换行并保留语言标识" do
    source_name = "unbrokenweeklysource" * 5
    sources(:ruanyf).update!(name: source_name)
    original_url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md"
    issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: "慢下来的理由", rank: 1,
      url: original_url, url_hash: Digest::SHA256.hexdigest(original_url), fetched_at: Time.current,
      meta: { issue_no: 366, issue_title: "慢下来的理由" }
    )
    sign_in_with_browser(users(:drew))

    [ 320, 375 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path("2026-W36")
      assert_selector "h2.source-band-title", text: "慢下来的理由"
      assert_selector ".source-band-source[lang='en']", text: source_name
      evaluate_async_script(<<~JS)
        const done = arguments[0], source = document.querySelector('.source-band-source')
        Promise.all([...source.querySelectorAll('span')].map(run => document.fonts.load(getComputedStyle(run).font, run.textContent)))
          .then(() => document.fonts.ready).then(() => requestAnimationFrame(() => requestAnimationFrame(done)))
      JS
      layout = evaluate_script(<<~JS)
        (() => {
          const source = document.querySelector('.source-band-source'), box = source.getBoundingClientRect()
          const walker = document.createTreeWalker(source, NodeFilter.SHOW_TEXT), lines = []
          for (let node; (node = walker.nextNode());) {
            const range = document.createRange(); range.selectNodeContents(node)
            lines.push(...Array.from(range.getClientRects()).filter(rect => rect.width > 0))
          }
          return { text: source.textContent, overflow: document.documentElement.scrollWidth - innerWidth,
            lineCount: lines.length,
            contained: lines.every(rect => rect.left >= box.left - 1 && rect.right <= box.right + 1) }
        })()
      JS

      assert_equal source_name, layout.fetch("text"), "#{width}px：来源名不能截断或省略"
      assert_operator layout.fetch("lineCount"), :>, 1, "#{width}px：长来源名应实际换行"
      assert layout.fetch("contained"), "#{width}px：每行字形应完整留在来源区域内"
      assert_operator layout.fetch("overflow"), :<=, 0, "#{width}px：长来源名不能撑出页面"
    end
  end

  private
    def degraded_title_layout
      evaluate_script(<<~JS)
        (() => {
          const link = document.querySelector('.source-state .source-foot'), title = link.querySelector(':scope > span')
          const arrow = link.querySelector(':scope > svg'), lines = [], glyphs = []
          const walker = document.createTreeWalker(title, NodeFilter.SHOW_TEXT)
          const segmenter = new Intl.Segmenter('zh', { granularity: 'grapheme' })
          for (let node; (node = walker.nextNode());) {
            for (const { segment, index } of segmenter.segment(node.data)) {
              const range = document.createRange()
              range.setStart(node, index)
              range.setEnd(node, index + segment.length)
              const r = range.getBoundingClientRect()
              if (!segment.trim() || r.width === 0) continue
              const center = (r.top + r.bottom) / 2
              let line = lines.find(line => Math.abs(line.center - center) < 7.5)
              if (!line) {
                line = { center, text: '' }
                lines.push(line)
              }
              line.text += segment
              glyphs.push({ text: segment, left: r.left, right: r.right, top: r.top, bottom: r.bottom })
            }
          }
          const a = arrow.getBoundingClientRect(), t = title.getBoundingClientRect(), r = link.getBoundingClientRect()
          return {
            width: innerWidth, text: title.textContent.trim(), href: link.href, target: link.target, rel: link.rel,
            lines: lines.sort((a, b) => a.center - b.center), glyphs,
            overflow: document.documentElement.scrollWidth - innerWidth, linkHeight: r.height,
            arrowSeparate: a.left >= t.right && glyphs.every(glyph => glyph.right <= a.left),
            arrowInsideLink: a.left >= r.left && a.right <= r.right && a.top >= r.top && a.bottom <= r.bottom,
          }
        })()
      JS
    end

    def source_band_colors
      evaluate_script(<<~JS)
        (() => {
          const band = document.querySelector('.source-band')
          const link = band.querySelector('.source-band-link')
          return {
            print: matchMedia('print').matches,
            screen: matchMedia('screen').matches,
            band: getComputedStyle(band).color,
            background: getComputedStyle(band).backgroundColor,
            link: getComputedStyle(link).color,
            text: getComputedStyle(link.querySelector('span')).color,
            pathStrokes: [...link.querySelectorAll('svg path')].map(path => getComputedStyle(path).stroke),
          }
        })()
      JS
    end

    def source_title_layout
      evaluate_script(<<~JS)
        (() => {
          const title = document.querySelector('.source-band-title')
          const walker = document.createTreeWalker(title, NodeFilter.SHOW_TEXT), lines = []
          for (let node; (node = walker.nextNode());) {
            let offset = 0
            for (const character of node.data) {
              const range = document.createRange()
              range.setStart(node, offset)
              offset += character.length
              range.setEnd(node, offset)
              const rect = range.getBoundingClientRect()
              if (!character.trim() || rect.width === 0) continue
              let line = lines.find(line => Math.abs(line.top - rect.top) < 1)
              if (!line) {
                line = { top: rect.top, text: '' }
                lines.push(line)
              }
              line.text += character
            }
          }
          return {
            text: title.textContent.trim(),
            lines: lines.sort((a, b) => a.top - b.top).map(line => line.text),
            fontSize: getComputedStyle(title).fontSize,
            metaFontSize: getComputedStyle(document.querySelector('.source-band-meta')).fontSize,
            overflow: document.documentElement.scrollWidth - innerWidth,
          }
        })()
      JS
    end
end
