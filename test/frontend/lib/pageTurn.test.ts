import { renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { crossfadeFor, ignoresArrow, pageTurn, useArrowTurns, usePageTurnCommit } from '@/lib/pageTurn'
import type { Page } from '@inertiajs/core'
import { router, emitRouterEvent } from '../support/inertia'

// 翻页（设计说明 2026-10-14 M2、M8）：方向写在 <html data-turn>，过渡进行中有 <html data-vt>，结束就摘掉

function fakeTransition() {
  let finish!: () => void
  let swapped!: () => void
  let ready!: () => void
  let rejectReady!: (error: Error) => void
  let rejectUpdate!: (error: Error) => void
  let rejectFinished!: (error: Error) => void
  const finished = new Promise<void>((resolve, reject) => { finish = resolve; rejectFinished = reject })
  const updateCallbackDone = new Promise<void>((resolve, reject) => { swapped = resolve; rejectUpdate = reject })
  return { transition: { finished, updateCallbackDone, ready: new Promise<void>((resolve, reject) => { ready = resolve; rejectReady = reject }), skipTransition: vi.fn() } as unknown as ViewTransition, finish, swapped, ready, rejectReady, rejectUpdate, rejectFinished }
}

function reduceMotion(matches: boolean) {
  vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches, addEventListener: vi.fn(), removeEventListener: vi.fn() }))
}

afterEach(() => {
  vi.unstubAllGlobals()
  delete document.documentElement.dataset.vt
  delete document.documentElement.dataset.turn
  router.visit.mockClear()
  window.history.replaceState({}, '', '/')
})

describe('pageTurn', () => {
  it('过渡开始时写上方向，结束时摘掉', async () => {
    const { transition, finish } = fakeTransition()
    const callback = pageTurn('back')
    expect(callback).toBeTypeOf('function')

    ;(callback as (t: ViewTransition) => void)(transition)
    expect(document.documentElement.dataset.turn).toBe('back')
    expect(document.documentElement.dataset.vt).toBe('old')

    finish()
    await transition.finished
    await Promise.resolve()
    expect(document.documentElement.dataset.turn).toBeUndefined()
    expect(document.documentElement.dataset.vt).toBeUndefined()
  })

  // 连点两次：第一次的收尾不能摘掉第二次的方向
  it('上一次翻页结束时不摘掉下一次的标记', async () => {
    const first = fakeTransition()
    const second = fakeTransition()
    ;(pageTurn('forward') as (t: ViewTransition) => void)(first.transition)
    ;(pageTurn('forward') as (t: ViewTransition) => void)(second.transition)

    first.finish()
    await first.transition.finished
    await Promise.resolve()
    expect(document.documentElement.dataset.turn).toBe('forward')

    second.finish()
    await second.transition.finished
    await Promise.resolve()
    expect(document.documentElement.dataset.turn).toBeUndefined()
  })

  it('减少动态效果时不做过渡', () => {
    reduceMotion(true)
    expect(pageTurn('back')).toBe(false)
  })
})

describe('crossfadeFor', () => {
  it('换了路径的 GET 访问淡入淡出', () => {
    window.history.replaceState({}, '', '/daily/2026-09-08')
    expect(crossfadeFor('/weekly/2026-W36', {}).viewTransition).toBeTypeOf('function')
  })

  it('同一路径、保留状态、局部刷新、轮询、预取、非 GET 都不做', () => {
    window.history.replaceState({}, '', '/daily/2026-09-08')
    expect(crossfadeFor('/daily/2026-09-08?source=x', {})).toEqual({})
    expect(crossfadeFor('/weekly', { preserveState: true })).toEqual({})
    expect(crossfadeFor('/weekly', { only: ['issue'] })).toEqual({})
    expect(crossfadeFor('/weekly', { async: true })).toEqual({})
    expect(crossfadeFor('/weekly', { prefetch: true })).toEqual({})
    expect(crossfadeFor('/favorites', { method: 'post' })).toEqual({})
  })

  // Inertia 把这里的返回值盖在访问自带的选项上：前一期 / 后一期自己带了方向（一个回调），必须原样放过
  it('访问自己带了过渡回调就不碰', () => {
    expect(crossfadeFor('/weekly', { viewTransition: () => {} })).toEqual({})
    expect(crossfadeFor('/weekly', { viewTransition: true })).toEqual({})
  })

  // 终审：Inertia 的 <Link> 默认把 viewTransition: false 一路传进访问，false 不是「调用方要求不做」
  it('<Link> 默认带来的 viewTransition: false 照样淡入淡出', () => {
    window.history.replaceState({}, '', '/daily/2026-09-08')
    expect(crossfadeFor('/weekly', { viewTransition: false }).viewTransition).toBeTypeOf('function')
  })

  it('减少动态效果时不做', () => {
    reduceMotion(true)
    expect(crossfadeFor('/weekly', {})).toEqual({ viewTransition: false })
  })

  it('访问时开启减少动态效果会禁用已创建的过渡回调', () => {
    reduceMotion(false)
    const renderedTurn = pageTurn('back')
    expect(renderedTurn).toBeTypeOf('function')

    reduceMotion(true)
    expect(crossfadeFor('/daily/2026-09-07', { viewTransition: renderedTurn })).toEqual({ viewTransition: false })
  })
})

