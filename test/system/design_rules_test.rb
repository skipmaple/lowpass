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
    render_fragment(%(<div style="padding: 40px"><a class="ctrl" href="#p">前一期</a> <span class="ctrl ctrl-off">后一期</span></div>))

    assert_equal "matrix(1, 0, 0, 0, 0, 0)", style(".ctrl:not(.ctrl-off)", "transform", "::before")
    find("a.ctrl").hover
    wait_until { style("a.ctrl", "color") == PAPER }
    wait_until { style("a.ctrl", "transform", "::before") == "matrix(1, 0, 0, 1, 0, 0)" }
    assert_equal "none", style(".ctrl-off", "content", "::before")
  end

  test "M4 未选中的索引条与分段控件悬停只加下划线，不反白" do
    render_fragment(%(<div class="source-tabs"><button class="source-tab" data-state="active"><span class="source-tab-name">A</span></button><button class="source-tab" data-state="inactive"><span class="source-tab-name">B</span></button></div>))

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

  private
    def render_fragment(html, width: 1440, height: 900, reduced_motion: false, media: "")
      css = STYLES.map { |name| Rails.root.join("app/frontend/styles", name) }.select(&:exist?).map(&:read).join("\n")
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
