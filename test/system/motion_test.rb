require "application_system_test_case"

# 三套主题共享阅读行为：来源连续、翻期有方向、正文立即可读；外观由各主题决定。
class MotionTest < ApplicationSystemTestCase
  setup do
    sign_in_with_browser(users(:drew))
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
    assert_equal sources(:hackaday).id, URI.decode_www_form(URI.parse(current_url).query).to_h.fetch("source")
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
    assert_includes anims.map { |a| [ a["pseudo"], a["name"] ] }, [ "::view-transition-new(root)", "lp-turn-in-left" ]
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

    def with_viewport(width, height)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      yield
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
end