describe('键盘翻页', () => {
  const key = (init: KeyboardEventInit & { key: string }, target: EventTarget = document.body) => {
    const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, ...init })
    Object.defineProperty(event, 'target', { value: target })
    return event
  }

  it('来源目录开关与链接获得焦点时，左右键不翻到其他刊期', () => {
    renderHook(() => useArrowTurns('/daily/2026-09-07', '/daily/2026-09-09'))
    const directory = document.createElement('details')
    directory.className = 'source-directory'
    const summary = document.createElement('summary')
    summary.textContent = '来源目录'
    const nav = document.createElement('nav')
    nav.id = 'source-directory'
    const link = document.createElement('a')
    link.href = '#source-github'
    nav.appendChild(link)
    directory.append(summary, nav)
    document.body.appendChild(directory)
    for (const target of [summary, link]) {
      target.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true, cancelable: true }))
      target.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true, cancelable: true }))
    }
    expect(router.visit).not.toHaveBeenCalled()
    directory.remove()
  })

  it('周刊板块目录的开关与锚点获得焦点时，左右键保持在当前刊期', () => {
    renderHook(() => useArrowTurns('/weekly/2026-W35', '/weekly/2026-W37'))
    const directory = document.createElement('details')
    directory.className = 'weekly-directory'
    directory.open = true
    directory.innerHTML = '<summary>板块目录</summary><nav class="anchors" aria-label="板块"><a href="#issue-411-cover">封面图</a></nav>'
    document.body.appendChild(directory)

    try {
      for (const control of directory.querySelectorAll<HTMLElement>('summary, a')) {
        control.focus()
        for (const direction of ['ArrowLeft', 'ArrowRight']) {
          const event = new KeyboardEvent('keydown', { key: direction, bubbles: true, cancelable: true })
          control.dispatchEvent(event)
          expect(event.defaultPrevented).toBe(false)
          expect(control).toHaveFocus()
        }
      }
      expect(router.visit).not.toHaveBeenCalled()
    } finally {
      directory.remove()
    }
  })

  it('输入框、索引条、菜单、对话框里，按着修饰键或按住不放时不翻', () => {
    const input = document.createElement('input')
    const tablist = document.createElement('div')
    tablist.setAttribute('role', 'tablist')
    const tab = document.createElement('button')
    tablist.appendChild(tab)
    document.body.append(input, tablist)

    expect(ignoresArrow(key({ key: 'ArrowLeft' }, input))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft' }, tab))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft', metaKey: true }))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft', repeat: true }))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft' }))).toBe(false)

    input.remove()
    tablist.remove()
  })

  it('← 去前一期，→ 去后一期；没有后一期时 → 不动', () => {
    renderHook(() => useArrowTurns('/daily/2026-09-07', null))

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true, cancelable: true }))
    expect(router.visit).toHaveBeenCalledWith('/daily/2026-09-07', expect.objectContaining({ viewTransition: expect.any(Function) }))

    router.visit.mockClear()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true, cancelable: true }))
    expect(router.visit).not.toHaveBeenCalled()
  })
})

