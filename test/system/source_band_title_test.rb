require "application_system_test_case"

# 真实周刊来源横带：已载入文楷后量文字行，避免只检查 CSS 属性却漏掉末行孤字。
class SourceBandTitleTest < ApplicationSystemTestCase
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "周刊来源标题在 320px 不剩末行孤字，375px 仍完整单行" do
    original_url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md"
    issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: "科技爱好者周刊（第 366 期）：慢下来的理由", rank: 1,
      url: original_url, url_hash: Digest::SHA256.hexdigest(original_url), fetched_at: Time.current,
      meta: { issue_no: 366, issue_title: "慢下来的理由", degraded: true }
    )
    sign_in_with_browser(users(:drew))

    [ 375, 320 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit weekly_issue_path("2026-W36")
      assert_selector ".source-band-title", text: sources(:ruanyf).name
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      layout = source_title_layout

      assert_equal sources(:ruanyf).name, layout.fetch("text"), "#{width}px：来源名完整"
      assert_equal "20px", layout.fetch("fontSize"), "#{width}px：保留既有字号"
      assert_operator layout.fetch("overflow"), :<=, 0, "#{width}px：页面不横向溢出"
      if width == 375
        assert_equal [ sources(:ruanyf).name ], layout.fetch("lines"), "375px：原标题仍为一行"
      else
        assert_operator layout.fetch("lines").length, :>, 1, "320px：在原有可用宽度内自然换行"
        assert_operator layout.fetch("lines").last.length, :>=, 2, "320px：来源标题末行不能只剩一个汉字（#{layout.fetch('lines').inspect}）"
      end
      assert_selector ".source-band-issue", text: "第 366 期 · 慢下来的理由"
      assert_selector ".source-band-link[href='#{original_url}'][target='_blank']", text: "原文"
    end
  end

  test "周刊原文链接打印为墨色，切回屏幕仍为纸色" do
    original_url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md"
    issues(:weekly_w36).items.create!(
      source: sources(:ruanyf), title: "科技爱好者周刊（第 366 期）：慢下来的理由", rank: 1,
      url: original_url, url_hash: Digest::SHA256.hexdigest(original_url), fetched_at: Time.current,
      meta: { issue_no: 366, issue_title: "慢下来的理由", degraded: true }
    )
    sign_in_with_browser(users(:drew))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    visit weekly_issue_path("2026-W36")
    assert_selector ".source-band-title", text: sources(:ruanyf).name
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
    assert_equal "rgb(232, 227, 218)", states.fetch("screen").fetch("band"), diagnostic

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

  private
    def source_band_colors
      evaluate_script(<<~JS)
        (() => {
          const band = document.querySelector('.source-band')
          const link = band.querySelector('.source-band-link')
          return {
            print: matchMedia('print').matches,
            screen: matchMedia('screen').matches,
            band: getComputedStyle(band).color,
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
            overflow: document.documentElement.scrollWidth - innerWidth,
          }
        })()
      JS
    end
end
