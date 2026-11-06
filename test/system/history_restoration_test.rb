require "application_system_test_case"

class HistoryRestorationTest < ApplicationSystemTestCase
  include ContinuousReadingHelpers

  setup do
    prepare_continuous_issue
    sign_in_with_browser(users(:drew))
  end

  teardown do
    begin
      execute_script("window.__historyFrameGateCleanup?.()") if @frame_gate_identifier
    ensure
      if @frame_gate_identifier
        page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @frame_gate_identifier)
      end
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    end
  end

  { "减少动态效果" => "reduce", "普通原生 VT" => "no-preference" }.each do |mode, preference|
    test "#{mode}：后退的绘制帧延迟时仍保留日刊阅读位置与历史快照" do
      # reduce 隔离 VT 变量；普通模式使用真实 VT，但本次 Back 可能在 updateCallbackDone 后，非特定缓冲窗口证明。
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: preference } ])
      @frame_gate_identifier = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: delayed_history_frames).fetch("identifier")

      source = sources(:github)
      reading_path = daily_issue_path("2026-09-08", source: source.id)
      visit reading_path
      assert_selector ".daily-source", count: 3
      wait_until { evaluate_script("window.scrollY > 0") }
      page.driver.browser.action.scroll_by(0, -(evaluate_script("innerHeight") * 0.78).round).perform
      evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
      reading_position = evaluate_script("window.scrollY")
      assert_operator reading_position, :>, 0
      wait_until { evaluate_script("window.history.state.documentScrollPosition?.top") == reading_position }

      # Search 真实归零的 scroll 事件安排原生 Back，避免 WebDriver 往返先耗掉框架的100ms记录窗口。
      execute_script("window.__historyFrameGate.backOnSearchScroll = true; document.querySelector('a[aria-label=搜索]').click()")
      wait_until { evaluate_script("window.__historyFrameGate.released") }
      assert_current_path reading_path
      assert_selector ".daily-source", count: 3
      evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")

      gate = evaluate_script("window.__historyFrameGate")
      assert_equal reading_position, gate.fetch("eventTop"), "原生 Back 必须选中离开前的阅读快照：#{gate.inspect}"
      assert_operator gate.fetch("queued"), :>, 0, "恢复帧必须实际经历延迟：#{gate.inspect}"
      assert_in_delta reading_position, evaluate_script("window.scrollY"), 2, "延迟后仍应回到原阅读位置：#{gate.inspect}"
      assert_equal reading_position, evaluate_script("window.history.state.documentScrollPosition?.top"), "历史快照不能被离开页的滚动记录覆盖：#{gate.inspect}"
    end
  end

  private
    def delayed_history_frames
      <<~JS
        (() => {
          const request = window.requestAnimationFrame.bind(window)
          const cancel = window.cancelAnimationFrame.bind(window)
          const pending = new Map()
          let held = false, nextId = 0, releaseTimer
          const gate = { backOnSearchScroll: false, queued: 0, released: false }
          window.__historyFrameGate = gate

          function onScroll() {
            if (!gate.backOnSearchScroll || location.pathname !== '/search' || scrollY !== 0) return
            gate.backOnSearchScroll = false
            setTimeout(() => history.back(), 0)
          }
          function onPopstate(event) {
            if (gate.eventTop !== undefined || !event.isTrusted || !location.pathname.startsWith('/daily/')) return
            const top = event.state?.documentScrollPosition?.top
            if (!(top > 0)) return
            gate.eventTop = top
            held = true
            releaseTimer = setTimeout(() => {
              // 基线可能已被旧记录写成0；修复允许它一直正确，因此只记录，不要求0。
              gate.beforeReleaseTop = history.state?.documentScrollPosition?.top
              gate.yBeforeRelease = scrollY
              held = false
              for (const [id, frame] of pending) {
                frame.nativeId = request(timestamp => {
                  pending.delete(id)
                  frame.callback.call(window, timestamp)
                })
              }
              gate.released = true
            }, 160)
          }
          window.addEventListener('scroll', onScroll, true)
          window.addEventListener('popstate', onPopstate, true)
          window.requestAnimationFrame = callback => {
            if (!held) return request(callback)
            const id = --nextId
            pending.set(id, { callback, nativeId: null })
            gate.queued++
            return id
          }
          window.cancelAnimationFrame = id => {
            const frame = pending.get(id)
            if (!frame) return cancel(id)
            if (frame.nativeId !== null) cancel(frame.nativeId)
            pending.delete(id)
          }
          window.__historyFrameGateCleanup = () => {
            clearTimeout(releaseTimer)
            window.removeEventListener('scroll', onScroll, true)
            window.removeEventListener('popstate', onPopstate, true)
            for (const frame of pending.values()) {
              if (frame.nativeId !== null) cancel(frame.nativeId)
            }
            pending.clear()
            window.requestAnimationFrame = request
            window.cancelAnimationFrame = cancel
          }
        })()
      JS
    end
end