// 终审：过渡的换页回调要等下一帧才跑；这一帧里按了后退，Inertia 先换上后退的那一页，过渡回调随后又把要去的那一页换回来。
// 后退赶上过渡还没换完页时，先扣下这次后退，等过渡换完再原样交给 Inertia
describe('过渡换页未完成时的后退', () => {
  it('扣下 popstate，等过渡换完页再把同一个 state 交出去', async () => {
    const seen: unknown[] = []
    const inertia = (event: PopStateEvent) => seen.push(event.state)
    window.addEventListener('popstate', inertia)
    const { transition, swapped, finish } = fakeTransition()
    ;(pageTurn('forward') as (t: ViewTransition) => void)(transition)

    window.dispatchEvent(new PopStateEvent('popstate', { state: { page: 'daily' } }))
    expect(seen).toEqual([])

    swapped()
    await transition.updateCallbackDone
    await Promise.resolve()
    expect(seen).toEqual([{ page: 'daily' }])

    finish()
    window.removeEventListener('popstate', inertia)
  })

  it('没有过渡在换页时，后退照常直接交给 Inertia', () => {
    const seen: unknown[] = []
    const inertia = (event: PopStateEvent) => seen.push(event.state)
    window.addEventListener('popstate', inertia)

    window.dispatchEvent(new PopStateEvent('popstate', { state: { page: 'search' } }))
    expect(seen).toEqual([{ page: 'search' }])
    window.removeEventListener('popstate', inertia)
  })
})

const targetPage = () => ({ url: '/search', component: 'Search/Index', props: {}, version: null } as Page)
function beforeUpdate(page: Page) {
  emitRouterEvent('beforeUpdate', new CustomEvent('beforeUpdate', { detail: { page } }))
}

describe('精确 React 提交', () => {
  it('beforeUpdate 只记录身份；同 URL 克隆不能提交，同一个对象首次 layout effect 同步提交', async () => {
    const target = targetPage()
    beforeUpdate(target)
    expect(document.documentElement.dataset.vt).toBeUndefined()
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    const surface = document.createElement('div')
    const ref = { current: surface }
    const hook = renderHook(({ page }) => usePageTurnCommit(page, ref), { initialProps: { page: { ...target } } })
    expect(document.documentElement.dataset.vt).toBe('old')
    hook.rerender({ page: target })
    expect(document.documentElement.dataset.vt).toBe('new')
    hook.rerender({ page: target })
    hook.unmount()
    expect(document.documentElement.dataset.vt).toBe('new')
    t.finish()
    await t.transition.finished
  })

  it('update 完成还没有匹配 Page 时跳过原生过渡', async () => {
    beforeUpdate(targetPage())
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    t.swapped()
    await t.transition.updateCallbackDone
    expect(t.transition.skipTransition).toHaveBeenCalledTimes(1)
    expect(document.documentElement.dataset.vt).toBeUndefined()
    t.finish()
  })
})


