require "application_system_test_case"

# 自然原生时钟：不暂停、不改速率、不延长 240/360ms。
class PageTurnTest < ApplicationSystemTestCase
  setup do
    sign_in_with_browser(users(:drew))
  end

  test "NEW 不捕获且正文固定，OLD 与真实正文共用 native 起点" do
    [ 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit daily_issue_path("2026-09-08")
      record_turn
      execute_script("document.querySelector('a[aria-label=搜索]').click()")
      wait_until { evaluate_script("window.__turn?.finished") }
      state = evaluate_script("window.__turn")
      puts "M2_NATIVE #{state.to_json}"
      assert_nil state["error"]
      assert_equal "new", state["phase"]
      assert_equal [ "none", "none" ], state["names"]
      assert state["native"], "OLD root 必须有实际 native animation"
      assert state["incoming"], "NEW 必须有实际 opacity animation"
      assert_not_nil state["animationReady"]["start"]
      assert_equal state["animationReady"]["start"], state["incomingReady"]["start"]
      assert state["sameTimeline"]
      assert_equal 240, state["native"]["duration"]
      assert_equal 240, state["incoming"]["duration"]
      assert_equal state["rects"].first, state["rects"].last
      assert_equal "none", state["transform"]
      assert_equal "border-box", state["origin"]
      assert_equal state["offset"], state["position"]
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "pending OLD 与 NEW 在同一次原生 update 获得严格相同起点" do
    Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    captures = []
    [ 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      [ "a[aria-label=搜索]", ".issue-nav a[aria-keyshortcuts=ArrowLeft]" ].each do |selector|
        visit daily_issue_path("2026-09-08")
        record_turn
        execute_script("document.querySelector(#{selector.to_json}).click()")
        wait_until { evaluate_script("window.__turn?.finished") }
        state = evaluate_script("window.__turn")
        state["width"] = width
        state["selector"] = selector
        state["chrome"] = page.driver.browser.capabilities.browser_version
        captures << state
        puts "M2_CLOCK #{state.to_json}"
      end
    end
    captures.each do |state|
      assert state["native"], state.inspect
      assert_not_nil state["animationReady"]["start"], state.inspect
      assert_equal state["animationReady"]["start"], state["incomingReady"]["start"], state.inspect
      assert state["sameTimeline"], state.inspect
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private
    def record_turn
      execute_script(<<~JS)
        window.__turn = {}
        const start = document.startViewTransition.bind(document)
        document.startViewTransition = callback => {
          const transition = start(callback)
          transition.ready.then(() => queueMicrotask(() => {
            const s = window.__turn
            const root = document.documentElement
            const surface = document.querySelector('.sheet-body, .login-ground')
            const paper = surface.closest('.paper')
            const rect = surface.getBoundingClientRect()
            const p = paper.getBoundingClientRect()
            const old = document.getAnimations().find(a => a.effect?.pseudoElement === '::view-transition-old(root)')
            const incoming = surface.getAnimations().find(a => a.effect?.target === surface)
            const dateState = () => ({scrollY, rect: document.querySelector('.issue-head-date')?.getBoundingClientRect().toJSON(), groupTransform: getComputedStyle(root, '::view-transition-group(issue-date)').transform})
            const read = a => a && ({start: a.startTime, current: a.currentTime, duration: a.effect.getTiming().duration, pending: a.pending, playState: a.playState, timeline: a.timeline?.constructor.name, timelineTime: a.timeline?.currentTime})
            Object.assign(s, {readyAt: performance.now(), dateAtReady: dateState(), phase: root.dataset.vt,
              names: [getComputedStyle(root).viewTransitionName, getComputedStyle(document.querySelector('.masthead')).viewTransitionName],
              native: read(old), incoming: read(incoming), sameTimeline: old?.timeline === incoming?.timeline,
              origin: surface.style.backgroundOrigin, position: surface.style.backgroundPosition,
              offset: `${p.left-rect.left}px ${p.top-rect.top}px`, transform: getComputedStyle(surface).transform,
              rects: [JSON.stringify(rect)]})
            incoming?.ready.then(() => { s.incomingReady = read(incoming) })
            old?.ready.then(() => { s.dateAtAnimationReady = dateState(); s.animationReadyAt = performance.now(); s.animationReady = read(old) })
            requestAnimationFrame(t => { s.dateAtFirstFrame = dateState(); s.firstFrameAt = t; s.firstFrameNative = read(old); s.rects.push(JSON.stringify(surface.getBoundingClientRect())) })
          }), error => { window.__turn.error = String(error) })
          transition.finished.then(() => queueMicrotask(() => { window.__turn.finished = true; window.__turn.restored = document.querySelector('.sheet-body, .login-ground').getAttribute('style') }))
          return transition
        }
      JS
    end
end
