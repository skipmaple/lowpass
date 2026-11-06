require "application_system_test_case"

class PeriodFontStabilityTest < ApplicationSystemTestCase
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "三主题日周刊日期与说明不因正文中文字库迟到而移动" do
    sign_in_with_browser(users(:drew))
    observations = []
    %w[daybreak duet unfold].each do |theme|
      execute_script("localStorage.setItem('lowpass-theme', arguments[0])", theme)
      [ 320, 375, 1270, 1920 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 846, deviceScaleFactor: 1, mobile: false)
        [ daily_issue_path("2026-09-08"), weekly_issue_path("2026-W36") ].each do |path|
          visit path
          assert_selector ".calendar-date, .issue-head-date"
          assert_selector "link[rel=stylesheet][href*=fonts-#{theme}-content-]", visible: :all
          settle_fonts
          delay_content_fonts(theme)
          before = period_geometry
          execute_script("window.__periodContentFonts.disabled = false")
          settle_fonts
          after = period_geometry
          observations << { theme: theme, width: width, path: path, before: before, after: after }
        end
      end
    end

    puts "PERIOD_FONT_ARRIVAL #{observations.to_json}"
    observations.each do |row|
      %w[ text title stack ].each do |part|
        assert_operator row[:before][part]["width"], :>, 0, "#{row[:theme]} #{row[:width]}px #{part} 必须实际可见"
        %w[ x y width height ].each do |dimension|
          assert_in_delta row[:before][part][dimension], row[:after][part][dimension], 0.1,
            "#{row[:theme]} #{row[:width]}px #{row[:path]} #{part}.#{dimension}"
        end
      end
    end
  ensure
    execute_script("localStorage.removeItem('lowpass-theme')")
  end

  private
    def settle_fonts
      evaluate_async_script("document.fonts.ready.then(() => requestAnimationFrame(() => requestAnimationFrame(arguments[0])))")
    end

    def delay_content_fonts(theme)
      # 新字体把期头常用字与正文切片分开；模拟正文 CSS 晚到，期头小字库仍按 HTML 预加载。
      fonts = evaluate_script(<<~JS, theme)
        (() => {
          const link = document.querySelector(`link[rel="stylesheet"][href*="fonts-${arguments[0]}-content-"]`)
          if (!link) return 0
          const count = [...link.sheet.cssRules].filter(rule => rule.type === CSSRule.FONT_FACE_RULE).length
          window.__periodContentFonts = link
          link.disabled = true
          return count
        })()
      JS
      assert_operator fonts, :>, 0, "必须实际延迟当前主题的正文字库：#{evaluate_script("[document.documentElement.dataset.theme, ...document.querySelectorAll(\"link[rel=stylesheet]\")].map(link => link.href || link)").inspect}"
      evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
    end

    def period_geometry
      evaluate_script(<<~JS)
        (() => {
          const title = [...document.querySelectorAll('.calendar-date, .issue-head-date')].find(node => node.getClientRects().length)
          const walker = document.createTreeWalker(title, NodeFilter.SHOW_TEXT)
          const range = document.createRange()
          range.selectNodeContents(walker.nextNode())
          return {
            text: range.getBoundingClientRect().toJSON(),
            title: title.getBoundingClientRect().toJSON(),
            stack: [...document.querySelectorAll('.calendar-meta > span, .issue-head-stack')].find(node => node.getClientRects().length).getBoundingClientRect().toJSON()
          }
        })()
      JS
    end
end
