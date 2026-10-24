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

  test "可信搜索 pointerdown 同步收尾并保持原生光标落点输入" do
    point = begin_input_turn("input[type=search]")
    assert_equal "abcdef", point["value"] if point["input"]
    mouse("mousePressed", point, "left", 1)
    assert_nil evaluate_script("document.documentElement.dataset.vt"), input_record
    assert_equal "search", evaluate_script("document.activeElement.type"), input_record
    mouse("mouseReleased", point, "left", 0)
    assert_equal 3, evaluate_script("document.activeElement.selectionStart"), input_record
    page.driver.browser.execute_cdp("Input.insertText", text: "X")
    assert_equal "abcXdef", evaluate_script("document.querySelector('input[type=search]').value")
    assert_trusted_input("pointerdown")
  end

  test "可信账户点击保留焦点与 Escape，按下后拖出释放不激活" do
    point = begin_input_turn(".account-button")
    assert_equal "abcdef", point["value"] if point["input"]
    mouse("mousePressed", point, "left", 1)
    assert_nil evaluate_script("document.documentElement.dataset.vt"), input_record
    mouse("mouseReleased", point, "left", 0)
    assert_selector "[role=menu]"
    assert evaluate_script("document.activeElement.matches('[role=menuitem]')"), evaluate_script("document.activeElement.outerHTML")
    page.driver.browser.execute_cdp("Input.dispatchKeyEvent", type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27)
    page.driver.browser.execute_cdp("Input.dispatchKeyEvent", type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27)
    assert_no_selector "[role=menu]"
    assert evaluate_script("document.activeElement.matches('.account-button')")
    assert_trusted_input("pointerdown")

    point = begin_input_turn(".account-button")
    mouse("mousePressed", point, "left", 1)
    outside = { "x" => point["x"] - 160, "y" => point["y"] + 180 }
    mouse("mouseMoved", outside, "left", 1)
    mouse("mouseReleased", outside, "left", 0)
    assert_no_selector "[role=menu]"
    assert_equal 0, evaluate_script("window.__input.filter(e=>e.type==='click' && e.target.includes('account-button')).length"), input_record
  end

  test "真实触摸模拟 tap 和输入保持默认动作，pan 产生 pointercancel 且无按钮激活" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 812, deviceScaleFactor: 1, mobile: true)
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    point = begin_input_turn(".account-button")
    touch("touchStart", point)
    touch("touchEnd")
    assert_selector "[role=menu]"
    assert_trusted_input("pointerdown")
    assert_equal "touch", evaluate_script("window.__input.find(e=>e.type==='pointerdown').pointerType")

    point = begin_input_turn("input[type=search]")
    touch("touchStart", point)
    touch("touchEnd")
    assert_equal "search", evaluate_script("document.activeElement.type")
    page.driver.browser.execute_cdp("Input.insertText", text: "X")
    assert_includes evaluate_script("document.querySelector('input[type=search]').value"), "X"
    assert_trusted_input("pointerdown")

    point = begin_input_turn(".account-button", daily: true)
    touch("touchStart", point)
    touch("touchMove", { "x" => point["x"], "y" => point["y"] + 180 })
    touch("touchEnd")
    assert_no_selector "[role=menu]"
    events = evaluate_script("window.__input")
    assert events.any? { |event| event["type"] == "pointercancel" && event["trusted"] }, events.inspect
    assert_equal 0, events.count { |event| event["type"] == "click" && event["trusted"] }, events.inspect
    assert_trusted_input("pointerdown")
  ensure
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "原生 wheel 与键盘输入同步收尾，滚动和文字输入仍执行" do
    point = begin_input_turn(".sheet-body", daily: true)
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseWheel", x: 300, y: 300, deltaX: 0, deltaY: 150)
    wait_until { evaluate_script("window.__input.some(e=>e.type==='wheel')") }
    assert_nil evaluate_script("document.documentElement.dataset.vt"), input_record
    wait_until { evaluate_script("scrollY") > 0 }
    assert_trusted_input("wheel")

    begin_input_turn("input[type=search]")
    page.driver.browser.execute_cdp("Input.dispatchKeyEvent", type: "keyDown", key: "x", code: "KeyX", text: "x", windowsVirtualKeyCode: 88)
    page.driver.browser.execute_cdp("Input.dispatchKeyEvent", type: "keyUp", key: "x", code: "KeyX", windowsVirtualKeyCode: 88)
    assert_nil evaluate_script("document.documentElement.dataset.vt"), input_record
    assert_includes evaluate_script("document.querySelector('input[type=search]').value"), "x"
    assert_trusted_input("keydown")
  end

  test "正文拖选保留原生选择，收藏与修饰键原文链接保留默认结果" do
    items(:hn_one).update!(summary: "Readable native selection keeps this text intact during the page turn.")
    point = begin_input_turn(".item-summary", daily: true)
    mouse("mousePressed", point, "left", 1)
    mouse("mouseMoved", { "x" => point["x"] + 100, "y" => point["y"] }, "left", 1)
    mouse("mouseReleased", { "x" => point["x"] + 100, "y" => point["y"] }, "left", 0)
    assert_not_empty evaluate_script("getSelection().toString()"), input_record
    assert_trusted_input("pointerdown")

    point = begin_input_turn(".favorite-button", daily: true)
    mouse("mousePressed", point, "left", 1)
    mouse("mouseReleased", point, "left", 0)
    assert_selector ".favorite-button[data-on]"
    assert_trusted_input("pointerdown")

    point = begin_input_turn(".item-row a.t", daily: true, prepare: "document.querySelector('.item-row a.t').href = location.origin + '/health'")
    original = page.driver.browser.window_handle
    before = page.driver.browser.window_handles
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mousePressed", x: point["x"], y: point["y"], button: "left", buttons: 1, clickCount: 1, modifiers: 4)
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseReleased", x: point["x"], y: point["y"], button: "left", buttons: 0, clickCount: 1, modifiers: 4)
    wait_until { page.driver.browser.window_handles.size > before.size }
    assert_trusted_input("pointerdown")
    (page.driver.browser.window_handles - before).each do |handle|
      page.driver.browser.switch_to.window(handle)
      assert_match %r{/health}, page.driver.browser.current_url
      page.driver.browser.close
    end
    page.driver.browser.switch_to.window(original)
  end

  private
    def begin_input_turn(selector, daily: false, prepare: "")
      visit(daily ? search_path : daily_issue_path("2026-09-08"))
      record_turn
      evaluate_async_script(<<~JS)
        const done = arguments[0]
        window.__input = []
        for(const type of ['pointerdown','pointerup','pointercancel','click','keydown','wheel']) document.addEventListener(type,event=>{
          const record={type, trusted:event.isTrusted, target:event.target.className || event.target.tagName, prevented:event.defaultPrevented, pointerType:event.pointerType, phase:document.documentElement.dataset.vt, time:performance.now()}
          window.__input.push(record)
          document.addEventListener(type,()=>{record.after=document.documentElement.dataset.vt;record.focus=document.activeElement.tagName},{once:true})
        },true)
        window.__inputReady = () => {
          #{prepare}
          const target=document.querySelector(#{selector.to_json}), rect=target.getBoundingClientRect()
          let x=target.matches('.t, .item-summary') ? rect.left+5 : rect.left+rect.width/2
          if(target.matches('input')){const canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');const style=getComputedStyle(target);ctx.font=style.fontWeight+' '+style.fontSize+' '+style.fontFamily;x=rect.left+ctx.measureText('abc').width}
          done({x,y:rect.top+rect.height/2,value:target.value,input:target.matches('input'),phase:document.documentElement.dataset.vt,time:performance.now()})
        }
        document.addEventListener('inertia:before',event=>event.detail.visit.url.searchParams.set('q','abcdef'),{once:true});document.querySelector(#{(daily ? '.masthead-brand' : 'a[aria-label=搜索]').to_json}).click()
      JS
    end

    def mouse(type, point, button, buttons)
      page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: type, x: point["x"], y: point["y"], button: button, buttons: buttons, clickCount: 1)
    end

    def touch(type, point = nil)
      points = point ? [ { x: point["x"], y: point["y"], radiusX: 1, radiusY: 1, force: 1, id: 1 } ] : []
      page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type: type, touchPoints: points)
    end

    def input_record
      evaluate_script("JSON.stringify(window.__input)")
    end

    def assert_trusted_input(type)
      events = evaluate_script("window.__input")
      puts "M2_INPUT #{events.to_json}"
      event = events.find { |entry| entry["type"] == type }
      assert event, events.inspect
      assert event["trusted"], events.inspect
      assert_equal "new", event["phase"], "未命中 natural playback 的输入样本无效：#{events.inspect}"
      assert_not event["prevented"], events.inspect
      assert_nil event["after"], events.inspect
    end

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
            window.__inputReady?.()
            incoming?.ready.then(() => { s.incomingReady = read(incoming) }, () => {})
            old?.ready.then(() => { s.dateAtAnimationReady = dateState(); s.animationReadyAt = performance.now(); s.animationReady = read(old) }, () => {})
            requestAnimationFrame(t => { s.dateAtFirstFrame = dateState(); s.firstFrameAt = t; s.firstFrameNative = read(old); s.rects.push(JSON.stringify(surface.getBoundingClientRect())) })
          }), error => { window.__turn.error = String(error) })
          transition.finished.then(() => queueMicrotask(() => { window.__turn.finished = true; window.__turn.restored = document.querySelector('.sheet-body, .login-ground').getAttribute('style') }))
          return transition
        }
      JS
    end
end