describe('native 播放时钟与纸面', () => {
  it.each([['back', 360, 'cubic-bezier(0.65, 0, 0.35, 1)'], [null, 240, 'cubic-bezier(0.2, 0.7, 0.2, 1)']] as const)('方向 %s 使用 OLD root 同一时间轴与起点', async (direction, duration, easing) => {
    const timeline = { currentTime: 160 }
    const native = { effect: { pseudoElement: '::view-transition-old(root)' }, timeline, startTime: 100 }
    vi.stubGlobal('KeyframeEffect', class { constructor(public target: Element, public frames: unknown, public timing: unknown) {} })
    const animations: { timeline: unknown; startTime: unknown; effect: { frames: unknown; timing: unknown }; cancel: () => void }[] = []
    vi.stubGlobal('Animation', class {
      startTime: unknown = null
      cancel = vi.fn()
      constructor(public effect: { frames: unknown; timing: unknown }, public timeline: unknown) { animations.push(this) }
    })
    Object.defineProperty(document, 'getAnimations', { configurable: true, value: () => [native] })
    const target = targetPage()
    beforeUpdate(target)
    const t = fakeTransition()
    const callback = direction ? pageTurn(direction) : crossfadeFor('/search', {}).viewTransition
    ;(callback as (t: ViewTransition) => void)(t.transition)
    const paper = document.createElement('div')
    paper.className = 'paper'
    paper.style.backgroundColor = 'rgb(232, 227, 218)'
    const surface = document.createElement('div')
    surface.style.backgroundPosition = '7px 9px'
    paper.append(surface)
    document.body.append(paper)
    vi.spyOn(paper, 'getBoundingClientRect').mockReturnValue({ left: 5, top: 9 } as DOMRect)
    vi.spyOn(surface, 'getBoundingClientRect').mockReturnValue({ left: 29, top: 90 } as DOMRect)
    renderHook(() => usePageTurnCommit(target, { current: surface }))
    expect(surface.style.opacity).toBe('0')
    expect(surface.style.backgroundPosition).toBe('-24px -81px')
    t.ready()
    await t.transition.ready
    expect(animations).toHaveLength(1)
    expect(animations[0].timeline).toBe(timeline)
    expect(animations[0].startTime).toBe(native.startTime)
    expect(animations[0].effect.frames).toEqual([{ opacity: 0 }, { opacity: 1 }])
    expect(animations[0].effect.timing).toEqual({ duration, easing, fill: 'both' })
    t.finish()
    await t.transition.finished
    expect(surface.style.opacity).toBe('')
    expect(surface.style.backgroundPosition).toBe('7px 9px')
    expect(animations[0].cancel).toHaveBeenCalledOnce()
    paper.remove()
    vi.restoreAllMocks()
  })
})

describe('OLD 纸面给真实新报头让出静止窗口', () => {
  it.each([104.375, -5, 10000, null])('ready 使用实际报头 bottom=%s，保留小数并限制视口，终态清理', async (bottom) => {
    vi.stubGlobal('KeyframeEffect', class {})
    vi.stubGlobal('Animation', class { startTime = null; cancel = vi.fn() })
    Object.defineProperty(document, 'getAnimations', { configurable: true, value: () => [{ effect: { pseudoElement: '::view-transition-old(root)' }, timeline: {}, startTime: 10 }] })
    const header = document.createElement('header')
    header.className = 'masthead'
    if (bottom !== null) document.body.append(header)
    vi.spyOn(header, 'getBoundingClientRect').mockReturnValue({ bottom } as DOMRect)
    const target = targetPage()
    beforeUpdate(target)
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    renderHook(() => usePageTurnCommit(target, { current: document.createElement('div') }))
    const root = document.documentElement
    expect(root.style.getPropertyValue('--vt-masthead-bottom')).toBe('')
    t.ready()
    await t.transition.ready
    expect(root.style.getPropertyValue('--vt-masthead-bottom')).toBe(bottom === null ? '' : `${Math.min(innerHeight, Math.max(0, bottom))}px`)
    t.finish()
    await t.transition.finished
    expect(root.style.getPropertyValue('--vt-masthead-bottom')).toBe('')
    header.remove()
    vi.restoreAllMocks()
  })

  it('旧 finished 晚到不清新 token 的裁剪坐标', async () => {
    vi.stubGlobal('KeyframeEffect', class {})
    vi.stubGlobal('Animation', class { startTime = null; cancel = vi.fn() })
    Object.defineProperty(document, 'getAnimations', { configurable: true, value: () => [{ effect: { pseudoElement: '::view-transition-old(root)' }, timeline: {}, startTime: 10 }] })
    const header = document.createElement('header')
    header.className = 'masthead'
    document.body.append(header)
    const rect = vi.spyOn(header, 'getBoundingClientRect')
    const turns = [fakeTransition(), fakeTransition()]
    for (const [i, t] of turns.entries()) {
      rect.mockReturnValue({ bottom: i ? 80.25 : 104.375 } as DOMRect)
      const target = targetPage()
      beforeUpdate(target)
      ;(pageTurn('forward') as (t: ViewTransition) => void)(t.transition)
      renderHook(() => usePageTurnCommit(target, { current: document.createElement('div') }))
      t.ready()
      await t.transition.ready
    }
    turns[0].finish()
    await turns[0].transition.finished
    expect(document.documentElement.style.getPropertyValue('--vt-masthead-bottom')).toBe('80.25px')
    turns[1].finish()
    await turns[1].transition.finished
    expect(document.documentElement.style.getPropertyValue('--vt-masthead-bottom')).toBe('')
    header.remove()
    vi.restoreAllMocks()
  })
})

