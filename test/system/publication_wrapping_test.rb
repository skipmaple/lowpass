require "application_system_test_case"

# T2：实际页面、实际字体和逐字行框；不以 CSS 属性或整体无溢出代替断行验收。
class PublicationWrappingTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 23, 4)
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "https://avatars.example/drew.png" ])
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
  end

  test "320px 周刊来源副标题保留全文且末行不剩非字" do
    weekly("2026-W43", 416, "编程已经面目全非", count: 32)
    sign_in_with_browser(users(:drew))
    render_page weekly_issue_path("2026-W43"), width: 320, target: ".source-band-issue"

    layout = text_layout(".source-band-issue")
    assert_equal "第 416 期 · 编程已经面目全非", layout.fetch("text")
    assert_equal [ "15px" ], layout.fetch("fontSizes")
    assert_no_orphan layout
    assert layout.fetch("lines").any? { |line| line.include?("编程已经面目全非") },
      "主题能放进一行时，不应把编程拆到期号两边：#{layout.fetch('lines').inspect}"
    assert_selector ".source-band-link[href='https://github.com/ruanyf/weekly/blob/master/docs/issue-416.md']"
  end

  test "320px 来源副标题的长主题有界折行且期号与主题文字原样" do
    title = "完整技术主题" * 8 + " " + "W" * 80
    issue = weekly("2026-W43", 416, title, count: 1)
    sign_in_with_browser(users(:drew))
    render_page weekly_issue_path("2026-W43"), width: 320, target: ".source-band-issue"
    layout = text_layout(".source-band-issue")
    assert_equal "第 416 期 · #{title}", layout.fetch("text")
    assert_no_overflow layout
    assert_operator layout.fetch("lines").length, :>, 2

    [ nil, "用 Rust · 组织工具" ].each do |theme|
      issue.items.first!.update!(meta: { issue_no: 416, issue_title: theme })
      render_page weekly_issue_path("2026-W43"), width: 320, target: ".source-band-issue"
      layout = text_layout(".source-band-issue")
      assert_equal [ "第 416 期", theme ].compact.join(" · "), layout.fetch("text")
      assert_no_overflow layout
    end
  end

  test "375px 日归档的源名与计数在同一行且分隔符不独行" do
    %w[ 2026-10-21 2026-10-22 2026-10-23 ].each do |key|
      daily(key, github: key.end_with?("23") ? 9 : 10)
    end
    sign_in_with_browser(users(:drew))
    render_page daily_issues_path(month: "2026-10"), width: 375, target: ".archive-meta"

    %w[ 2026-10-23 2026-10-22 2026-10-21 ].each do |key|
      layout = text_layout(".archive-row[href='#{daily_issue_path(key)}'] .archive-meta")
      count = key.end_with?("23") ? 9 : 10
      assert_equal "Hacker News 10 · GitHub Trending #{count} · Hackaday 7", layout.fetch("text")
      assert layout.fetch("lines").any? { |line| line.delete(" ").include?("Hackaday7") },
        "#{key}：来源与数量应在同一行；#{layout.fetch('lines').inspect}"
      assert layout.fetch("lines").none? { |line| line.delete(" ") == "·" }, layout.inspect
      assert layout.fetch("lines").none? { |line| line.match?(/·\S/) },
        "同一行的分隔点后仍保留空格：#{layout.fetch('lines').inspect}"
      assert_match(/Maple/, layout.fetch("glyphs").last.fetch("family"))
      assert_match(/Newsreader/, layout.fetch("glyphs")[-2].fetch("family"))
      assert_no_overflow layout
    end
  end

  [
    [ "2026-W43", 416, "编程已经面目全非", 32, 320 ],
    [ "2026-W41", 414, "Jev 决策模型有什么用", 40, 1024 ]
  ].each do |key, number, title, count, width|
    test "#{width}px 周刊归档主题 #{title} 末行不剩单字" do
      weekly(key, number, title, count: count)
      sign_in_with_browser(users(:drew))
      render_page weekly_issues_path(year: "2026"), width: width, target: ".archive-label"

      layout = text_layout(".archive-row[href='#{weekly_issue_path(key)}'] .archive-label")
      assert_equal "阮一峰科技爱好者周刊 第 #{number} 期 · #{title}", layout.fetch("text")
      assert_equal [ "20px" ], layout.fetch("fontSizes")
      assert_no_orphan layout
    end
  end

  test "320px 周归档的日期单位不拆开且保留原字串" do
    weekly("2026-W41", 414, "Jev 决策模型有什么用", count: 40)
    sign_in_with_browser(users(:drew))
    render_page weekly_issues_path(year: "2026"), width: 320, target: ".archive-sub"

    assert_date_units "2026-W41", "10月5日 至 10月11日"
    assert_date_units "2026-W40", "9月28日 至 10月4日"
  end

  test "长来源状态和跨年日期完整可读且不横向溢出" do
    issue = daily("2026-10-23")
    issue.update!(source_states: { sources(:hn).id => "empty", sources(:github).id => "failed", sources(:hackaday).id => "no_backfill" })
    sign_in_with_browser(users(:drew))
    [ ("超长技术来源" * 8 + "UnbrokenTechnicalPublicationName!").first(80), "W" * 80, ("Long Technical Source " * 4).first(80) ].each do |name|
      sources(:hackaday).update!(name: name)
      render_page daily_issues_path(month: "2026-10"), width: 320, target: ".archive-meta"
      layout = text_layout(".archive-row[href='#{daily_issue_path('2026-10-23')}'] .archive-meta")
      assert_equal "Hacker News 0 · GitHub Trending 失败 · #{name} 无法回填", layout.fetch("text")
      assert layout.fetch("lines").none? { |line| line.delete(" ") == "·" }, layout.inspect
      assert_no_overflow layout
    end

    travel_to Time.utc(2027, 1, 3, 4)
    sign_in_with_browser(users(:drew))
    render_page weekly_issues_path(year: "2026"), width: 320, target: ".archive-sub"
    assert_date_units "2026-W53", "12月28日 至 1月3日"
  end

  test "来源与归档在十个宽度和相邻断点保留完整阅读单位" do
    weekly("2026-W43", 416, "编程已经面目全非", count: 32)
    weekly("2026-W41", 414, "Jev 决策模型有什么用", count: 40)
    combined = weekly("2026-W38", 412, "禁止 issue，只用 PR", count: 34)
    add_items combined, sources(:ruanyf), 31, section: "文章", meta: { issue_no: 413, issue_title: "再见了，React Native" }
    daily("2026-10-23")
    sign_in_with_browser(users(:drew))

    [ 320, 375, 390, 481, 600, 767, 768, 1023, 1024, 1440, 1920, 2560 ].each do |width|
      render_page weekly_issue_path("2026-W43"), width: width, target: ".source-band-issue"
      issue_label = text_layout(".source-band-issue")
      assert_no_orphan issue_label
      assert issue_label.fetch("lines").any? { |line| line.include?("编程已经面目全非") },
        "#{width}px：可放下的主题保留为阅读单位；#{issue_label.fetch('lines').inspect}"

      render_page daily_issues_path(month: "2026-10"), width: width, target: ".archive-meta"
      sources = text_layout(".archive-row[href='#{daily_issue_path('2026-10-23')}'] .archive-meta")
      %w[ HackerNews10 GitHubTrending9 Hackaday7 ].each do |unit|
        assert sources.fetch("lines").any? { |line| line.delete(" ").include?(unit) },
          "#{width}px：#{unit} 同行；#{sources.fetch('lines').inspect}"
      end
      assert_no_overflow sources

      render_page weekly_issues_path(year: "2026"), width: width, target: ".archive-label"
      %w[ 2026-W43 2026-W41 2026-W38 ].each do |key|
        assert_no_orphan text_layout(".archive-row[href='#{weekly_issue_path(key)}'] .archive-label")
      end
      assert_date_units "2026-W41", "10月5日 至 10月11日"
      assert_date_units "2026-W40", "9月28日 至 10月4日"
    end
  end

  private
    def weekly(key, number, title, count:)
      date = PeriodKey.week_range(key).first + 4
      stamp = Time.zone.local(date.year, date.month, date.day, 9)
      issue = Issue.create!(kind: "weekly", period_key: key, state: "published", published_at: stamp,
        generation_started_at: stamp, source_states: { sources(:ruanyf).id => "ok" })
      add_items issue, sources(:ruanyf), count, section: "文章", meta: { issue_no: number, issue_title: title }
      issue
    end

    def daily(key, github: 9)
      date = Date.iso8601(key)
      stamp = Time.zone.local(date.year, date.month, date.day, 6)
      issue = Issue.create!(kind: "daily", period_key: key, state: "published", published_at: stamp,
        generation_started_at: stamp, source_states: %i[ hn github hackaday ].index_with { "ok" }.transform_keys { |name| sources(name).id })
      { hn: 10, github: github, hackaday: 7 }.each { |name, count| add_items issue, sources(name), count }
      issue
    end

    def add_items(issue, source, count, section: nil, meta: {})
      offset = issue.items.where(source: source).count
      count.times do |index|
        rank = offset + index + 1
        url = "https://example.test/#{issue.period_key}/#{source.id}/#{rank}"
        issue.items.create!(source: source, title: "Frozen article #{rank}", rank: rank, section: section,
          url: url, url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current, meta: meta)
      end
    end

    def render_page(path, width:, target:)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit path
      assert_selector target
      evaluate_async_script(<<~JS)
        const done = arguments[0]
        const nodes = [...document.querySelectorAll(#{target.to_json})].flatMap(element => [element, ...element.querySelectorAll('span')])
        Promise.all(nodes.map(element => document.fonts.load(getComputedStyle(element).font, element.textContent)))
          .then(() => document.fonts.ready)
          .then(() => Promise.all(document.getAnimations().map(animation => animation.finished.catch(() => {}))))
          .then(() => requestAnimationFrame(() => requestAnimationFrame(done)))
      JS
      if directory = ENV["WRAP_EVIDENCE_DIR"]
        FileUtils.mkdir_p(directory)
        @render_sequence = (@render_sequence || 0) + 1
        @evidence_key = "#{Digest::SHA256.hexdigest(name).first(10)}-#{@render_sequence}-#{width}"
        page.save_screenshot(File.join(directory, "#{@evidence_key}.png"))
        File.open(File.join(directory, "index.jsonl"), "a") { |file| file.puts({ key: @evidence_key, test: name, path: path, width: width }.to_json) }
      end
    end

    def text_layout(selector)
      layout = evaluate_script(<<~JS)
        (() => {
          const element = document.querySelector(#{selector.to_json}), lines = [], glyphs = []
          const bounds = element.getBoundingClientRect()
          const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT)
          const segmenter = new Intl.Segmenter('zh', { granularity: 'grapheme' })
          for (let node; (node = walker.nextNode());) {
            for (const {segment, index} of segmenter.segment(node.data)) {
              const range = document.createRange()
              range.setStart(node, index)
              range.setEnd(node, index + segment.length)
              const rect = range.getBoundingClientRect()
              if (rect.width === 0) continue
              const center = (rect.top + rect.bottom) / 2
              let line = lines.find(line => Math.abs(line.center - center) < 7.5)
              if (!line) { line = {center, text: ''}; lines.push(line) }
              line.text += segment
              if (segment.trim()) glyphs.push({text: segment, center, left: rect.left, right: rect.right, family: getComputedStyle(node.parentElement).fontFamily})
            }
          }
          return {
            text: element.textContent.trim(), lines: lines.sort((a, b) => a.center - b.center).map(line => line.text.trim()),
            glyphs, fontSizes: [...new Set([element, ...element.querySelectorAll('span')].filter(element => element.childNodes.length && [...element.childNodes].some(node => node.nodeType === Node.TEXT_NODE && node.data.trim())).map(element => getComputedStyle(element).fontSize))],
            overflow: document.documentElement.scrollWidth - innerWidth,
            glyphOverflow: glyphs.some(glyph => glyph.left < bounds.left - 1 || glyph.right > bounds.right + 1),
            fontStatus: document.fonts.status,
            wenkaiLoaded: [...document.fonts].some(face => face.family.includes('LXGW') && face.status === 'loaded'),
          }
        })()
      JS
      if directory = ENV["WRAP_EVIDENCE_DIR"]
        File.write(File.join(directory, "#{@evidence_key}-#{Digest::SHA256.hexdigest(selector).first(8)}.json"), layout.merge(selector: selector).to_json)
      end
      layout
    end

    def assert_no_orphan(layout)
      assert_operator layout.fetch("lines").last.scan(/\X/).length, :>=, 2,
        "实际末行不能只剩一个字：#{layout.fetch('lines').inspect}"
      if layout.fetch("lines").length > 1 && layout.fetch("lines").last.match?(/\A[\p{Latin}\p{Punct}\s]+\z/)
        assert_operator layout.fetch("lines").last.scan(/\p{Latin}+/).length, :>=, 2,
          "实际标题末行不能只剩一个英文词：#{layout.fetch('lines').inspect}"
      end
      assert_no_overflow layout
    end

    def assert_date_units(key, expected)
      layout = text_layout(".archive-row[href='#{weekly_issue_path(key)}'] .archive-sub")
      assert_equal expected, layout.fetch("text")
      assert_equal [ "15px" ], layout.fetch("fontSizes")
      expected.split(" 至 ").each do |date|
        assert layout.fetch("lines").any? { |line| line.include?(date) },
          "#{key} 的 #{date} 不应拆开；#{layout.fetch('lines').inspect}"
      end
      assert_not_includes layout.fetch("lines"), "至"
      assert_no_overflow layout
    end

    def assert_no_overflow(layout)
      diagnostic = layout.slice("text", "lines", "overflow", "glyphOverflow").inspect
      assert_operator layout.fetch("overflow"), :<=, 0, "视口内显示完整：#{diagnostic}"
      assert_not layout.fetch("glyphOverflow"), "文字不能越出自身的布局框：#{diagnostic}"
      assert_equal "loaded", layout.fetch("fontStatus")
      assert layout.fetch("wenkaiLoaded"), "实际文楷 face 已加载"
    end
end
