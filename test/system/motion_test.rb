require "application_system_test_case"

# 三套主题共享阅读行为：来源连续、翻期有方向、正文立即可读；外观由各主题决定。
class MotionTest < ApplicationSystemTestCase
  include ContinuousReadingHelpers
  setup do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
  end

  test "跨栏进度随自然滚动推进、停住和原路回退" do
    with_viewport(1200, 850) { assert_source_motion }
  end

  test "手机滚动也能控制来源过渡且没有横向溢出" do
    with_viewport(375, 812) do
      assert_source_motion
      assert evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    end
  end

  test "实际阅读窗口高度下也能停住进度并反向回退" do
    with_viewport(812, 1311) { assert_source_motion }
  end

  test "来源标题与首条全程保持固定间距，进入主要阅读区之前停止额外位移" do
    with_viewport(812, 1311) do
      source = sources(:github)
      visit daily_issue_path("2026-09-08")
      assert_selector ".daily-source", count: 3
      scroll_source_to(source, 0.82)
      before = source_motion_state(source)
      assert_in_delta before["normal_gap"], before["opening_gap"], 0.1, "标题后只有版式留白，不额外制造随滚动收缩的空白"
      page.driver.browser.action.scroll_by(0, 90).perform
      settle_scroll
      assert_in_delta before["opening_gap"], source_motion_state(source)["opening_gap"], 0.1, "正文不能相对标题追赶"
      scroll_source_to(source, 0.62)
      readable = source_motion_state(source)
      assert_equal 1, readable["progress"], "来源进入主要阅读区域前就应回到正常滚动"
      assert_equal 0, readable["content_offset"]
    end
  end

  test "减少动态效果时自然滚动直接显示终态" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit daily_issue_path("2026-09-08")
    execute_script("document.querySelector('#source-#{sources(:github).id}').scrollIntoView()")
    assert_no_selector ".daily-source[data-scroll-source]", visible: :all
    assert_equal "none", evaluate_script("getComputedStyle(document.querySelectorAll('.daily-source-sheet')[1]).transform")
    assert_text "GitHub story 1"
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "末尾只有一条的短来源滚到底仍完整可见，栏尾链接能命中" do
    with_viewport(812, 1311) do
      source = sources(:hackaday)
      ids = Item.where(issue: issues(:daily_0908), source: source).order(:rank).pluck(:id)
      Item.where(id: ids.drop(1)).update_all(hidden: true)
      visit daily_issue_path("2026-09-08")
      assert_selector "#source-#{source.id} .item-row", count: 1
      page.driver.browser.action.scroll_by(0, 100_000).perform
      settle_scroll
      assert_equal 1, source_motion_state(source)["progress"]
      assert_equal 0, source_motion_state(source)["content_offset"]
      assert_no_selector "#source-#{source.id}[data-source-opening]", visible: :all
      assert_source_link_hit(source)
    end
  end

  test "中间空栏目在过渡区也能用 Tab 到达可见的栏尾链接" do
    with_viewport(812, 1311) do
      source = sources(:github)
      issue = issues(:daily_0908)
      issue.update!(source_states: issue.source_states.merge(source.id => "empty"))
      visit daily_issue_path("2026-09-08")
      assert_selector "#source-#{source.id} .state-line", text: "本期未收录"
      execute_script("const section=document.querySelector('#source-#{source.id}'); window.scrollTo(0,section.getBoundingClientRect().top+scrollY-innerHeight*.8); section.focus({preventScroll:true})")
      settle_scroll
      page.driver.browser.switch_to.active_element.send_keys(:tab)
      settle_scroll
      assert evaluate_script("document.activeElement.matches('#source-#{source.id} .source-foot')")
      assert_no_selector "#source-#{source.id}[data-source-opening]", visible: :all
      assert_source_link_hit(source)
    end
  end

  test "深链直接定位，后退恢复相同的滚动进度与阅读位置" do
    source = sources(:github)
    visit daily_issue_path("2026-09-08", source: source.id)
    assert_selector ".daily-source", count: 3
    wait_until { source_motion_state(source)["progress"] == 1 }
    page.driver.browser.action.scroll_by(0, -(evaluate_script("innerHeight") * 0.78).round).perform
    settle_scroll
    reading_position = evaluate_script("window.scrollY")
    reading_state = source_motion_state(source)
    assert_operator reading_state["progress"], :>, 0
    assert_operator reading_state["progress"], :<, 1
    wait_until { evaluate_script("window.history.state.documentScrollPosition?.top") == reading_position }
    execute_script("document.querySelector('nav[aria-label=主导航] a[href=\"/search\"]').click()")
    assert_current_path search_path
    page.go_back
    assert_selector ".daily-source", count: 3
    wait_until { (evaluate_script("window.scrollY") - reading_position).abs < 2 }
    settle_scroll
    assert_in_delta reading_state["progress"], source_motion_state(source)["progress"], 0.005, source_motion_state(source).inspect
    paused = source_motion_state(source)
    evaluate_async_script("setTimeout(arguments[0], 350)")
    assert_equal paused, source_motion_state(source), "历史恢复后不应自行推进"
    page.go_forward
    assert_current_path search_path
    page.go_back
    assert_selector ".daily-source", count: 3
    wait_until { (evaluate_script("window.scrollY") - reading_position).abs < 2 }
    settle_scroll
    assert_in_delta reading_state["progress"], source_motion_state(source)["progress"], 0.005, source_motion_state(source).inspect
  end

  test "缩小窗口后使用新视口计算进度，停住后保持原位" do
    with_viewport(1200, 850) do
      source = sources(:github)
      visit daily_issue_path("2026-09-08")
      assert_selector ".daily-source", count: 3
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1200, height: 400, deviceScaleFactor: 1, mobile: false)
      execute_script("const head = document.querySelector('#source-#{source.id}'); window.scrollTo(0, head.getBoundingClientRect().top + scrollY - 320)")
      settle_scroll
      before = source_motion_state(source)
      assert_in_delta 0.5, before["progress"], 0.01
      page.driver.browser.action.scroll_by(0, 90).perform
      settle_scroll
      assert_operator source_motion_state(source)["progress"], :>, before["progress"]
      paused = source_motion_state(source)
      evaluate_async_script("setTimeout(arguments[0], 350)")
      assert_equal paused, source_motion_state(source)
    end
  end

  test "来源目录跟随主动选择，全部来源仍留在同一期连续正文中" do
    visit daily_issue_path("2026-09-08")
    assert_current_source sources(:hn)
    assert_selector ".source-section", count: 3

    within("nav[aria-label='本期来源']") { click_on sources(:hackaday).name }
    assert_current_source sources(:hackaday)
    assert_selector ".source-section", count: 3
    assert_selector "#item-#{items(:hn_one).id}"
    assert_source_in_view sources(:hackaday)
  end

  test "连点两个来源后最终目录标记和定位停在第二个来源" do
    visit daily_issue_path("2026-09-08")

    within("nav[aria-label='本期来源']") { click_on sources(:github).name }
    within("nav[aria-label='本期来源']") { click_on sources(:hackaday).name }
    assert_current_source sources(:hackaday)
    assert_source_in_view sources(:hackaday)
    assert_equal "source-#{sources(:hackaday).id}", URI.parse(current_url).fragment
  end

  test "三套主题窄屏导航与编号保留各自版式，来源都能到达且不溢出" do
    with_viewport(320, 844) do
      visit daily_issue_path("2026-09-08")
      %w[daybreak duet unfold].each do |theme|
        select_theme theme
        within("nav[aria-label='本期来源']") { click_on sources(:github).name }
        assert_current_source sources(:github)
        assert_source_in_view sources(:github)
        assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{theme} 手机页不应横向溢出"
        assert evaluate_script(<<~JS), "#{theme} 主导航不应掉到页眉外覆盖正文"
          (() => {
            const head = document.querySelector('.masthead').getBoundingClientRect()
            const nav = document.querySelector('.masthead-nav').getBoundingClientRect()
            return nav.top >= head.top && nav.bottom <= head.bottom + 1
          })()
        JS
        if theme == "duet"
          assert_in_delta 0, evaluate_script("document.querySelector('.source-tabs-frame').getBoundingClientRect().top - document.querySelector('.masthead').getBoundingClientRect().bottom"), 1
          assert_equal "1px", evaluate_script("getComputedStyle(document.querySelector('.item-rank')).borderTopWidth")
          assert_equal "solid", evaluate_script("getComputedStyle(document.querySelector('.item-rank')).borderTopStyle")
        end
      end
    end
  end

  test "切换主题保留收藏搜索草稿、原文展开和收藏状态，关闭后焦点回入口" do
    item = items(:hn_one)
    item.update!(title_zh: "用 Rust 写的终端日志查看器")
    Favorite.keep(users(:drew), item)
    visit favorites_path
    fill_in "搜索收藏", with: "Rust 未提交草稿"
    find(".record-detail > summary").click
    assert_selector ".record-detail[open]", text: item.title

    %w[duet unfold].each do |theme|
      select_theme theme
      assert_field "搜索收藏", with: "Rust 未提交草稿"
      assert_selector ".record-detail[open]", text: item.title
      assert_selector ".favorite-button[data-on]"
      assert_selector ".theme-menu > summary:focus"
      assert_current_path favorites_path
    end
    assert_equal 1, users(:drew).favorites.count
  end

  test "左右键翻期，最新一期下一期禁用，搜索输入框内方向键不触发翻期" do
    create_previous_issue
    visit daily_issue_path("2026-09-08")
    assert_selector ".period-controls [role='link'][aria-disabled='true']", text: "下一期"
    assert_no_selector ".period-controls a", text: "下一期"

    find("body").send_keys(:right)
    assert_current_path daily_issue_path("2026-09-08")

    find("body").send_keys(:left)
    assert_current_path daily_issue_path("2026-09-07")
    assert_no_selector "html[data-vt]", visible: :all, wait: 2

    find("body").send_keys(:right)
    assert_current_path daily_issue_path("2026-09-08")
    assert_no_selector "html[data-vt]", visible: :all, wait: 2

    within("nav[aria-label='主导航']") { click_on "搜索" }
    assert_selector "#search-query"
    find("#search-query").send_keys(:left)
    assert_current_path search_path
  end

  test "上一期控件带键盘提示并能跳到对应日期" do
    create_previous_issue
    visit daily_issue_path("2026-09-08")

    assert_selector ".period-controls a.ctrl[aria-keyshortcuts='ArrowLeft']", text: "上一期"
    find(".period-controls a.ctrl", text: "上一期").click
    assert_current_path daily_issue_path("2026-09-07")
  end

  test "三主题刊头和页脚翻期始终无底色，保留触控高度与禁用语义" do
    create_previous_issue
    [ 1440, 390 ].each do |width|
      with_viewport(width, 900) do
        visit daily_issue_path("2026-09-08")
        %w[daybreak duet unfold].each do |theme|
          select_theme theme
          all(".period-controls .ctrl, .footer-turns .ctrl").each do |control|
            background = -> { control.evaluate_script("getComputedStyle(this).backgroundColor") }
            assert_equal "rgba(0, 0, 0, 0)", background.call, "#{theme}/#{width} 默认翻期底色"
            assert_operator control.native.rect.height, :>=, 44
            control.hover
            sleep 0.25
            assert_equal "rgba(0, 0, 0, 0)", background.call, "#{theme}/#{width} 悬停翻期底色"
            if control["aria-disabled"] == "true"
              assert_nil control["href"]
            end
          end
        end
      end
    end
  end

  test "首屏正文立即可读，不播隐形开场；刷新保留阅读主题" do
    execute_script("sessionStorage.clear()")
    visit daily_issue_path("2026-09-08")
    assert_no_selector "html[data-first-load]", visible: :all
    assert_selector "#item-#{items(:hn_one).id}"
    assert evaluate_script(<<~JS), "正文及祖先不应为开场动画先隐藏"
      (() => {
        let node = document.querySelector('.item-row')
        while (node && node !== document.body) {
          const style = getComputedStyle(node)
          if (style.opacity !== '1' || style.visibility === 'hidden') return false
          node = node.parentElement
        }
        return true
      })()
    JS

    select_theme "unfold"
    refresh
    assert_selector "html[data-theme='unfold']", visible: :all
    assert_no_selector "html[data-first-load]", visible: :all
    assert_selector "#item-#{items(:hn_one).id}"
  end

  test "打印三套主题时所有来源都保留，书签和来源目录不印" do
    visit daily_issue_path("2026-09-08")
    %w[daybreak duet unfold].each do |theme|
      select_theme theme
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")

      assert_selector ".print-source-name", count: 3
      assert_equal [ sources(:hn).name, sources(:github).name, sources(:hackaday).name ].sort, all(".print-source-name").map(&:text).sort
      assert_selector "#item-#{items(:hn_one).id}"
      assert_no_selector ".favorite-button"
      assert_no_selector ".source-tabs-frame"
      assert_equal "none", evaluate_script("getComputedStyle(document.querySelectorAll('.daily-source-sheet')[1]).transform")
      assert_equal "1", evaluate_script("getComputedStyle(document.querySelectorAll('.daily-source')[1].querySelector('.item-row')).opacity")
      assert_no_selector ".period-controls"
      assert_equal "rgb(255, 255, 255)", evaluate_script("getComputedStyle(document.body).backgroundColor")
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
      assert_selector "nav[aria-label='本期来源']"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  test "从页脚翻期时报头不随滚动距离位移，正文按翻期方向过渡" do
    create_previous_issue
    visit daily_issue_path("2026-09-08")
    execute_script(<<~JS)
      document.querySelector('#main-content').style.paddingBottom = '2000px'
      window.scrollTo(0, document.documentElement.scrollHeight)
      window.__anims = null
      const start = document.startViewTransition.bind(document)
      document.startViewTransition = (...args) => {
        const transition = start(...args)
        transition.ready.then(() => {
          window.__anims = document.getAnimations().filter((a) => a.effect && a.effect.pseudoElement).map((a) => ({
            pseudo: a.effect.pseudoElement, name: a.animationName, transforms: a.effect.getKeyframes().map((frame) => frame.transform || 'none')
          }))
        })
        return transition
      }
    JS
    find("footer a.ctrl", text: "上一期").click
    wait_until { evaluate_script("window.__anims") }
    anims = evaluate_script("window.__anims")

    moving = anims.select { |a| a["pseudo"].match?(/group\((masthead|issue-date)\)/) && a["transforms"].any? { |t| t != "none" } }
    assert_empty moving, "报头与期头的过渡组不应跨越滚动距离：#{moving.inspect}"
    assert_includes anims.map { |a| [ a["pseudo"], a["name"] ] }, [ "::view-transition-old(root)", "lp-turn-out-right" ]
    assert_empty anims.select { |a| a["pseudo"] == "::view-transition-new(root)" }, "NEW 不进入命名捕获"
    assert_current_path daily_issue_path("2026-09-07")
    assert_no_selector "html[data-vt]", visible: :all, wait: 2
  end

  test "主导航换页使用过渡并在结束后清除过渡标记" do
    visit daily_issue_path("2026-09-08")
    execute_script(<<~JS)
      window.__vt = false
      new MutationObserver(() => { if (document.documentElement.hasAttribute('data-vt')) window.__vt = true }).observe(document.documentElement, { attributes: true })
    JS
    within("nav[aria-label='主导航']") { click_on "周刊" }
    assert_current_path %r{\A/weekly}
    wait_until { evaluate_script("window.__vt") }
    assert_no_selector "html[data-vt]", visible: :all, wait: 2
  end

  private
    def create_previous_issue
      Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    end

    def select_theme(theme)
      find(".theme-menu > summary").click
      assert evaluate_script(<<~JS), "外观选择器应完整留在视口内"
        (() => {
          const box = document.querySelector('.theme-menu-panel').getBoundingClientRect()
          return box.left >= 0 && box.right <= innerWidth
        })()
      JS
      find(".theme-choice[data-preview='#{theme}']").click
      assert_selector "html[data-theme='#{theme}']", visible: :all
      evaluate_async_script("const done = arguments[0]; requestAnimationFrame(() => document.fonts.ready.then(done))")
      find(".theme-menu > summary").send_keys(:escape)
    end

    def assert_current_source(source)
      assert_selector "nav[aria-label='本期来源'] a[aria-current='location']", count: 1
      assert_selector "nav[aria-label='本期来源'] a[aria-current='location'][href='#source-#{source.id}']", text: source.name
      assert_selector "#source-#{source.id}"
    end

    def assert_source_in_view(source)
      wait_until do
        evaluate_script(<<~JS)
          (() => {
            const box = document.getElementById(#{"source-#{source.id}".to_json}).getBoundingClientRect()
            return box.top < innerHeight && box.bottom > 0
          })()
        JS
      end
    end

    def assert_source_link_hit(source)
      assert evaluate_script(<<~JS), "栏尾链接必须在视口里可见且可点击，不能被裁切"
        (() => {
          const link=document.querySelector('#source-#{source.id} .source-foot')
          const rect=link.getBoundingClientRect()
          const hit=document.elementFromPoint(rect.left+rect.width/2,rect.top+rect.height/2)
          return rect.top>=0 && rect.bottom<=innerHeight && (hit===link || link.contains(hit))
        })()
      JS
    end

    def assert_source_motion
      visit daily_issue_path("2026-09-08")
      assert_selector ".daily-source", count: 3
      assert_selector ".daily-source[data-scroll-source]", count: 2
      [ sources(:github), sources(:hackaday) ].each do |source|
        scroll_source_to(source, 0.84)
        middle = source_motion_state(source)
        assert_operator middle["progress"], :>, 0
        assert_operator middle["progress"], :<, 1
        assert_in_delta middle["heading_offset"], middle["content_offset"], 0.1, "标题与正文作为同一阅读单元移动"
        assert_in_delta middle["normal_gap"], middle["opening_gap"], 0.1, "标题后保持静态版式间距，不制造第二次停顿"
        assert_operator middle["content_offset"], :>, 8
        assert_equal "1", middle["opacity"]
        assert_equal "1", middle["heading_opacity"]
        assert_equal 0, middle["animations"], "进度不依赖时间动画"
        assert_equal "none", middle["rule"], "细线不单独位移，随整个阅读单元接入"
        assert_equal 0, middle["previous_offset"], "上一来源保持原位"
        assert_equal 1, middle["colors"].uniq.size, "正文维持实墨，不用迟到的墨色打断阅读"

        evaluate_async_script("setTimeout(arguments[0], 350)")
        assert_equal middle, source_motion_state(source), "停止滚动后，正文位移与链接墨色都不能自行推进"
        page.driver.browser.action.scroll_by(0, -90).perform
        settle_scroll
        backward = source_motion_state(source)
        assert_operator backward["progress"], :<, middle["progress"]
        assert_operator backward["content_offset"], :>, middle["content_offset"]
        assert_in_delta middle["opening_gap"], backward["opening_gap"], 0.1, "反向滚动也不能把标题与首条拆开"
        assert_operator backward["content_offset"] - middle["content_offset"], :>=, 8, "过渡仍应产生可辨认的整体接入幅度"
        page.driver.browser.action.scroll_by(0, 90).perform
        settle_scroll
        assert_equal middle, source_motion_state(source), "回到同一位置应恢复同一画面"

        scroll_source_to(source, 0.62)
        finished = source_motion_state(source)
        assert_equal 1, finished["progress"]
        assert_equal 0, finished["content_offset"]
        assert_equal 0, finished["heading_offset"]
        assert_equal 1, finished["colors"].uniq.size
        distance = (evaluate_script("innerHeight") * 0.28).round
        page.driver.browser.action.scroll_by(0, -distance).perform
        settle_scroll
        assert_operator source_motion_state(source)["progress"], :<, 1, "完成后上滑也应自然回退，不需要重新待命"
        page.driver.browser.action.scroll_by(0, distance).perform
        settle_scroll
        assert_equal finished, source_motion_state(source)
      end
    end

    def scroll_source_to(source, fraction)
      # 原生 wheel 输入，不给正文手动设置进度或动画标记。
      100.times do
        break if evaluate_script("document.querySelector('#source-#{source.id}').getBoundingClientRect().top < innerHeight * #{fraction}")
        page.driver.browser.action.scroll_by(0, 90).perform
      end
      settle_scroll
    end

    def settle_scroll
      evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
    end

    def source_motion_state(source)
      evaluate_script(<<~JS)
        (() => {
          const section = document.querySelector('#source-#{source.id}')
          const sheet = section.querySelector('.daily-source-sheet')
          const content = section.querySelector('.daily-source-content')
          const heading = section.querySelector('.daily-source-heading')
          const rows = [...content.querySelectorAll('.item-row')].slice(0, 3)
          const offset = element => new DOMMatrixReadOnly(getComputedStyle(element).transform).m42
          return {
            progress: Number(section.style.getPropertyValue('--source-progress')),
            source_top: section.getBoundingClientRect().top,
            scroll_y: scrollY,
            heading_offset: offset(heading) + offset(sheet), content_offset: offset(content) + offset(sheet),
            opening_gap: content.getBoundingClientRect().top - heading.getBoundingClientRect().bottom,
            normal_gap: section.querySelector('.daily-source-head').getBoundingClientRect().bottom - heading.getBoundingClientRect().bottom,
            colors: rows.map(row => getComputedStyle(row).color),
            link_color: getComputedStyle(rows[0].querySelector('a.t')).color,
            opacity: getComputedStyle(rows[0]).opacity, heading_opacity: getComputedStyle(heading).opacity,
            animations: content.getAnimations().length,
            rule: getComputedStyle(section.querySelector('.daily-source-rule')).transform,
            previous_offset: offset(section.previousElementSibling.querySelector('.daily-source-sheet'))
          }
        })()
      JS
    end

    def with_viewport(width, height)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      yield
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
end