describe('pending native 时钟核验', () => {
  it.each([100, 101])('真实 startTime=%s 必须严格相同，不接受近似值', async (incomingStart) => {
    let resolveNative!: () => void
    let resolveIncoming!: () => void
    const timeline = {}
    const native = { effect: { pseudoElement: '::view-transition-old(root)' }, timeline, startTime: null as number | null, ready: new Promise<void>(resolve => { resolveNative = resolve }) }
    vi.stubGlobal('KeyframeEffect', class {})
    const animations: { startTime: number | null; play: ReturnType<typeof vi.fn>; cancel: ReturnType<typeof vi.fn> }[] = []
    vi.stubGlobal('Animation', class {
      startTime: number | null = null
      play = vi.fn()
      cancel = vi.fn()
      ready = new Promise<void>(resolve => { resolveIncoming = resolve })
      constructor(_effect: unknown, public timeline: unknown) { animations.push(this) }
    })
    Object.defineProperty(document, 'getAnimations', { configurable: true, value: () => [native] })
    const target = targetPage()
    beforeUpdate(target)
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    const surface = document.createElement('div')
    const ref = { current: surface }
    const hook = renderHook(() => usePageTurnCommit(target, ref))
    t.ready()
    await t.transition.ready
    expect(animations[0].play).toHaveBeenCalledOnce()
    surface.style.opacity = '0.4'
    hook.rerender()
    expect(surface.style.opacity).toBe('0.4')
    native.startTime = 100
    animations[0].startTime = incomingStart
    resolveNative()
    resolveIncoming()
    await Promise.resolve()
    await Promise.resolve()
    expect(t.transition.skipTransition).toHaveBeenCalledTimes(incomingStart === 100 ? 0 : 1)
    expect(surface.style.opacity).toBe(incomingStart === 100 ? '0.4' : '')
    t.finish()
    await t.transition.finished
  })
})

describe('可信输入收尾', () => {
  it('只处理 ready 之后可信 pointerdown/keydown/wheel；不接管任何默认动作', async () => {
    const listeners = vi.spyOn(document, 'addEventListener')
    vi.stubGlobal('KeyframeEffect', class {})
    vi.stubGlobal('Animation', class { startTime = null; cancel = vi.fn() })
    Object.defineProperty(document, 'getAnimations', { configurable: true, value: () => [{ effect: { pseudoElement: '::view-transition-old(root)' }, timeline: {}, startTime: 10 }] })
    const target = targetPage()
    beforeUpdate(target)
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    const surface = document.createElement('div')
    renderHook(() => usePageTurnCommit(target, { current: surface }))
    document.dispatchEvent(new Event('pointerdown', { bubbles: true }))
    expect(t.transition.skipTransition).not.toHaveBeenCalled()
    t.ready()
    await t.transition.ready
    for (const type of ['pointerdown', 'keydown', 'wheel', 'focus']) document.dispatchEvent(new Event(type, { bubbles: true }))
    expect(t.transition.skipTransition).not.toHaveBeenCalled()
    const registered = listeners.mock.calls.filter(([type, , options]) => ['pointerdown', 'keydown', 'wheel'].includes(type) && typeof options === 'object' && options?.capture)
    expect(registered.map(([type]) => type)).toEqual(['pointerdown', 'keydown', 'wheel'])
    const event = { isTrusted: true, preventDefault: vi.fn(), stopPropagation: vi.fn(), target: { click: vi.fn(), focus: vi.fn(), setPointerCapture: vi.fn() } }
    ;(registered[0][1] as EventListener)(event as unknown as Event)
    expect(t.transition.skipTransition).toHaveBeenCalledOnce()
    expect(document.documentElement.dataset.vt).toBeUndefined()
    expect(surface.style.opacity).toBe('')
    expect(event.preventDefault).not.toHaveBeenCalled()
    expect(event.stopPropagation).not.toHaveBeenCalled()
    expect(event.target.click).not.toHaveBeenCalled()
    expect(event.target.focus).not.toHaveBeenCalled()
    expect(event.target.setPointerCapture).not.toHaveBeenCalled()
    t.finish()
    vi.restoreAllMocks()
  })
})


