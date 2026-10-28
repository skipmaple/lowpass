require "application_system_test_case"

class DailyChaptersTest < ApplicationSystemTestCase
  WIDTHS = [ 320, 375, 481, 768, 1440, 1920, 2560 ].freeze
  INTERACTION_WIDTHS = [ 320, 375, 1440 ].freeze

  setup do
    issue = issues(:daily_0908)
    items(:hn_one).update!(published_at: 11.hours.ago - 15.minutes, title_zh: "用 Rust 制作终端日志查看器")
    [ sources(:github), sources(:hackaday) ].each do |source|
      url = "https://example.com/chapter/#{source.id}"
      Item.create!(issue: issue, source: source, title: source == sources(:github) ? "tools/readable-terminal" : "A repairable handheld computer",
        url: url, url_hash: Digest::SHA256.hexdigest(url), rank: 1, fetched_at: Time.current,
        summary: "A practical tool for reading and understanding technical systems.", summary_zh: "适合日常阅读和理解技术系统的工具。",
        reason: "可以直接查看实现，理解工具的工作方式。", meta: source == sources(:github) ? { language: "Rust", stars: 12345, stars_today: 312 } : {})
    end
    issue.update!(source_states: issue.source_states.transform_values { "ok" })
    sign_in_with_browser(users(:drew))
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "桌面与窄屏的全部章节保持原有暖纸与纸纹，普通和减少动态模式下正文都可读" do
    WIDTHS.each do |width|
      viewport(width)
      [ "no-preference", "reduce" ].each do |motion|
        page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: motion } ])
        visit daily_issue_path("2026-09-08")
        assert_selector ".daily-source", count: 3
        all(".daily-source").each do |section|
          colors = chapter_colors(section)
          context = "#{width}px #{motion} #{section[:id]}"
          assert_equal "rgb(232, 227, 218)", colors.fetch("surface"), "章节不得更换暖纸主色；#{context}"
          refute_equal "none", colors.fetch("texture"), "原有纸纹应继续存在；#{context}"
          colors.fetch("planes").each do |plane|
            transparent = plane.fetch("color") == "rgba(0, 0, 0, 0)"
            assert transparent || plane.fetch("image") == colors.fetch("texture"), "目录与章头不能用纯色层盖住纸纹；#{context} #{plane.inspect}"
          end
          assert_not_empty colors.fetch("text"), context
          colors.fetch("text").each do |entry|
            foreground = luminance(entry.fetch("color"))
            background = luminance(entry.fetch("background"))
            assert_operator contrast(foreground, background), :>=, 4.5, "正文与数字必须能读清；#{context} #{entry.inspect}"
          end
        end
        assert_no_horizontal_overflow
      end
    end
  end

  test "无边框图标收藏与评论同组，切换保留可访问名称与稳定命中区" do
    with_forgery_protection do
      INTERACTION_WIDTHS.each do |width|
        viewport(width)
        visit daily_issue_path("2026-09-08")
        row = find("#item-#{items(:hn_one).id}")
        assert_selector "#item-#{items(:hn_one).id} .item-meta time", text: "11 小时前提交"
        time = row.find("time")
        assert_includes time["aria-label"], "提交到 Hacker News"
        assert_includes time["title"], "Asia/Shanghai"
        assert_equal items(:hn_one).published_at.iso8601, time["datetime"]

        bookmark = row.find(".item-meta .favorite-button")
        execute_script("arguments[0].scrollIntoView({ block: 'center' })", bookmark)
        settle_frames
        assert_controls_independent(row, width)
        assert_equal "收藏：#{items(:hn_one).title}", bookmark["aria-label"]
        assert_nil bookmark["data-on"]
        before = bookmark_geometry(bookmark)
        assert_bookmark_layers(before, width)

        bookmark.click
        assert_selector "#item-#{items(:hn_one).id} .item-save[data-on]"
        assert_equal "取消收藏：#{items(:hn_one).title}", bookmark["aria-label"]
        wait_until { users(:drew).favorites.exists?(url_hash: items(:hn_one).url_hash) }
        wait_for_favorite_requests(1)
        wait_until { bookmark.evaluate_script("this.getAnimations().length === 0") }
        saved = bookmark_geometry(bookmark)
        assert_bookmark_layers(saved, width)
        %w[ x y width height ].each do |key|
          assert_in_delta before.fetch("button").fetch(key), saved.fetch("button").fetch(key), 0.5, "收藏切换不能移动命中区；#{width}px #{key}"
        end
        assert_controls_independent(row, width)

        bookmark.click
        assert_selector "#item-#{items(:hn_one).id} .item-save:not([data-on])"
        assert_equal "收藏：#{items(:hn_one).title}", bookmark["aria-label"]
        wait_until { users(:drew).favorites.where(url_hash: items(:hn_one).url_hash).empty? }
        wait_for_favorite_requests(2)
        assert_bookmark_layers(bookmark_geometry(bookmark), width)
        assert_no_horizontal_overflow
      end
    end
  end

  test "目录默认收起，展开后完整提供实际一二四个来源与状态" do
    issue = issues(:daily_0908)
    extra = Source.create!(name: "Technical Notes", adapter: "rss", publication: "daily", sort_order: 4,
      config: { feed_url: "https://notes.example/feed" })
    available = [ sources(:hn), sources(:github), sources(:hackaday), extra ]
    [ 320, 1440 ].each do |width|
      viewport(width)
      [ 1, 2, 4 ].each do |count|
        selected = available.first(count)
        issue.update!(source_states: selected.to_h { |source| [ source.id, source == extra ? "empty" : "ok" ] })
        visit daily_issue_path("2026-09-08")
        assert_selector "details.source-directory:not([open])"
        assert_no_selector "#source-directory", visible: true
        assert_selector ".daily-source", count: count
        assert_selector "#item-#{items(:hn_one).id} .item-title"
        summary = find("details.source-directory > summary", text: "来源目录")
        assert_operator summary.native.rect.height, :>=, 44
        summary.send_keys(:enter)
        assert_selector "details.source-directory[open]"
        links = all("#source-directory a.source-link", count: count)
        assert_equal selected.map { |source| "#source-#{source.id}" }, links.map { |link| "##{link[:href].split('#', 2).last}" }
        links.zip(selected).each do |link, source|
          assert_includes link.text, source.name
          assert_operator link.native.rect.height, :>=, 44
          assert_operator link.native.rect.width, :>=, 44
        end
        assert_selector "#source-directory", text: "本期无新内容" if count == 4
        rectangles = evaluate_script("[...document.querySelectorAll('#source-directory a.source-link')].map(link => link.getBoundingClientRect().toJSON())")
        rectangles.combination(2).each do |a, b|
          overlap = [ 0, [ a.fetch("right"), b.fetch("right") ].min - [ a.fetch("left"), b.fetch("left") ].max ].max *
            [ 0, [ a.fetch("bottom"), b.fetch("bottom") ].min - [ a.fetch("top"), b.fetch("top") ].max ].max
          assert_equal 0, overlap, "#{width}px：来源入口不能重叠"
        end
        assert_no_horizontal_overflow
      end
    end
  end

  test "来源标题与首条正文共享居中的阅读列，栏目开头没有额外空块" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    WIDTHS.each do |width|
      viewport(width)
      visit daily_issue_path("2026-09-08")
      assert_selector ".daily-source", count: 3
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      geometry = evaluate_script(<<~JS)
        (() => {
          const rect = element => element.getBoundingClientRect().toJSON();
          return { sheet: rect(document.querySelector('.sheet-body')),
            sources: [...document.querySelectorAll('.daily-source')].map(section => {
              const header = section.querySelector('.daily-source-head'), heading = section.querySelector('.print-source-name');
              const row = section.querySelector('.item-row'), body = row.querySelector('.item-body'), title = row.querySelector('.item-heading');
              return { section: rect(section), header: rect(header), heading: rect(heading), row: rect(row), body: rect(body), title: rect(title),
                titleLine: parseFloat(getComputedStyle(row.querySelector('.item-title')).lineHeight) };
            }) };
        })()
      JS
      geometry.fetch("sources").each do |source|
        column, header, heading, row, body, title = source.values_at("section", "header", "heading", "row", "body", "title")
        assert_in_delta width / 2.0, column.fetch("left") + column.fetch("width") / 2, 1, "#{width}px：阅读列居中"
        assert_in_delta heading.fetch("left"), body.fetch("left"), 1, "#{width}px：来源名与正文左缘一致"
        assert_in_delta column.fetch("left"), row.fetch("left"), 1, "#{width}px：条目与栏目同列"
        assert_in_delta column.fetch("right"), row.fetch("right"), 1, "#{width}px：条目与栏目同列"
        assert_in_delta header.fetch("bottom"), row.fetch("top"), 1, "#{width}px：栏首之后不插入空白块"
        assert_operator title.fetch("top") - heading.fetch("bottom"), :<=, source.fetch("titleLine"), "#{width}px：来源名与首条标题的留白不超过一行正文标题"
        assert_operator column.fetch("width"), :<, geometry.fetch("sheet").fetch("width") if width >= 1440
      end
      assert_no_horizontal_overflow
    end
  end

  test "时间保持可读的次级字号，不与标题和译文争抢层次" do
    WIDTHS.each do |width|
      viewport(width)
      visit daily_issue_path("2026-09-08")
      row = find("#item-#{items(:hn_one).id}")
      sizes = evaluate_script(<<~JS, row)
        (() => {
          const row = arguments[0], size = selector => parseFloat(getComputedStyle(row.querySelector(selector)).fontSize);
          return { time: size('.item-age'), title: size('.item-title'), translation: size('.item-translation') };
        })()
      JS
      assert_equal 12, sizes.fetch("time"), "#{width}px：时间应保持次级字号"
      assert_operator sizes.fetch("time"), :<, sizes.fetch("title"), "#{width}px"
      assert_operator sizes.fetch("time"), :<, sizes.fetch("translation"), "#{width}px"
      assert_no_selector "#item-#{items(:hn_one).id} .item-age svg"
    end
  end

  test "窄屏完整长作者名自然折行，不挤出正文或收藏" do
    author = "A" * 100
    item = Item.find_by!(issue: issues(:daily_0908), source: sources(:hackaday))
    item.update!(author: author)

    [ 320, 375 ].each do |width|
      viewport(width)
      visit daily_issue_path("2026-09-08")
      row = find("#item-#{item.id}")
      author_element = row.find(".item-meta span", text: author, exact_text: true)
      assert_equal author, author_element.text
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      geometry = evaluate_script(<<~JS, author_element, row)
        (() => {
          const author = arguments[0], body = arguments[1].querySelector('.item-body').getBoundingClientRect();
          const range = document.createRange(); range.selectNodeContents(author);
          return { body: body.toJSON(), lines: [...range.getClientRects()].filter(rect => rect.width > 0).map(rect => rect.toJSON()) };
        })()
      JS
      assert_operator geometry.fetch("lines").map { |line| line.fetch("top") }.uniq.size, :>, 1, "#{width}px：长作者名应完整折行"
      geometry.fetch("lines").each do |line|
        assert_operator line.fetch("left"), :>=, geometry.fetch("body").fetch("left") - 0.5, "#{width}px"
        assert_operator line.fetch("right"), :<=, geometry.fetch("body").fetch("right") + 0.5, "#{width}px：实际字形不能越出阅读列"
      end
      assert_bookmark_layers(bookmark_geometry(row.find(".item-save")), width)
      assert_no_horizontal_overflow
    end
  end

  test "章节目录保留原生 hash 和从栏目标题继续阅读的键盘路径" do
    WIDTHS.each do |width|
      viewport(width)
      visit daily_issue_path("2026-09-08")
      target = "source-#{sources(:github).id}"
      summary = find("details.source-directory > summary", text: "来源目录")
      summary.send_keys(:enter)
      assert_selector "details.source-directory[open]"
      find("#source-directory a[href='##{target}']").send_keys(:enter)
      wait_until { evaluate_script("location.hash") == "##{target}" && evaluate_script("document.activeElement.id") == target }
      assert_selector "details.source-directory[open]"
      heading = find("##{target} .daily-source-heading")
      visible = evaluate_script("(() => { const r = arguments[0].getBoundingClientRect(); return r.top >= 0 && r.bottom <= innerHeight })()", heading)
      assert visible, "#{width}px：目录落点的栏目标题应完整在视口内"
      page.driver.browser.switch_to.active_element.send_keys(:tab)
      assert evaluate_script("document.activeElement.matches('##{target} .item-title a')"), "#{width}px：Tab 应从栏目进入正文"

      summary.send_keys(:enter)
      assert_selector "details.source-directory:not([open])"
      find("##{target} .directory-return").send_keys(:enter)
      wait_until { evaluate_script("location.hash") == "#source-directory" && evaluate_script("document.activeElement.id") == "source-directory" }
      assert_selector "details.source-directory[open]"
      page.driver.browser.switch_to.active_element.send_keys(:tab)
      assert_selector "#source-directory a.source-link:first-child:focus"
      assert_no_horizontal_overflow
    end
  end

  private
    def viewport(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
    end

    def settle_frames
      evaluate_async_script("const done = arguments[0]; requestAnimationFrame(() => requestAnimationFrame(done))")
    end

    def assert_no_horizontal_overflow
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, evaluate_script("document.documentElement.clientWidth")
    end

    def chapter_colors(section)
      evaluate_script(<<~JS, section)
        (() => {
          const section = arguments[0];
          function background(element) {
            const layers = [];
            for (let node = element; node; node = node.parentElement) {
              const channels = getComputedStyle(node).backgroundColor.match(/[\\d.]+/g)?.map(Number);
              if (channels) layers.push(channels);
            }
            const composite = layers.reverse().reduce((base, layer) => {
              const alpha = layer[3] ?? 1;
              return base.map((channel, index) => layer[index] * alpha + channel * (1 - alpha));
            }, [255, 255, 255]);
            return `rgb(${composite.join(', ')})`;
          }
          const text = [];
          for (const block of section.querySelectorAll('.print-source-name, .item-rank, .item-title, .item-summary, .item-translation, .item-reason, .item-meta')) {
            const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT);
            while (walker.nextNode()) {
              const node = walker.currentNode, element = node.parentElement;
              if (node.textContent.trim() && !element.closest('svg')) {
                text.push({ text: node.textContent.trim(), color: getComputedStyle(element).color, background: background(element) });
              }
            }
          }
          const directory = document.querySelector('details.source-directory');
          const planes = [section, section.querySelector('.daily-source-sheet'), section.querySelector('.daily-source-head'), directory].map(element => {
            const style = getComputedStyle(element);
            return { color: style.backgroundColor, image: style.backgroundImage };
          });
          return { surface: background(section.querySelector('.daily-source-sheet')), text, planes,
            texture: getComputedStyle(document.querySelector('.paper')).backgroundImage };
        })()
      JS
    end

    def luminance(color)
      channels = color.scan(/[\d.]+/).first(3).map do |value|
        channel = value.to_f / 255
        channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
      end
      channels.zip([ 0.2126, 0.7152, 0.0722 ]).sum { |channel, weight| channel * weight }
    end

    def contrast(foreground, background)
      light, dark = [ foreground, background ].max, [ foreground, background ].min
      (light + 0.05) / (dark + 0.05)
    end

    def assert_controls_independent(row, width)
      controls = evaluate_script(<<~JS, row)
        (() => {
          const row = arguments[0], comments = row.querySelector('.item-comments'), bookmark = row.querySelector('.item-save');
          const controls = [comments, bookmark].map(element => {
            const r = element.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
            const width = Math.max(44, r.width), height = Math.max(44, r.height);
            const points = [[-21, -21], [21, -21], [-21, 21], [21, 21], [0, 0]];
            return { width, height, left: cx - width / 2, right: cx + width / 2, top: cy - height / 2, bottom: cy + height / 2,
              hits: points.map(([dx, dy]) => document.elementFromPoint(cx + dx, cy + dy)?.closest('a, button') === element) };
          });
          const [a, b] = controls;
          return { controls, adjacent: comments.nextElementSibling === bookmark, grouped: bookmark.parentElement === comments.parentElement,
            overlap: Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left)) * Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top)) };
        })()
      JS
      assert controls.fetch("adjacent"), "#{width}px：收藏应紧跟评论"
      assert controls.fetch("grouped"), "#{width}px：收藏与评论应在同一元数据行"
      assert_equal 0, controls.fetch("overlap"), "#{width}px：44px 命中区域不能重叠"
      controls.fetch("controls").each do |control|
        assert control.fetch("hits").all?, "#{width}px：44px 区域每个探测点必须命中自己的控件；#{control.inspect}"
      end
    end

    def bookmark_geometry(bookmark)
      evaluate_script(<<~JS, bookmark)
        (() => {
          const button = arguments[0];
          const rect = element => element.getBoundingClientRect().toJSON();
          const style = getComputedStyle(button);
          return { button: rect(button), text: button.textContent.trim(), labels: button.querySelectorAll('.favorite-label').length,
            borders: [style.borderTopWidth, style.borderRightWidth, style.borderBottomWidth, style.borderLeftWidth].map(parseFloat),
            line: rect(button.querySelector('.favorite-line svg')), ink: rect(button.querySelector('.favorite-ink svg')) };
        })()
      JS
    end

    def assert_bookmark_layers(geometry, width)
      button, line, ink = geometry.values_at("button", "line", "ink")
      assert_equal "", geometry.fetch("text"), "#{width}px：收藏仅显示图标"
      assert_equal 0, geometry.fetch("labels"), "#{width}px：收藏不附加文字标签"
      geometry.fetch("borders").each { |border| assert_equal 0, border, "#{width}px：普通状态不画按钮边框" }
      assert_in_delta 44, button.fetch("width"), 0.5, "#{width}px"
      assert_in_delta 44, button.fetch("height"), 0.5, "#{width}px"
      %w[ x y width height ].each { |key| assert_in_delta line.fetch(key), ink.fetch(key), 0.5, "#{width}px：描线与墨层须重合" }
      assert_in_delta button.fetch("left") + button.fetch("width") / 2, line.fetch("left") + line.fetch("width") / 2, 0.5, "#{width}px：图标水平居中"
      assert_in_delta button.fetch("top") + button.fetch("height") / 2, line.fetch("top") + line.fetch("height") / 2, 0.5, "#{width}px：图标垂直居中"
      assert_operator line.fetch("right"), :<=, button.fetch("right"), "#{width}px：图标应位于按钮内"
    end
end
