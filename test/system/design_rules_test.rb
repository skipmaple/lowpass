require "application_system_test_case"
require "base64"

# 设计说明 2026-10-14 里能用计算样式与几何量出来的规则。直接把生产 CSS 和最小的 HTML 片段装进一页
# （同 paper_test），不经 Vite、不登录：量的是样式表本身。动效与打印的样式表还没建时就跳过它们。
class DesignRulesTest < ApplicationSystemTestCase
  STYLES = %w[ tokens.css motion.css daily.css weekly.css results.css print.css ].freeze
  PAPER = "rgb(232, 227, 218)".freeze
  INK = "rgb(29, 29, 27)".freeze
  WEEKLY_HEADER = <<~HTML.freeze
    <div class="sheet-body"><section class="weekly-reading"><header class="source-band">
      <h2 class="source-band-title"><span>慢下来的理由</span></h2>
      <div class="source-band-meta"><span>阮一峰科技爱好者周刊</span><span class="source-band-issue">第 366 期</span>
        <a class="source-band-link" href="https://example.com/weekly" target="_blank"><span>原文</span><svg width="13" height="13" viewBox="0 0 24 24" stroke="currentColor"><path d="M7 17 17 7M7 7h10v10" /></svg></a>
      </div>
    </header></section></div>
  HTML

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "", features: [])
  end

  test "Q1 周刊主题与原文入口使用墨色，次级来源事实保留暖纸背景" do
    [ 375, 1440 ].each do |width|
      render_fragment(WEEKLY_HEADER, width: width)

      assert_equal PAPER, style("body", "background-color")
      assert_equal "rgba(0, 0, 0, 0)", style(".source-band", "background-color")
      [ ".source-band-title", ".source-band-link", ".source-band-link svg" ].each do |selector|
        assert_equal INK, style(selector, "color"), "#{width}px #{selector}"
      end
      assert_operator style(".source-band-title", "font-size").to_f, :>, style(".source-band-meta", "font-size").to_f
    end
  end

  test "原生 Tab 跳过不可用翻期控件，可用链接使用墨色可见焦点" do
    [ 375, 1440 ].each do |width|
      render_fragment(<<~HTML, width: width)
        <div style="padding: 60px">
          <a class="ctrl" href="#previous">前一期</a>
          <span class="ctrl ctrl-off" role="link" aria-disabled="true">后一期</span>
          <a class="ctrl" href="#archive">归档</a>
        </div>
      HTML

      [ "前一期", "归档" ].each do |label|
        page.driver.browser.action.send_keys(:tab).perform
        assert_equal label, evaluate_script("document.activeElement.textContent")
        assert_equal INK, style(".ctrl:focus-visible", "outline-color")
        assert_equal "2px", style(".ctrl:focus-visible", "outline-width")
        assert_equal "solid", style(".ctrl:focus-visible", "outline-style")
        assert_equal "2px", style(".ctrl:focus-visible", "outline-offset")
      end
    end
  end

  test "Q2 折叠目录没有默认三角，换成会转的 chevron" do
    render_fragment(%(<details class="weekly-directory"><summary>板块目录</summary><p>x</p></details>))

    assert_not_equal "list-item", style("summary", "display")
    assert_includes style("summary", "mask-image", "::before"), "url("
    assert_equal "none", style("summary", "rotate", "::before")

    execute_script("document.querySelector('details').open = true")
    assert_equal "90deg", style("summary", "rotate", "::before")
  end

  test "来源目录展开后的独立链接保留足够命中面积，窄屏不重叠或溢出" do
    [ 1440, 375, 320 ].each do |width|
      render_fragment(<<~HTML, width: width)
        <details class="source-directory source-tabs-frame">
          <summary>来源目录</summary>
          <nav id="source-directory" class="source-links" aria-label="来源" tabindex="-1">
            <a class="source-link" href="#hn">Hacker News</a>
            <a class="source-link" href="#gh">GitHub Trending</a>
            <a class="source-link" href="#rss">Hackaday</a>
          </nav>
        </details>
        <div class="issue-body"><p>x</p></div>
      HTML
      assert_no_selector "#source-directory", visible: true
      find(".source-directory > summary").send_keys(:enter)
      assert_selector ".source-directory[open] .source-link", count: 3
      links = evaluate_script("[...document.querySelectorAll('.source-link')].map(link => link.getBoundingClientRect().toJSON())")
      links.each do |link|
        assert_operator link.fetch("width"), :>=, 44, "#{width}px"
        assert_operator link.fetch("height"), :>=, 44, "#{width}px"
        assert_operator link.fetch("left"), :>=, 0, "#{width}px"
        assert_operator link.fetch("right"), :<=, width, "#{width}px"
      end
      links.combination(2).each do |a, b|
        overlap = [ 0, [ a.fetch("right"), b.fetch("right") ].min - [ a.fetch("left"), b.fetch("left") ].max ].max *
          [ 0, [ a.fetch("bottom"), b.fetch("bottom") ].min - [ a.fetch("top"), b.fetch("top") ].max ].max
        assert_equal 0, overlap, "#{width}px：来源链接不能重叠"
      end
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
    end
  end

  test "窄屏元数据的评论与收藏分别保留 44px 命中区，时间可自然换行" do
    [ 320, 375 ].each do |width|
      render_fragment(<<~HTML, width: width, height: 812)
        <div style="padding: 24px"><div class="item-meta">
          <a class="item-metric item-comments" href="#c"><span>6</span></a>
          <button type="button" class="favorite-button item-save" aria-label="收藏"><span class="favorite-line" aria-hidden="true"><svg width="18" height="18" viewBox="0 0 24 24"><path d="M6 3h12v18l-6-4-6 4z" /></svg></span></button>
          <time class="item-metric item-age">11 小时前提交</time>
        </div></div>
      HTML
      targets = evaluate_script(<<~JS)
        [...document.querySelectorAll('.item-comments, .item-save')].map(element => {
          const r = element.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
          return { width: r.width, height: r.height,
            hits: [[cx - 21, cy - 21], [cx + 21, cy - 21], [cx - 21, cy + 21], [cx + 21, cy + 21]].map(([x, y]) => document.elementFromPoint(x, y)?.closest('a, button') === element) };
        })
      JS
      targets.each do |target|
        assert_operator target.fetch("width"), :>=, 44, "#{width}px"
        assert_operator target.fetch("height"), :>=, 44, "#{width}px"
        assert target.fetch("hits").all?, "#{width}px：各控件完整命中自己的 44px 区域"
      end
      assert_selector "time", text: "11 小时前提交"
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
    end
  end

  test "标题的 44px 高触控区不占用译文、标签、摘要、周刊正文或独立操作" do
    [ 320, 375, 1440, 1920, 2560 ].each do |width|
      [ "I", "Rust 异步运行时：从任务调度到取消传播，理解 Tokio 在真实服务里的边界" ].each do |title|
        [ :translated, :summary, :weekly ].each do |variant|
          render_fragment(touch_item(title, variant), width: width)
          probes = title_touch_probes
          install_touch_recorder

          probes.each do |probe|
            x, y = probe.values_at("x", "y").map(&:round)
            expected = probe.fetch("expected")
            label = "#{width}px #{variant} #{title.inspect} #{probe.fetch('label')}"
            hit = evaluate_script("document.elementFromPoint(#{x}, #{y})?.closest('[data-touch]')?.dataset.touch || 'nonlink'")
            page.driver.browser.action.move_to_location(x, y, duration: 0).click.perform
            assert_equal [ expected, true ], evaluate_script("window.touchHits.at(-1)"), "#{label}：原生点击"
            assert_equal expected, hit, label
          end
          assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
        end
      end
    end
  end

  test "标题触控扩展不进入打印布局" do
    render_fragment(touch_item("A practical guide to asynchronous systems", :weekly), width: 720, media: "print")

    assert_equal "0px", style(".item-heading", "padding-bottom")
    assert_equal "static", style(".item-title a", "position")
    assert_equal "static", style(".item-rank", "position")
    assert_equal "none", style(".item-title a", "content", "::before")
    assert_equal "0px", style(".item-title a", "padding-top")
    assert_equal "0px", style(".item-title a", "padding-bottom")
  end

  test "搜索与收藏标题命中区保持混排几何并保护眉行、译文、片段和独立操作" do
    [ 320, 375, 1440 ].each do |width|
      [ "I", "A practical guide to reliable asynchronous systems and cancellation in production services", "理解异步系统的任务调度与取消传播，保留完整的阅读上下文和工程边界", "Rust 异步运行时：从任务调度到取消传播，理解 Tokio 在真实服务里的边界" ].each do |title|
        [ false, true ].each do |favorite|
          render_fragment(search_touch_row(title, favorite: favorite), width: width, preflight: true)
          geometry = search_title_geometry
          # 去掉链接的装饰类作为排版参照，不复制实现的 CSS；命中扩展不能改变同一份文字的排版。
          execute_script("document.querySelector('.search-title a').classList.remove('t')")
          reference = search_title_geometry
          execute_script("document.querySelector('.search-title a').classList.add('t')")
          assert_equal reference, geometry, "#{width}px #{title.inspect}：链接命中样式不能改变字形、换行或首标题位置"
          assert_equal "balance", style(".search-title", "text-wrap-style")
          assert_equal "2px", style(".search-title .hit", "text-decoration-thickness") unless favorite
          install_touch_recorder
          targets = search_touch_probes
          assert_operator targets.fetch("height"), :>=, 44, "#{width}px #{title.inspect}：包含字形的连续命中区至少 44px 高"

          targets.fetch("probes").each do |probe|
            x, y = probe.values_at("x", "y").map(&:round)
            expected = probe.fetch("expected")
            label = "#{width}px #{favorite ? 'favorite' : 'search'} #{title.inspect} #{probe.fetch('label')}"
            hit = evaluate_script("document.elementFromPoint(#{x}, #{y})?.closest('[data-touch]')?.dataset.touch || 'nonlink'")
            execute_script("window.touchHits = []")
            page.driver.browser.action.move_to_location(x, y, duration: 0).click.perform
            assert_equal [ [ expected, true ] ], evaluate_script("window.touchHits"), "#{label}：一次可信原生点击"
            assert_equal expected, hit, label
          end
          assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
        end
      end
    end
  end

  test "搜索与收藏标题的命中扩展不进入打印布局" do
    render_fragment(search_touch_row("I", favorite: true), width: 720, media: "print", preflight: true)

    assert_equal "0px", style(".search-title", "padding-bottom")
    assert_equal "static", style(".search-title a", "position")
    assert_equal "none", style(".search-title a", "content", "::before")
    assert_equal "static", style(".result-context", "position")
    assert_equal "0px", style(".search-title a", "padding-top")
    assert_equal "0px", style(".search-title a", "padding-bottom")
  end

  test "标题保护区之外有完整触控矩形且所有字形仍可原生点击" do
    samples = [
      [ "A practical guide to reliable asynchronous systems, cancellation, and the subtle boundaries of production services", "前端开发", [ :item, :search, :favorite ] ],
      [ "Tailwind Labs is joining Shopify", "前端开发", [ :item ] ],
      [ "Desert Ant Labs: local, fast models that run on device", "AI / LLM", [ :item ] ]
    ]
    [ 320, 375 ].each do |width|
      samples.each do |title, tag, kinds|
        kinds.each do |kind|
          html = kind == :item ? touch_item(title, :translated, interest_tag: tag) : search_touch_row(title, favorite: kind == :favorite)
          render_fragment(html, width: width, preflight: kind != :item)
          install_touch_recorder
          selector = kind == :item ? ".item-title a" : ".search-title a"
          title_fragment_targets(selector).each do |target|
            [ target.fetch("top"), target.fetch("glyph_top"), target.fetch("glyph_center"), target.fetch("glyph_bottom"), target.fetch("bottom") ].uniq.each do |y|
              execute_script("window.touchHits = []")
              page.driver.browser.action.move_to_location(target.fetch("x"), y, duration: 0).click.perform
              assert_equal [ [ "title", true ] ], evaluate_script("window.touchHits"), "#{width}px #{kind} #{target.inspect}：原生命中边缘"
            end
          end
          # 标签是非链接保护区，目标可以有凹口；宽标题仍必须容纳完整 44×44 区域，不能只靠细列通过。
          rectangle = title_touch_rectangle(selector)
          assert rectangle, "#{width}px #{kind} #{title.inspect}：保护区之外应有完整 44×44 命中矩形"
          [ 1, 22, 43 ].product([ 1, 22, 43 ]).each do |dx, dy|
            execute_script("window.touchHits = []")
            page.driver.browser.action.move_to_location(rectangle.fetch("x") + dx, rectangle.fetch("y") + dy, duration: 0).click.perform
            assert_equal [ [ "title", true ] ], evaluate_script("window.touchHits"), "#{width}px #{kind}：内接矩形原生点击"
          end
        end
      end
    end
  end

  test "T1 内容文字开中西文间距，界面日期保持紧排" do
    render_fragment(%(<p class="item-reason">涉及AI模型</p><p class="item-translation">OpenAI工程师</p><h1 class="issue-head-date">10月14日</h1>))

    assert_equal "normal", style(".item-reason", "text-autospace")
    assert_equal "normal", style(".item-translation", "text-autospace")
    assert_equal "no-autospace", style(".issue-head-date", "text-autospace")
  end

  test "T2 标题均衡换行，段落避免孤字" do
    render_fragment(%(<div class="item-heading"><h2 class="item-title">Title</h2></div><span class="item-summary">Summary</span><div class="item-reason">理由</div>))

    assert_equal "balance", style(".item-heading", "text-wrap-style")
    assert_equal "pretty", style(".item-summary", "text-wrap-style")
    assert_equal "pretty", style(".item-reason", "text-wrap-style")
  end

  test "T3 选区是墨底纸字" do
    render_fragment(%(<p class="item-reason">理由</p>))

    assert_equal INK, style(".item-reason", "background-color", "::selection")
    assert_equal PAPER, style(".item-reason", "color", "::selection")
  end

  test "T5 墨底纸字用灰度抗锯齿；T6 滚动条用令牌色" do
    render_fragment(%(<header class="masthead"><a class="masthead-brand">lowpass</a></header>))

    assert_equal "antialiased", style(".masthead", "-webkit-font-smoothing")
    assert_equal "rgba(29, 29, 27, 0.35) rgba(0, 0, 0, 0)", style("html", "scrollbar-color")
  end

  ITEM = <<~HTML.freeze
    <div style="padding: 0 24px"><article class="item-row"><span class="item-rank">2</span><div class="item-body">
      <div class="item-heading"><h2 class="item-title"><a class="t" href="#">%<title>s</a></h2><span class="item-tag"><span class="chip-outline item-interest-chip">%<tag>s</span></span></div>
    </div></article></div>
  HTML

  test "Q4/C4 兴趣标签紧跟标题末尾，放不下就整个换到下一行行首" do
    [ 1440, 1024, 375, 320 ].each do |width|
      render_fragment(format(ITEM, title: "OpenAI engineer arrested in bugging of executive conference room", tag: "智能家居 / IoT"), width: width)
      placed = evaluate_script(<<~JS)
        (() => {
          const range = document.createRange(); range.selectNodeContents(document.querySelector('.item-title a'))
          const rects = [...range.getClientRects()]
          const last = rects[rects.length - 1]
          const tag = document.querySelector('.item-tag').getBoundingClientRect()
          const heading = document.querySelector('.item-heading').getBoundingClientRect()
          const sameLine = Math.abs(tag.bottom - last.bottom) <= 6 && tag.left >= last.right
          const nextLineStart = tag.top >= last.bottom - 1 && Math.abs(tag.left - heading.left) <= 1
          return sameLine || nextLineStart
        })()
      JS
      assert placed, "#{width}px：标签应在标题末尾或下一行行首"
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, evaluate_script("document.documentElement.clientWidth"), "#{width}px：不横向溢出"
    end
  end

  test "T4 序号与标题首行同一条基线；期头小字末行与大字日期同一条基线" do
    baseline = <<~JS
      ((selector) => { const el = document.querySelector(selector); const probe = document.createElement('span'); probe.style.cssText = 'display:inline-block;width:0;height:0;vertical-align:baseline'; el.prepend(probe); const y = probe.getBoundingClientRect().top; probe.remove(); return y })
    JS

    [ 320, 375, 1440, 1920 ].each do |width|
      [ :translated, :weekly ].each do |variant|
        render_fragment(touch_item("A practical guide to asynchronous systems and readable tools", variant), width: width)
        assert_in_delta evaluate_script("#{baseline}('.item-rank')"), evaluate_script("#{baseline}('.item-title a')"), 1,
          "#{width}px #{variant}：序号必须对齐完整标题的首行"
      end
    end

    render_fragment(%(<header class="page-head"><div class="issue-head-main"><div class="issue-head-title"><h1 class="issue-head-date">10月14日</h1><div class="issue-head-stack"><span class="issue-head-calendar">2026 年 · 星期三</span><span class="issue-head-time">06:00 发布</span></div></div></div></header>))
    assert_in_delta evaluate_script("#{baseline}('.issue-head-date')"), evaluate_script("#{baseline}('.issue-head-time')"), 1
  end

  test "M 动效令牌就这五个" do
    render_fragment("<p>x</p>")

    root = ->(name) { evaluate_script("getComputedStyle(document.documentElement).getPropertyValue(#{name.to_json}).trim()") }
    assert_equal "120ms", root.("--dur-1")
    assert_equal "240ms", root.("--dur-2")
    assert_equal "360ms", root.("--dur-3")
    assert_equal "cubic-bezier(0.2, 0.7, 0.2, 1)", root.("--ease-out")
    assert_equal "cubic-bezier(0.65, 0, 0.35, 1)", root.("--ease-move")
  end

  test "M4 描边按钮悬停时墨从底部漫满、字转纸色；不可点的没有" do
    render_fragment(%(<div style="padding: 40px"><a class="ctrl" href="#p">前一期</a> <span class="ctrl ctrl-off">后一期</span></div>), hover: true)

    assert_equal "matrix(1, 0, 0, 0, 0, 0)", style(".ctrl:not(.ctrl-off)", "transform", "::before")
    find("a.ctrl").hover
    wait_until { style("a.ctrl", "color") == PAPER }
    wait_until { style("a.ctrl", "transform", "::before") == "matrix(1, 0, 0, 1, 0, 0)" }
    assert_equal "none", style(".ctrl-off", "content", "::before")
  end

  test "M4 来源目录链接悬停加深下划线，不反白纸面" do
    render_fragment(%(<details class="source-directory source-tabs-frame" open><summary>来源目录</summary><nav id="source-directory" class="source-links" aria-label="来源" tabindex="-1"><a class="source-link" href="#hn">Hacker News</a></nav></details>), hover: true)

    assert_equal "underline", style(".source-link", "text-decoration-line")
    refute_equal "rgba(0, 0, 0, 0)", style(".source-link", "text-decoration-color")
    refute_equal INK, style(".source-link", "text-decoration-color")
    find(".source-link").hover
    wait_until { style(".source-link", "text-decoration-color") == INK }
    assert_not_equal INK, style(".source-link", "background-color")
  end

  test "M7 菜单、对话框、提示条带出现动画；减少动态效果时几乎为零" do
    render_fragment(%(<div class="menu-card">菜单</div><div class="dialog">问句</div><div class="toast">提示</div>))
    assert_equal "lp-unfold", style(".menu-card", "animation-name")
    assert_equal "lp-settle", style(".dialog", "animation-name")
    assert_equal "lp-drop", style(".toast", "animation-name")

    render_fragment(%(<div class="menu-card">菜单</div><a class="ctrl" href="#p">前一期</a>), reduced_motion: true)
    assert_equal "0.001s", style(".menu-card", "animation-duration")
    assert_equal "0.001s", style(".ctrl", "transition-duration", "::before")
  end

  test "C3 周刊配图在纸面正片叠底，打印时恢复原图" do
    image = %(<figure class="item-media-frame"><img class="item-media-image" alt="周刊配图"></figure>)
    [ 375, 1440 ].each do |width|
      render_fragment(image, width: width)
      assert_equal "multiply", style(".item-media-image", "mix-blend-mode")
    end
    render_fragment(image, media: "print")
    assert_equal "normal", style(".item-media-image", "mix-blend-mode")
  end

  test "已知天然尺寸的周刊配图解码前后不推移后文，手机与多图同样成立" do
    [ 375, 1440 ].each do |width|
      [ "item-media--single", "item-media--multiple" ].each do |layout|
        render_fragment(<<~HTML, width: width)
          <div class="item-media #{layout}">
            <figure class="item-media-frame item-media-frame--sized item-media-frame--loading" style="--image-width:1200px;--image-ratio:1.5">
              <img class="item-media-image" width="1200" height="800" alt="横图">
            </figure>
            #{if layout == "item-media--multiple"
                '<figure class="item-media-frame item-media-frame--sized" style="--image-width:400px;--image-ratio:0.5"><img class="item-media-image" width="400" height="800" alt="竖图"></figure>'
              end}
          </div>
          <p id="after-media">下一段正文</p>
        HTML
        assert_equal "solid", style(".item-media-frame--loading", "outline-style")
        before = evaluate_script("document.querySelector('#after-media').getBoundingClientRect().top")
        execute_script(<<~JS)
          for (const image of document.images) {
            const w = Number(image.getAttribute('width')), h = Number(image.getAttribute('height'))
            image.src = 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="100%" height="100%" fill="black"/></svg>`)
          }
        JS
        wait_until { evaluate_script("[...document.images].every(image => image.complete && image.naturalWidth > 0)") }
        execute_script("document.querySelector('.item-media-frame--loading').classList.remove('item-media-frame--loading')")
        after = evaluate_script("document.querySelector('#after-media').getBoundingClientRect().top")
        assert_in_delta before, after, 0.5, "#{width}px #{layout}：解码不推移后文"
        assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
      end
    end
  end

  test "周刊单图与正文左缘对齐，窄图和宽图均不超出阅读列" do
    [ 375, 768, 1440 ].each do |width|
      [ 240, 512, 1200 ].each do |image_width|
        render_fragment(<<~HTML, width: width)
          <div class="item-body">
            <div class="item-content--weekly"><p>正文</p></div>
            <div class="item-media item-media--single">
              <figure class="item-media-frame item-media-frame--sized" style="--image-width:#{image_width}px;--image-ratio:1.5"></figure>
            </div>
          </div>
        HTML
        bounds = evaluate_script(<<~JS)
          (() => {
            const text = document.querySelector('.item-content--weekly').getBoundingClientRect()
            const image = document.querySelector('.item-media-frame').getBoundingClientRect()
            return { textLeft: text.left, imageLeft: image.left, imageRight: image.right, textRight: text.right }
          })()
        JS
        assert_in_delta bounds["textLeft"], bounds["imageLeft"], 0.5, "#{width}px / #{image_width}px：图文左缘"
        assert_operator bounds["imageRight"], :<=, bounds["textRight"] + 0.5
      end
    end
  end

  test "D2 打印时配图不叠底，报头是白底墨字" do
    render_fragment(%(<header class="masthead"><a class="masthead-brand">lowpass</a></header><img class="item-media-image" alt="">), media: "print")

    assert_equal "normal", style(".item-media-image", "mix-blend-mode")
    assert_equal "rgba(0, 0, 0, 0)", style(".masthead", "background-color")
    assert_equal INK, style(".masthead-brand", "color")
  end

  # 自查第 1 轮：打印页宽 700 多像素，手机断点里的 align-items: center 让序号沉到条目中间
  test "D2 打印时序号与标题首行同一条基线" do
    render_fragment(format(ITEM, title: "Show HN: Geiger – See every AI agent on your machine and what it can touch", tag: "AI / LLM"), width: 720, media: "print")
    # 探针插在开头：长标题在 720 宽折成两行，序号对的是第一行
    baseline = "((selector) => { const el = document.querySelector(selector); const probe = document.createElement('span'); probe.style.cssText = 'display:inline-block;width:0;height:0;vertical-align:baseline'; el.prepend(probe); const y = probe.getBoundingClientRect().top; probe.remove(); return y })"

    assert_in_delta evaluate_script("#{baseline}('.item-rank')"), evaluate_script("#{baseline}('.item-title a')"), 1
  end

  # 自查第 1 轮：冷缓存时 Bodoni 晚到，品牌字由窄的回退字体换成 Bodoni，后面的导航被推开 40px（CLS）。
  # 这页没有加载网页字体，量到的就是回退字体下的宽度：必须已经预留到 Bodoni 的宽度（5.66em）
  test "报头品牌字没加载 Bodoni 时也占住 Bodoni 的宽度" do
    render_fragment(%(<header class="masthead"><div class="masthead-left"><a class="masthead-brand">lowpass</a><nav class="masthead-nav"><a>日刊</a></nav></div></header>))
    assert_operator evaluate_script("document.querySelector('.masthead-brand').getBoundingClientRect().width"), :>=, 226.5

    render_fragment(%(<header class="masthead"><div class="masthead-left"><a class="masthead-brand">lowpass</a></div></header>), width: 375, height: 812)
    assert_operator evaluate_script("document.querySelector('.masthead-brand').getBoundingClientRect().width"), :>=, 147
  end

  # 自查第 2 轮：375 宽的登录卡里，「每天一期技术日刊，登录后阅读」折行后第二行只剩一个「读」。放不下时只在逗号后断行
  test "登录页那句话放不下时只在逗号后断行" do
    # 容器宽度按这句话在当前字体下一行的宽度来定（比它窄一点，逼它折行），不假设某台机器上的回退字体有多宽
    render_fragment(%(<div class="box"><p class="login-tagline">每天一期技术日刊，登录后阅读</p></div>), width: 375, height: 812)
    execute_script(<<~JS)
      const box = document.querySelector('.box'), line = document.querySelector('.login-tagline')
      line.style.cssText = 'display: inline-block; white-space: nowrap'
      const full = line.getBoundingClientRect().width
      line.style.cssText = ''
      box.style.width = (full - 8) + 'px'
    JS
    line_of = <<~JS
      ((index) => { const node = document.querySelector('.login-tagline').firstChild; const range = document.createRange(); range.setStart(node, index); range.setEnd(node, index + 1); return Math.round(range.getBoundingClientRect().top) })
    JS

    assert_operator evaluate_script("#{line_of}(8)"), :<, evaluate_script("#{line_of}(9)"), "逗号在第一行，「登」另起一行"
    assert_equal evaluate_script("#{line_of}(9)"), evaluate_script("#{line_of}(13)"), "「登录后阅读」在同一行"
  end

  # 终审：均衡换行总给标签在标题末行留出位置，上面那条用例走不到「换到下一行」的分支；
  # 这里用一个几乎占满一行、又不至于被拆开的词逼它换行
  test "Q4 标签换到下一行时从行首起，不缩进" do
    render_fragment(format(ITEM, title: "Mmmmmmmmmmmmmm", tag: "智能家居 / IoT"), width: 320, height: 800)
    offsets = evaluate_script(<<~JS)
      (() => {
          const range = document.createRange(); range.selectNodeContents(document.querySelector('.item-title a'))
          const rects = [...range.getClientRects()]
        const last = rects[rects.length - 1]
        const tag = document.querySelector('.item-tag').getBoundingClientRect()
        const heading = document.querySelector('.item-heading').getBoundingClientRect()
        return { wrapped: tag.top >= last.bottom - 1, left: tag.left - heading.left }
      })()
    JS

    assert offsets["wrapped"], "这个标题应把标签挤到下一行"
    assert_in_delta 0, offsets["left"], 1
  end

  test "D2 周刊栏首打印为墨色并保留主题、来源与原文入口" do
    render_fragment(WEEKLY_HEADER, media: "print")
    assert_equal "rgba(0, 0, 0, 0)", style(".source-band", "background-color")
    [ ".source-band-title", ".source-band-meta > span", ".source-band-link" ].each do |selector|
      assert_equal INK, style(selector, "color"), selector
    end
    assert_selector ".source-band-title", text: "慢下来的理由"
    assert_selector ".source-band-meta", text: "阮一峰科技爱好者周刊"
    assert_selector ".source-band-link[href='https://example.com/weekly']", text: "原文"
  end

  # 终审：选区统一成墨底纸字后，墨底上的字（报头、横带、反白按钮）选中时成了墨上墨，看不见。墨底上反过来用纸底墨字
  test "T3 墨底选区用纸底墨字，纸面周刊主题选区用墨底纸字" do
    render_fragment(%(<header class="masthead"><a class="masthead-brand">lowpass</a></header>#{WEEKLY_HEADER}<button class="btn-primary">搜索</button>))

    [ ".masthead-brand", ".btn-primary" ].each do |selector|
      assert_equal PAPER, style(selector, "background-color", "::selection"), selector
      assert_equal INK, style(selector, "color", "::selection"), selector
    end
    assert_equal INK, style(".source-band-title span", "background-color", "::selection")
    assert_equal PAPER, style(".source-band-title span", "color", "::selection")
  end

  # 终审：summary 设成 flex 后，后台抓取记录里「错误详情 · 原因」这种行内片段各成一个弹性项、互相隔开 8px。
  # summary 保持块级，chevron 用行内块挂在开头，里面的字照常排成一行
  test "Q2 summary 里的行内片段照常连成一行" do
    render_fragment(%(<details class="admin-details"><summary><span class="a">错误详情</span> · <span class="b">超时</span></summary><p>x</p></details>))

    assert_equal "block", style("summary", "display")
    gap = evaluate_script("document.querySelector('.b').getBoundingClientRect().left - document.querySelector('.a').getBoundingClientRect().right")
    assert_operator gap, :<, 20, "「 · 」本身的宽度，不该再加上弹性间距"
    assert_includes style("summary", "mask-image", "::before"), "url("
  end

  private
    def title_touch_rectangle(selector)
      evaluate_script(<<~JS)
        (() => {
          const anchor = document.querySelector(#{selector.to_json}), hit = (x, y) => document.elementFromPoint(x, y)?.closest(#{selector.to_json}) === anchor
          for (const r of [...anchor.getClientRects(), anchor.getBoundingClientRect()]) {
            if (r.width < 44 || r.height < 44) continue
            for (const x of [r.left, r.left + (r.width - 44) / 2, r.right - 44]) for (const y of [r.top, r.top + (r.height - 44) / 2, r.bottom - 44]) {
              let solid = true
              for (let dx = .5; dx < 44 && solid; dx++) for (let dy = .5; dy < 44; dy++) if (!hit(x + dx, y + dy)) { solid = false; break }
              if (solid) return {x, y, width:44, height:44, sampledPixels:1936}
            }
          }
          return null
        })()
      JS
    end

    def title_fragment_targets(selector)
      evaluate_script(<<~JS)
        (() => {
          const anchor = document.querySelector(#{selector.to_json}), walker = document.createTreeWalker(anchor, NodeFilter.SHOW_TEXT), targets = []
          let fragment = 0
          for (let node; (node = walker.nextNode());) {
            const range = document.createRange(); range.selectNodeContents(node)
            for (const r of range.getClientRects()) if (r.width > 0) {
              for (const [edge, point] of [['left', r.left + 1], ['middle', r.left + r.width / 2], ['right', r.right - 1]]) {
                const x = Math.round(point), cy = Math.round(r.top + r.height / 2)
                const hit = y => document.elementFromPoint(x, y)?.closest(#{selector.to_json}) === anchor
                let top = cy, bottom = cy
                while (top > 0 && cy - top < 100 && hit(top - 1)) top--
                while (bottom < innerHeight - 1 && bottom - cy < 100 && hit(bottom + 1)) bottom++
                targets.push({fragment, width:r.width, edge, x, top, bottom, height:bottom - top + 1, glyph_top:Math.ceil(r.top + 1), glyph_center:cy, glyph_bottom:Math.floor(r.bottom - 1)})
              }
              fragment++
            }
          }
          return targets
        })()
      JS
    end

    # SearchResultRow 与 Favorites/Index 的静态 fixture，保留 Mixed/HitText 的嵌套与行高。
    # 搜索没有译文；收藏的标题译文直接跟在 h2 后，不借用 ItemRow 的 flex gap。
    def search_touch_row(title, favorite:)
      segments = title.split(/(Rust |Tokio )/).reject(&:empty?).map do |text|
        font = text.match?(/\p{Han}/) ? "cjk" : "latin"
        %(<span style="font-family:var(--font-#{font});font-size:var(--fs-20)">#{ERB::Util.html_escape(text)}</span>)
      end.join
      mixed = %(<span style="line-height:1.6">#{segments}</span>)
      title_markup = favorite ? mixed : %(<span class="hit">#{mixed}</span>)
      translation = %(<p class="item-translation">原文标题的完整中文译文。</p>) if favorite
      <<~HTML
        <div class="sheet-body" style="padding-top:40px"><div class="search-results"><article class="search-row">
          <h2 class="search-title"><a class="t" href="#title" data-touch="title">#{title_markup}</a></h2>
          #{translation}<p class="search-snippet">A complete ordinary reading excerpt remains nonlinked.</p>
          <div class="result-meta">
            <div class="result-context"><span>日刊</span><span>Hacker News</span></div>
            <div class="search-links"><a class="t" href="#issue" data-touch="where">所在期 · 2026年10月13日</a><button type="button" class="favorite-button search-mark" data-touch="bookmark" aria-label="收藏"><span class="favorite-line" aria-hidden="true"><svg width="18" height="18" viewBox="0 0 24 24"><path d="M6 3h12v18l-6-4-6 4z" /></svg></span></button></div>
          </div>
        </article></div></div>
      HTML
    end

    def search_title_geometry
      evaluate_script(<<~JS)
        (() => {
          const heading = document.querySelector('.search-title'), anchor = heading.querySelector('a'), box = heading.getBoundingClientRect()
          const walker = document.createTreeWalker(anchor, NodeFilter.SHOW_TEXT), glyphs = []
          for (let node; (node = walker.nextNode());) {
            const range = document.createRange(); range.selectNodeContents(node)
            for (const r of range.getClientRects()) if (r.width > 0) glyphs.push([r.x, r.y - box.y, r.width, r.height])
          }
          return {top:box.top, glyphs}
        })()
      JS
    end

    def search_touch_probes
      evaluate_script(<<~JS)
        (() => {
          const probes = [], add = (x, y, expected, label) => probes.push({x, y, expected, label})
          const anchor = document.querySelector('.search-title a'), walker = document.createTreeWalker(anchor, NodeFilter.SHOW_TEXT), lines = []
          for (let node; (node = walker.nextNode());) {
            const range = document.createRange(); range.selectNodeContents(node)
            for (const r of range.getClientRects()) if (r.width > 0) lines.push(r)
          }
          const last = lines.at(-1), cx = Math.round(last.left + last.width / 2), cy = Math.round(last.top + last.height / 2)
          // 44px 不隐含相对字形居中；从字形内部扫描连续命中区，原生点击它的实际上下边缘。
          const hit = y => Boolean(document.elementFromPoint(cx, y)?.closest('.search-title a'))
          let top = cy, bottom = cy
          while (top > 0 && cy - top < 100 && hit(top - 1)) top--
          while (bottom < innerHeight - 1 && bottom - cy < 100 && hit(bottom + 1)) bottom++
          add(cx, top, 'title', '连续命中区上沿'); add(cx, bottom, 'title', '连续命中区下沿')
          for (const line of lines) for (const x of [line.left + 1, line.left + line.width / 2, line.right - 1]) for (const y of [line.top + 1, line.top + line.height / 2, line.bottom - 1]) add(x, y, 'title', '每段字形边界')
          for (const element of document.querySelectorAll('.result-context,.item-translation,.search-snippet')) {
            const r = element.getBoundingClientRect()
            for (const x of [r.left + 1, r.left + r.width / 2, r.right - 1]) for (const y of [r.top + 1, r.top + r.height / 2, r.bottom - 1]) add(x, y, 'nonlink', element.className)
          }
          for (const element of document.querySelectorAll('.search-links > a,.favorite-button')) {
            const r = element.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2
            for (const dy of [-21, 0, 21]) add(x, y + dy, element.dataset.touch, element.dataset.touch + ' 独立目标')
          }
          return {height:bottom - top + 1, probes}
        })()
      JS
    end

    # 与 ItemRow 的三种正文次序一致：HN 译文、GitHub 简介、无标签的周刊完整正文。
    # 只装生产 CSS 与静态结构；点击记录器阻止导航，书签没有持久化处理器，不发请求。
    def touch_item(title, variant, interest_tag: "前端开发")
      heading = variant == :weekly ? "h4" : "h2"
      tag_font = interest_tag.match?(/\p{Han}/) ? "cjk" : "data"
      tag = %(<span class="item-tag"><span class="chip-outline item-interest-chip"><span style="line-height:1.6;white-space:nowrap"><span style="font-family:var(--font-#{tag_font});font-size:var(--fs-12)">#{ERB::Util.html_escape(interest_tag)}</span></span></span></span>) unless variant == :weekly
      copy = case variant
      when :translated
        %(<p class="item-translation">原文标题的中文译文，保持完整展示。</p>)
      when :summary
        %(<span class="item-summary">A complete summary that remains ordinary, nonlinked reading text.</span><p class="item-translation">这段简介的中文译文。</p>)
      when :weekly
        %(<div class="item-content item-content--weekly"><p><span style="font-family:var(--font-cjk);font-size:var(--fs-15);line-height:1.8">这是周刊的完整正文，按原文分段展示。</span></p><p><span style="font-family:var(--font-latin);font-size:var(--fs-15);line-height:1.8">The second paragraph remains part of the weekly reading column.</span></p></div>)
      end
      bookmark = %(<button type="button" class="favorite-button #{variant == :weekly ? 'item-mark' : 'item-save'}" aria-label="收藏" data-touch="bookmark"><span class="favorite-line" aria-hidden="true"><svg width="18" height="18" viewBox="0 0 24 24"><path d="M6 3h12v18l-6-4-6 4z" /></svg></span></button>)
      meta = if variant == :weekly
        %(<span class="data" data-protected>10-22 06:00</span>)
      else
        %(<div class="item-reason">与关注的领域相关，说明具体使用场景。</div><div class="item-meta"><span class="item-metric" data-protected>382</span><a class="item-metric item-comments" href="#comments" data-touch="comments">147</a>#{bookmark}<time class="item-metric item-age" data-protected>42 天前提交</time></div>)
      end
      <<~HTML
        <div class="sheet-body" style="padding-top:40px"><section class="#{variant == :weekly ? 'weekly-reading' : 'daily-reading daily-source'}"><article class="item-row#{' item-row--weekly' if variant == :weekly}"><span class="item-rank">1</span><div class="item-body">
          <div class="item-heading"><#{heading} class="item-title"><a class="t" href="#title" data-touch="title">#{ERB::Util.html_escape(title)}</a></#{heading}>#{tag}#{bookmark if variant == :weekly}</div>
          #{copy}#{meta}
        </div></article></section></div>
      HTML
    end

    def title_touch_probes
      evaluate_script(<<~JS)
        (() => {
          const probes = [], add = (x, y, expected, label) => probes.push({x, y, expected, label})
          const title = document.querySelector('.item-title a'), range = document.createRange()
          range.selectNodeContents(title)
          const lines = [...range.getClientRects()].filter(r => r.width > 0), last = lines.at(-1)
          const cx = last.left + last.width / 2, cy = last.top + last.height / 2
          // 高度要求不隐含宽度要求，单字母 I 也只在自身宽度内探测。
          for (const dy of [-21.5, 21.5]) add(cx, cy + dy, 'title', '44px 上下边缘')
          for (const line of lines) add(line.left + line.width / 2, line.top + line.height / 2, 'title', '每行字形')
          for (const element of document.querySelectorAll('.item-rank,.item-tag,.item-translation,.item-summary,.item-content--weekly > p,.item-reason,[data-protected]')) {
            const r = element.getBoundingClientRect()
            for (const x of [r.left + 1, r.left + r.width / 2, r.right - 1]) {
              add(x, r.top + 1, 'nonlink', element.className + ' 上沿')
              add(x, r.top + r.height / 2, 'nonlink', element.className + ' 中部')
              add(x, r.bottom - 1, 'nonlink', element.className + ' 下沿')
            }
          }
          for (const element of document.querySelectorAll('.item-comments,.favorite-button')) {
            const r = element.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2
            for (const [dx, dy] of [[0, 0], [-21, -21], [21, -21], [-21, 21], [21, 21]]) {
              add(x + dx, y + dy, element.dataset.touch, element.dataset.touch + ' 独立目标')
            }
          }
          return probes
        })()
      JS
    end

    def install_touch_recorder
      execute_script(<<~JS)
        window.touchHits = []
        document.addEventListener('click', event => {
          window.touchHits.push([event.target.closest('[data-touch]')?.dataset.touch || 'nonlink', event.isTrusted])
          event.preventDefault()
          event.stopImmediatePropagation()
        }, true)
      JS
    end

    # hover: true 把悬停规则外面那层 (hover: hover) and (pointer: fine) 换成 all：那层只是给触屏设备的保护，
    # GitHub Actions 的无头 Chrome 没有指针设备、不匹配它，悬停的效果却正是这里要量的（CDP 也模拟不了这两个媒体特性）
    def render_fragment(html, width: 1440, height: 900, reduced_motion: false, media: "", hover: false, preflight: false)
      css = STYLES.map { |name| Rails.root.join("app/frontend/styles", name) }.select(&:exist?).map(&:read).join("\n")
      # 搜索标题的 h2 继承 15px，内部 Mixed 才是 20px；使用应用实际加载的 Tailwind reset。
      css = Rails.root.join("node_modules/tailwindcss/preflight.css").read + "\n" + css if preflight
      css = css.gsub("@media (hover: hover) and (pointer: fine)", "@media all") if hover
      browser = page.driver.browser
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      browser.execute_cdp("Emulation.setEmulatedMedia", media: media, features: [ { name: "prefers-reduced-motion", value: reduced_motion ? "reduce" : "no-preference" } ])
      document = "<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'><style>#{css}</style></head><body class='paper'>#{html}</body></html>"
      visit "data:text/html;charset=utf-8;base64,#{Base64.strict_encode64(document)}"
    end

    def style(selector, property, pseudo = nil)
      evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}), #{pseudo.to_json}).getPropertyValue(#{property.to_json})")
    end
end
