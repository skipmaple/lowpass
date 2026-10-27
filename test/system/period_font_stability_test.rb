require "application_system_test_case"

class PeriodFontStabilityTest < ApplicationSystemTestCase
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "日周刊的日期与说明在普通字库迟到时保持位置" do
    sign_in_with_browser(users(:drew))
    observations = []
    [ 320, 375, 1270, 1920 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 846, deviceScaleFactor: 1, mobile: false)
      [ daily_issue_path("2026-09-08"), weekly_issue_path("2026-W36") ].each do |path|
        visit path
        assert_selector ".issue-head-date"
        settle_fonts
        delay_ordinary_fonts
        before = period_geometry
        release_font("Maple Mono NL")
        after_data = period_geometry
        release_font("LXGW WenKai Screen")
        after_ui = period_geometry
        observations << { width: width, path: path, before: before, after_data: after_data, after_ui: after_ui }
      end
    end

    puts "PERIOD_FONT_ARRIVAL #{observations.to_json}"
    observations.each do |row|
      [ :after_data, :after_ui ].each do |phase|
        %w[ text title stack ].each do |part|
          %w[ x y width height ].each do |dimension|
            assert_in_delta row[:before][part][dimension], row[phase][part][dimension], 0.1,
              "#{row[:width]}px #{row[:path]} #{phase} #{part}.#{dimension}"
          end
        end
      end
    end
  end

  private
    def settle_fonts
      evaluate_async_script("document.fonts.ready.then(() => requestAnimationFrame(() => requestAnimationFrame(arguments[0])))")
    end

    def delay_ordinary_fonts
      fonts = evaluate_script(<<~'JS')
        (() => {
          const ui = document.querySelector('link[as="font"][href*="lxgw-wenkai-screen-ui-"]').href
          window.__ordinaryPeriodFonts = {}
          const candidates = []
          for (const sheet of document.styleSheets) {
            if (!sheet.href || !sheet.href.startsWith(location.origin)) continue
            for (let i = sheet.cssRules.length - 1; i >= 0; i--) {
              const rule = sheet.cssRules[i]
              if (rule.type !== CSSRule.FONT_FACE_RULE) continue
              const family = rule.style.getPropertyValue('font-family').replace(/["']/g, '')
              if (!['LXGW WenKai Screen', 'Maple Mono NL'].includes(family)) continue
              const src = rule.style.getPropertyValue('src')
              if (src.includes('data:') || !src.includes('url(')) continue
              const path = /url\(["']?([^"')]+)["']?\)/.exec(src)[1]
              const url = new URL(path, sheet.href).href
              candidates.push({ family, url })
              if (url === ui || family === 'Maple Mono NL') {
                window.__ordinaryPeriodFonts[family] = { url, range: rule.style.getPropertyValue('unicode-range') }
              }
              sheet.deleteRule(i)
            }
          }
          return { fonts: Object.keys(window.__ordinaryPeriodFonts).sort(), ui, candidates }
        })()
      JS
      puts "PERIOD_FONT_SOURCES #{fonts.to_json}" unless fonts["fonts"].length == 2
      assert_equal [ "LXGW WenKai Screen", "Maple Mono NL" ], fonts["fonts"]
      evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
    end

    def release_font(family)
      result = evaluate_async_script(<<~JS, family)
        const done = arguments[arguments.length - 1]
        const source = window.__ordinaryPeriodFonts[arguments[0]]
        const face = new FontFace(arguments[0], `url('${source.url}')`, { weight: '400', unicodeRange: source.range })
        face.load().then(() => {
          document.fonts.add(face)
          requestAnimationFrame(() => requestAnimationFrame(() => done(true)))
        }).catch(error => done({ error: error.message }))
      JS
      assert_equal true, result
    end

    def period_geometry
      evaluate_script(<<~JS)
        (() => {
          const title = document.querySelector('.issue-head-date')
          const walker = document.createTreeWalker(title, NodeFilter.SHOW_TEXT)
          const range = document.createRange()
          range.selectNodeContents(walker.nextNode())
          return {
            text: range.getBoundingClientRect().toJSON(),
            title: title.getBoundingClientRect().toJSON(),
            stack: document.querySelector('.issue-head-stack').getBoundingClientRect().toJSON()
          }
        })()
      JS
    end
end
