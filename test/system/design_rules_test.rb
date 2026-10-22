require "application_system_test_case"
require "base64"

# 设计说明 2026-10-14 里能用计算样式与几何量出来的规则。直接把生产 CSS 和最小的 HTML 片段装进一页
# （同 paper_test），不经 Vite、不登录：量的是样式表本身。动效与打印的样式表还没建时就跳过它们。
class DesignRulesTest < ApplicationSystemTestCase
  STYLES = %w[ tokens.css motion.css print.css ].freeze
  PAPER = "rgb(232, 227, 218)".freeze
  INK = "rgb(29, 29, 27)".freeze

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "", features: [])
  end

  test "Q1 周刊来源横带里的图标与文字是纸色" do
    render_fragment(%(<div class="source-band"><svg viewBox="0 0 10 10" fill="none" stroke="currentColor"><path d="M0 0L10 10"/></svg></div>))

    assert_equal PAPER, style(".source-band svg", "color")
  end

  test "Q2 折叠目录没有默认三角，换成会转的 chevron" do
    render_fragment(%(<details class="weekly-directory"><summary>板块目录</summary><p>x</p></details>))

    assert_not_equal "list-item", style("summary", "display")
    assert_includes style("summary", "mask-image", "::before"), "url("
    assert_equal "none", style("summary", "rotate", "::before")

    execute_script("document.querySelector('details').open = true")
    assert_equal "90deg", style("summary", "rotate", "::before")
  end

  test "Q3 索引条相邻的边与下面的列表线都合成一条 1px" do
    [ 1440, 375 ].each do |width|
      render_fragment(<<~HTML, width: width)
        <div class="source-tabs"><button class="source-tab">A</button><button class="source-tab">B</button><button class="source-tab">C</button></div>
        <div class="issue-body"><p>x</p></div>
      HTML
      tabs = evaluate_script("[...document.querySelectorAll('.source-tab')].map((tab) => tab.getBoundingClientRect().toJSON())")
      body = evaluate_script("document.querySelector('.issue-body').getBoundingClientRect().toJSON()")

      assert_in_delta 0, tabs[0]["left"], 0.5, "#{width}px：最左一条贴齐版心"
      assert_in_delta tabs[0]["right"] - 1, tabs[1]["left"], 0.5, "#{width}px：第一、二条共用一条边"
      assert_in_delta tabs[1]["right"] - 1, tabs[2]["left"], 0.5, "#{width}px：第二、三条共用一条边"
      assert_in_delta tabs[0]["bottom"] - 1, body["top"], 0.5, "#{width}px：索引条底边与列表顶线合成一条"
    end
  end

  test "Q5 手机上评论链接的触控区 44px，元数据行仍是 24px 高" do
    render_fragment(%(<div style="padding: 60px"><div class="item-meta"><a class="item-metric item-comments" href="#c"><span>6</span></a></div></div>), width: 375, height: 812)

    assert_operator evaluate_script("document.querySelector('.item-meta').getBoundingClientRect().height"), :<=, 24.5
    hits = evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector('.item-comments').getBoundingClientRect()
        const cx = r.left + r.width / 2, cy = r.top + r.height / 2
        return [[cx, cy - 21], [cx, cy + 21], [cx - 21, cy], [cx + 21, cy]].map(([x, y]) => document.elementFromPoint(x, y)?.closest('.item-comments') !== null)
      })()
    JS
    assert_equal [ true, true, true, true ], hits
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
          if width <= 767
            assert_equal "24px", style(".item-row", "padding-top")
            assert_equal "24px", style(".item-row", "padding-bottom")
          end
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
          const rects = [...document.querySelector('.item-title a').getClientRects()]
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
    render_fragment(<<~HTML)
      #{format(ITEM, title: "Gemini 4 Argon", tag: "AI / LLM")}
      <header class="page-head"><div class="issue-head-main"><div class="issue-head-title"><h1 class="issue-head-date">10月14日</h1><div class="issue-head-stack"><span class="issue-head-calendar">2026 年 · 星期三</span><span class="issue-head-time">06:00 发布</span></div></div></div></header>
    HTML
    baseline = <<~JS
      ((selector) => { const el = document.querySelector(selector); const probe = document.createElement('span'); probe.style.cssText = 'display:inline-block;width:0;height:0;vertical-align:baseline'; el.appendChild(probe); const y = probe.getBoundingClientRect().top; probe.remove(); return y })
    JS

    assert_in_delta evaluate_script("#{baseline}('.item-rank')"), evaluate_script("#{baseline}('.item-title a')"), 1
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

  test "M4 未选中的索引条与分段控件悬停只加下划线，不反白" do
    render_fragment(%(<div class="source-tabs"><button class="source-tab" data-state="active"><span class="source-tab-name">A</span></button><button class="source-tab" data-state="inactive"><span class="source-tab-name">B</span></button></div>), hover: true)

    name = ".source-tab[data-state='inactive'] .source-tab-name"
    assert_equal "underline", style(name, "text-decoration-line")
    assert_equal "rgba(0, 0, 0, 0)", style(name, "text-decoration-color")
    find(".source-tab[data-state='inactive']").hover
    wait_until { style(name, "text-decoration-color") == INK }
    assert_not_equal INK, style(".source-tab[data-state='inactive']", "background-color")
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

  test "C3 周刊配图正片叠底；横带图形 52×34，手机 37×24" do
    render_fragment(%(<div class="source-band"><svg class="source-band-mark" viewBox="0 0 120 78"></svg></div><img class="item-media-image" alt="">))

    assert_equal "multiply", style(".item-media-image", "mix-blend-mode")
    assert_equal [ 52, 34 ], evaluate_script("(() => { const r = document.querySelector('.source-band-mark').getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height)] })()")

    render_fragment(%(<div class="source-band"><svg class="source-band-mark" viewBox="0 0 120 78"></svg></div>), width: 375, height: 812)
    assert_equal [ 37, 24 ], evaluate_script("(() => { const r = document.querySelector('.source-band-mark').getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height)] })()")
  end

  test "已知天然尺寸的周刊配图解码前后不推移后文，手机与多图同样成立" do
    [ 375, 1440 ].each do |width|
      [ "item-media--single", "item-media--multiple" ].each do |layout|
        render_fragment(<<~HTML, width: width)
          <div class="item-media #{layout}">
            <figure class="item-media-frame item-media-frame--sized" style="--image-width:1200px;--image-ratio:1.5">
              <img class="item-media-image" width="1200" height="800" alt="横图">
            </figure>
            #{if layout == "item-media--multiple"
                '<figure class="item-media-frame item-media-frame--sized" style="--image-width:400px;--image-ratio:0.5"><img class="item-media-image" width="400" height="800" alt="竖图"></figure>'
              end}
          </div>
          <p id="after-media">下一段正文</p>
        HTML
        before = evaluate_script("document.querySelector('#after-media').getBoundingClientRect().top")
        execute_script(<<~JS)
          for (const image of document.images) {
            const w = Number(image.getAttribute('width')), h = Number(image.getAttribute('height'))
            image.src = 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="100%" height="100%" fill="black"/></svg>`)
          }
        JS
        wait_until { evaluate_script("[...document.images].every(image => image.complete && image.naturalWidth > 0)") }
        after = evaluate_script("document.querySelector('#after-media').getBoundingClientRect().top")
        assert_in_delta before, after, 0.5, "#{width}px #{layout}：解码不推移后文"
        assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
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
        const rects = [...document.querySelector('.item-title a').getClientRects()]
        const last = rects[rects.length - 1]
        const tag = document.querySelector('.item-tag').getBoundingClientRect()
        const heading = document.querySelector('.item-heading').getBoundingClientRect()
        return { wrapped: tag.top >= last.bottom - 1, left: tag.left - heading.left }
      })()
    JS

    assert offsets["wrapped"], "这个标题应把标签挤到下一行"
    assert_in_delta 0, offsets["left"], 1
  end

  # 终审：打印时横带底色去掉了，「翻开的书」挖空处却还填着墨，印出来是一块黑剪影
  test "D2 周刊横带的图形：屏幕上挖空填墨，打印时挖空透明" do
    band = %(<div class="source-band"><svg class="source-band-mark" viewBox="0 0 10 10"><path class="hole" fill="var(--band-hole)" d="M0 0h10v10H0z"/></svg></div>)
    render_fragment(band)
    assert_equal INK, style(".source-band .hole", "fill")

    render_fragment(band, media: "print")
    assert_equal "rgba(0, 0, 0, 0)", style(".source-band .hole", "fill")
  end

  # 终审：选区统一成墨底纸字后，墨底上的字（报头、横带、反白按钮）选中时成了墨上墨，看不见。墨底上反过来用纸底墨字
  test "T3 墨底上的字选中时是纸底墨字" do
    render_fragment(%(<header class="masthead"><a class="masthead-brand">lowpass</a></header><div class="source-band"><h2 class="source-band-title"><span>阮一峰科技爱好者周刊</span></h2></div><button class="btn-primary">搜索</button>))

    [ ".masthead-brand", ".source-band-title span", ".btn-primary" ].each do |selector|
      assert_equal PAPER, style(selector, "background-color", "::selection"), selector
      assert_equal INK, style(selector, "color", "::selection"), selector
    end
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
    # 与 ItemRow 的三种正文次序一致：HN 译文、GitHub 简介、无标签的周刊完整正文。
    # 只装生产 CSS 与静态结构；点击记录器阻止导航，书签没有持久化处理器，不发请求。
    def touch_item(title, variant)
      heading = variant == :weekly ? "h4" : "h2"
      tag = %(<span class="item-tag"><span class="chip-outline item-interest-chip">前端开发</span></span>) unless variant == :weekly
      copy = case variant
      when :translated
        %(<p class="item-translation">原文标题的中文译文，保持完整展示。</p>)
      when :summary
        %(<span class="item-summary">A complete summary that remains ordinary, nonlinked reading text.</span><p class="item-translation">这段简介的中文译文。</p>)
      when :weekly
        %(<div class="item-content item-content--weekly"><p><span style="font-family:var(--font-cjk);font-size:var(--fs-15);line-height:1.8">这是周刊的完整正文，按原文分段展示。</span></p><p><span style="font-family:var(--font-latin);font-size:var(--fs-15);line-height:1.8">The second paragraph remains part of the weekly reading column.</span></p></div>)
      end
      meta = if variant == :weekly
        %(<span class="data" data-protected>10-22 06:00</span>)
      else
        %(<div class="item-meta"><span class="item-metric" data-protected>382</span><a class="item-metric item-comments" href="#comments" data-touch="comments">147</a><time class="item-metric" data-protected>42d</time></div><div class="item-reason">与关注的领域相关，说明具体使用场景。</div>)
      end
      <<~HTML
        <div class="sheet-body" style="padding-top:40px"><article class="item-row"><span class="item-rank">1</span><div class="item-body">
          <div class="item-heading"><#{heading} class="item-title"><a class="t" href="#title" data-touch="title">#{ERB::Util.html_escape(title)}</a></#{heading}>#{tag}</div>
          #{copy}#{meta}
        </div><button type="button" class="favorite-button item-mark" aria-label="收藏" data-touch="bookmark">书签</button></article></div>
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
    def render_fragment(html, width: 1440, height: 900, reduced_motion: false, media: "", hover: false)
      css = STYLES.map { |name| Rails.root.join("app/frontend/styles", name) }.select(&:exist?).map(&:read).join("\n")
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
