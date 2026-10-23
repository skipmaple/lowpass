require "application_system_test_case"

class SearchReturnScrollRaceTest < ApplicationSystemTestCase
  setup do
    sign_in_with_browser(users(:drew))
    Rails.cache.clear
    Search::Record.rebuild!
  end

  teardown do
    if @frame_gate_identifier
      begin
        execute_script("window.__searchReturnRaceCleanup?.()")
      ensure
        page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @frame_gate_identifier)
      end
    end
  end

  test "搜索返回的恢复帧延迟时仍保留第十三条阅读位置" do
    entries = (1..16).map do |rank|
      Adapters::Entry.new(title: "historyfocus result #{rank}", url: "https://r.example/#{rank}", section: "工具", rank: rank,
                         meta: { issue_no: 366, issue_title: "慢下来的理由", anchor: "工具" })
    end
    issues(:weekly_w36).replace_section!(sources(:ruanyf), entries, issue_no: 366)
    @frame_gate_identifier = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: delayed_search_return_frames).fetch("identifier")

    visit search_path(q: "historyfocus")
    assert_text "16 条结果"
    evaluate_async_script("document.fonts.ready.then(arguments[0])")
    target = all(".search-links > a:first-child")[12]
    execute_script("arguments[0].scrollIntoView({ block: 'center' }); arguments[0].focus({ preventScroll: true })", target)
    reading_position = evaluate_script("scrollY")
    assert_operator reading_position, :>, 500
    wait_until { evaluate_script("history.state.documentScrollPosition?.top") == reading_position }

    # 用真实周刊滚动触发原生 Back，不让 WebDriver 往返耗掉旧记录的100ms窗口。
    execute_script("window.__searchReturnRace.backOnWeeklyScroll = true")
    target.send_keys(:enter)
    wait_until { evaluate_script("window.__searchReturnRace.released") }
    assert_current_path search_path(q: "historyfocus")
    assert_selector ".search-row:nth-child(13) .search-links > a:first-child:focus"
    evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")

    gate = evaluate_script("window.__searchReturnRace")
    assert_equal reading_position, gate.fetch("eventTop"), "原生 Back 必须带回原阅读快照：#{gate.inspect}"
    assert_operator gate.fetch("queued"), :>, 0, "框架恢复帧必须真正经历延迟：#{gate.inspect}"
    assert gate.fetch("weeklySeen"), "必须经过真实周刊组件与滚动：#{gate.inspect}"
    assert_equal "pollution-observed", gate.fetch("releaseReason"), "只有实际旧任务覆盖后才释放恢复帧：#{gate.inspect}"
    refute_equal reading_position, gate.fetch("beforeReleaseTop"), "恢复前必须实际观察到旧滚动任务覆盖快照：#{gate.inspect}"
    assert_in_delta gate.fetch("yBeforeRelease"), gate.fetch("beforeReleaseTop"), 2
    assert_in_delta reading_position, evaluate_script("scrollY"), 2, "延迟后仍应恢复第十三条的原阅读位置：#{gate.inspect}"
    assert_equal reading_position, evaluate_script("history.state.documentScrollPosition?.top")
  ensure
    trace = evaluate_script("window.__searchReturnRace ? { gate: window.__searchReturnRace, events: window.__searchReturnRaceEvents } : null")
    puts "SEARCH_RETURN_SCROLL_RACE #{JSON.generate(trace)}"
  end

  private
    def delayed_search_return_frames
      <<~JS
        (() => {
          const request = window.requestAnimationFrame.bind(window)
          const cancel = window.cancelAnimationFrame.bind(window)
          const replace = history.replaceState
          const scroll = window.scrollTo
          const intoView = Element.prototype.scrollIntoView
          const pending = new Map(), events = []
          let held = false, nextId = 0, releaseTimer
          const gate = { backOnWeeklyScroll: false, queued: 0, released: false, weeklySeen: false, dropped: 0 }
          window.__searchReturnRace = gate
          window.__searchReturnRaceEvents = events

          const top = state => Number.isFinite(state?.documentScrollPosition?.top) ? state.documentScrollPosition.top : null
          const route = () => location.pathname + location.search + location.hash
          const stack = () => (new Error().stack || '').split('\\n').slice(2, 8).map(line => line.replace(/https?:\\/\\/[^/\\s)]+/g, '').slice(0, 200))
          function record(kind, extra = {}) {
            if (events.length >= 160) { gate.dropped++; return }
            events.push({ seq: events.length + 1, kind, ms: performance.now(), route: route(), y: scrollY, liveTop: top(history.state), ...extra })
          }
          history.replaceState = function (...args) {
            record('replaceState:before', { argumentTop: top(args[0]), stack: stack() })
            const result = Reflect.apply(replace, this, args)
            record('replaceState:after', { argumentTop: top(args[0]) })
            releaseIfReady()
            return result
          }
          window.scrollTo = function (...args) {
            record('scrollTo:before', { requestedTop: typeof args[0] === 'number' ? args[1] : args[0]?.top, stack: stack() })
            const result = Reflect.apply(scroll, this, args)
            record('scrollTo:after', { height: document.documentElement.scrollHeight })
            return result
          }
          Element.prototype.scrollIntoView = function (...args) {
            record('scrollIntoView:before', { targetId: this.id, stack: stack() })
            const result = Reflect.apply(intoView, this, args)
            record('scrollIntoView:after', { targetId: this.id })
            return result
          }
          function onScroll() {
            record('scroll')
            if (!gate.backOnWeeklyScroll || location.pathname !== '/weekly/2026-W36') return
            if (!document.querySelector("section[id='issue-366-%E5%B7%A5%E5%85%B7']")) return
            gate.backOnWeeklyScroll = false
            gate.weeklySeen = !!document.querySelector("section[id='issue-366-%E5%B7%A5%E5%85%B7']")
            record('native-back-scheduled')
            setTimeout(() => history.back(), 0)
          }
          function onPopstate(event) {
            record('popstate', { trusted: event.isTrusted, eventTop: top(event.state) })
            if (gate.eventTop !== undefined || !event.isTrusted || location.pathname !== '/search') return
            const snapshotTop = top(event.state)
            if (!(snapshotTop > 0)) return
            gate.eventTop = snapshotTop
            held = true
            // 以真实写回为条件，避免用固定延时猜测慢 CI 上的任务先后。
            releaseTimer = setTimeout(() => releaseFrames('watchdog'), 4000)
          }
          function releaseFrames(reason) {
            if (!held) return
            clearTimeout(releaseTimer)
            gate.releaseReason = reason
            gate.beforeReleaseTop = top(history.state)
            gate.yBeforeRelease = scrollY
            record('frames-release', { queued: gate.queued, reason })
            held = false
            for (const [id, frame] of pending) {
              frame.nativeId = request(timestamp => {
                pending.delete(id)
                record('held-frame-start', { id })
                frame.callback.call(window, timestamp)
              })
            }
            gate.released = true
          }
          function releaseIfReady() {
            if (held && pending.size > 0 && location.pathname === '/search' && Number.isFinite(top(history.state)) && top(history.state) !== gate.eventTop) releaseFrames('pollution-observed')
          }
          function onNavigate(event) {
            record('inertia:navigate', { component: event.detail.page.component, pageUrl: event.detail.page.url })
          }
          window.addEventListener('scroll', onScroll, true)
          window.addEventListener('popstate', onPopstate, true)
          document.addEventListener('inertia:navigate', onNavigate, true)
          window.requestAnimationFrame = callback => {
            if (!held) return request(callback)
            const id = --nextId
            pending.set(id, { callback, nativeId: null })
            gate.queued++
            record('frame-held', { id })
            releaseIfReady()
            return id
          }
          window.cancelAnimationFrame = id => {
            const frame = pending.get(id)
            if (!frame) return cancel(id)
            if (frame.nativeId !== null) cancel(frame.nativeId)
            pending.delete(id)
            record('held-frame-cancelled', { id })
          }
          window.__searchReturnRaceCleanup = () => {
            clearTimeout(releaseTimer)
            window.removeEventListener('scroll', onScroll, true)
            window.removeEventListener('popstate', onPopstate, true)
            document.removeEventListener('inertia:navigate', onNavigate, true)
            for (const frame of pending.values()) {
              if (frame.nativeId !== null) cancel(frame.nativeId)
            }
            pending.clear()
            window.requestAnimationFrame = request
            window.cancelAnimationFrame = cancel
            history.replaceState = replace
            window.scrollTo = scroll
            Element.prototype.scrollIntoView = intoView
          }
        })()
      JS
    end
end