describe('重叠、取消与拒绝', () => {
  it('两个 beforeUpdate 在异步解析间交错时拒绝歧义身份，不把最后一个 Page 错配给旧 track', async () => {
    emitRouterEvent('before')
    beforeUpdate(targetPage())
    const wrong = targetPage()
    beforeUpdate(wrong)
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    const surface = document.createElement('div')
    renderHook(() => usePageTurnCommit(wrong, { current: surface }))
    expect(document.documentElement.dataset.vt).toBe('old')
    expect(surface.style.opacity).not.toBe('0')
    t.swapped()
    await t.transition.updateCallbackDone
    expect(t.transition.skipTransition).toHaveBeenCalledOnce()
    t.finish()
  })

  it.each(['before', 'finish', 'clientVisit'] as const)('%s 使未消费 Page 失效，不能遗留到下次 track', async (event) => {
    beforeUpdate(targetPage())
    const target = targetPage()
    beforeUpdate(target)
    emitRouterEvent(event)
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    const surface = document.createElement('div')
    renderHook(() => usePageTurnCommit(target, { current: surface }))
    expect(surface.style.opacity).not.toBe('0')
    t.swapped()
    await t.transition.updateCallbackDone
    expect(t.transition.skipTransition).toHaveBeenCalledOnce()
    t.finish()
  })

  it('旧 ready/finished/reject 晚到只清旧 surface，不能摘掉新 token 或背景', async () => {
    const a = targetPage(), b = targetPage()
    beforeUpdate(a)
    const first = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(first.transition)
    const oldSurface = document.createElement('div')
    renderHook(() => usePageTurnCommit(a, { current: oldSurface }))
    expect(oldSurface.style.opacity).toBe('0')
    beforeUpdate(b)
    const second = fakeTransition()
    ;(pageTurn('forward') as (t: ViewTransition) => void)(second.transition)
    const newSurface = document.createElement('div')
    renderHook(() => usePageTurnCommit(b, { current: newSurface }))
    expect(oldSurface.style.opacity).toBe('')
    first.ready()
    first.rejectUpdate(new Error('old update cancelled'))
    first.rejectFinished(new Error('old finish cancelled'))
    await Promise.resolve()
    await Promise.resolve()
    expect(document.documentElement.dataset.turn).toBe('forward')
    expect(newSurface.style.opacity).toBe('0')
    second.finish()
    await second.transition.finished
    expect(newSurface.style.opacity).toBe('')
  })

  it.each(['rejectReady', 'rejectUpdate', 'rejectFinished'] as const)('%s 收尾无残余标记/opacity0', async (reject) => {
    const target = targetPage()
    beforeUpdate(target)
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    const surface = document.createElement('div')
    renderHook(() => usePageTurnCommit(target, { current: surface }))
    t[reject](new Error('cancelled'))
    await Promise.resolve()
    await Promise.resolve()
    expect(surface.style.opacity).toBe('')
    expect(document.documentElement.dataset.vt).toBeUndefined()
    t.finish()
    t.swapped()
  })

  it('原生 Animation 构造拒绝也恢复终态，并吸收 ready reaction 的异常', async () => {
    vi.stubGlobal('Animation', class {})
    vi.stubGlobal('KeyframeEffect', class { constructor() { throw new Error('unsupported effect') } })
    Object.defineProperty(document, 'getAnimations', { configurable: true, value: () => [{ effect: { pseudoElement: '::view-transition-old(root)' }, timeline: {}, startTime: 10 }] })
    const target = targetPage()
    beforeUpdate(target)
    const t = fakeTransition()
    ;(pageTurn('back') as (t: ViewTransition) => void)(t.transition)
    const surface = document.createElement('div')
    renderHook(() => usePageTurnCommit(target, { current: surface }))
    t.ready()
    await t.transition.ready
    await Promise.resolve()
    expect(surface.style.opacity).toBe('')
    expect(t.transition.skipTransition).toHaveBeenCalledOnce()
    t.finish()
  })
})
