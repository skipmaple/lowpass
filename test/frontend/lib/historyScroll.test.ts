import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { captureHistoryScroll, restoreHistoryScroll } from '@/lib/historyScroll'
import { pageTurn } from '@/lib/pageTurn'
import { emitRouterEvent } from '../support/inertia'

const daily = '/daily/2026-09-08?source=github'
let stop: () => void
let frames: FrameRequestCallback[]
let scroll: ReturnType<typeof vi.spyOn>

function navigate(url: string, component = 'Daily/Show') {
  emitRouterEvent('navigate', new CustomEvent('navigate', { detail: { page: { url, component } } }))
}

function visit(event: 'before' | 'start' | 'finish', id: string, url = '/search') {
  emitRouterEvent(event, new CustomEvent(event, { detail: { visit: { id, url: new URL(url, location.origin) } } }))
}

function pop(url = daily, position: unknown = { top: 1255, left: 7 }, page: unknown = new ArrayBuffer(4)) {
  const state = { page, documentScrollPosition: position, scrollRegions: [{ top: 19, left: 3 }], extra: 'keep-current' }
  window.history.replaceState(state, '', url)
  captureHistoryScroll(new PopStateEvent('popstate', { state }))
  return state
}

function overwritePosition(top = 0) {
  window.history.replaceState({ ...history.state, documentScrollPosition: { top, left: 0 } }, '')
}

function flush() {
  // 也执行已取消的旧回调：导航 epoch 必须提供最后一层保护。
  const queued = frames.splice(0)
  queued.forEach(callback => callback(0))
}

beforeEach(() => {
  window.history.replaceState({ page: new ArrayBuffer(4) }, '', '/search')
  frames = []
  vi.spyOn(window, 'requestAnimationFrame').mockImplementation(callback => { frames.push(callback); return frames.length })
  vi.spyOn(window, 'cancelAnimationFrame').mockImplementation(() => {})
  scroll = vi.spyOn(window, 'scrollTo').mockImplementation(() => {})
  vi.stubGlobal('scrollY', 0)
  vi.stubGlobal('scrollX', 0)
  stop = restoreHistoryScroll()
})

afterEach(() => {
  stop()
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('reading history snapshot', () => {
  it('在框架恢复帧之后只纠正一次，并保留当前不透明状态和原生事件快照', () => {
    const original = pop()
    const opaque = new ArrayBuffer(8)
    new Uint8Array(opaque).set([4, 9, 21, 36])
    history.replaceState({ ...history.state, page: opaque, extra: 'newer', documentScrollPosition: { top: 0, left: 0 } }, '')
    requestAnimationFrame(() => window.scrollTo(0, 0))
    navigate(daily)
    navigate(daily)
    expect(scroll).not.toHaveBeenCalled()

    flush()

    expect(scroll.mock.calls).toEqual([[0, 0], [7, 1255]])
    expect(history.state.page).toBeInstanceOf(ArrayBuffer)
    expect(Array.from(new Uint8Array(history.state.page))).toEqual([4, 9, 21, 36, 0, 0, 0, 0])
    expect(history.state.extra).toBe('newer')
    expect(history.state.scrollRegions).toEqual([{ top: 19, left: 3 }])
    expect(history.state.documentScrollPosition).toEqual({ top: 1255, left: 7 })
    expect(original.documentScrollPosition).toEqual({ top: 1255, left: 7 })
    navigate(daily)
    flush()
    expect(scroll).toHaveBeenCalledTimes(2)
  })

  it.each([['/', 'Daily/Show'], ['/weekly/2026-W36', 'Weekly/Show']])('恢复阅读组件 %s，包含日刊首页', (url, component) => {
    pop(url)
    overwritePosition()
    navigate(url, component)
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
  })

  it('已在正确位置时仍修复快照，不再滚动', () => {
    pop()
    overwritePosition()
    vi.stubGlobal('scrollY', 1255)
    vi.stubGlobal('scrollX', 7)
    navigate(daily)
    flush()
    expect(history.state.documentScrollPosition).toEqual({ top: 1255, left: 7 })
    expect(scroll).not.toHaveBeenCalled()
  })

  it.each([null, {}, { top: -1, left: 0 }, { top: Infinity, left: 0 }, { top: 1, left: NaN }, { top: '1255', left: 0 }, { top: 1, left: -1 }])('忽略无效坐标 %j', position => {
    pop(daily, position)
    navigate(daily)
    flush()
    expect(scroll).not.toHaveBeenCalled()
  })

  it('没有页面状态时不写入，也不滚动', () => {
    pop()
    history.replaceState(null, '')
    navigate(daily)
    flush()
    expect(history.state).toBeNull()
    expect(scroll).not.toHaveBeenCalled()
  })

  it('非阅读页面、不同 query 或过期 URL 不纠正', () => {
    pop()
    overwritePosition()
    navigate(daily, 'Search/Show')
    navigate('/daily/2026-09-08?source=hn')
    expect(frames).toHaveLength(0)
    navigate(daily)
    history.replaceState(history.state, '', '/weekly/2026-W36')
    flush()
    expect(scroll).not.toHaveBeenCalled()
  })

  it('普通同路径 hash 前进后退不重用继承的阅读坐标', () => {
    navigate(daily)
    pop(`${daily}#source-hn`)
    navigate(`${daily}#source-hn`)
    flush()
    expect(scroll).not.toHaveBeenCalled()
  })

  it('跨路径 Back 的原生 hash 可比 Inertia 页面 URL 更新，仍恢复这次快照', () => {
    pop(`${daily}#source-github`)
    overwritePosition()
    navigate(daily)
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
    expect(history.state.documentScrollPosition).toEqual({ top: 1255, left: 7 })
  })

  it('排帧后原生 hash 改变便取消旧位置，即使页面 route 仍相同', () => {
    pop(`${daily}#source-github`)
    overwritePosition()
    navigate(daily)
    history.replaceState(history.state, '', `${daily}#source-hn`)
    flush()
    expect(scroll).not.toHaveBeenCalled()
  })

  it('Back 先于 Search 提交时仍捕获；旧 finish 不清掉新访问身份', () => {
    navigate(daily)
    visit('start', 'old', '/weekly/2026-W36')
    visit('start', 'current')
    visit('finish', 'old', '/weekly/2026-W36')
    pop()
    overwritePosition()
    navigate('/search', 'Search/Show')
    visit('finish', 'current')
    navigate(daily)
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
  })

  it('当前访问结束后不把同路径 hash 当成跨路恢复', () => {
    navigate(daily)
    visit('start', 'done')
    visit('finish', 'done')
    pop(`${daily}#source-hn`)
    navigate(`${daily}#source-hn`)
    flush()
    expect(scroll).not.toHaveBeenCalled()
  })

  it('提交路径取 navigate 的页面 URL，而非已经 Back 的 live URL', () => {
    navigate(daily)
    const state = { page: new ArrayBuffer(4), documentScrollPosition: { top: 1255, left: 7 } }
    history.replaceState(state, '', daily)
    navigate('/search', 'Search/Show')
    captureHistoryScroll(new PopStateEvent('popstate', { state }))
    overwritePosition()
    navigate(daily)
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
  })

  it('快速连续 pop 只使用最新 traversal，即使旧帧被执行', () => {
    pop()
    navigate(daily)
    pop('/weekly/2026-W36', { top: 800, left: 0 })
    overwritePosition()
    navigate('/weekly/2026-W36', 'Weekly/Show')
    flush()
    expect(scroll.mock.calls).toEqual([[0, 800]])
    expect(cancelAnimationFrame).toHaveBeenCalled()
  })

  it.each([true, false])('未提交的原生 Search 往返仍恢复最后提交的日刊，Search有记录=%s', recorded => {
    navigate(daily)
    const searchState = recorded ? { page: new ArrayBuffer(4), documentScrollPosition: { top: 0, left: 0 } } : { page: new ArrayBuffer(4) }
    history.replaceState(searchState, '', '/search')
    captureHistoryScroll(new PopStateEvent('popstate', { state: searchState }))
    pop()
    navigate('/search', 'Search/Show')
    overwritePosition()
    requestAnimationFrame(() => window.scrollTo(0, 0))
    navigate(daily)
    flush()
    expect(scroll.mock.calls).toEqual([[0, 0], [7, 1255]])
    expect(history.state.documentScrollPosition).toEqual({ top: 1255, left: 7 })
  })

  it('输入取消旧纠正后，新的原生 Forward 仍获得自己的快照', () => {
    navigate(daily)
    const searchState = { page: new ArrayBuffer(4) }
    history.replaceState(searchState, '', '/search')
    captureHistoryScroll(new PopStateEvent('popstate', { state: searchState }))
    window.dispatchEvent(new Event('wheel'))
    pop()
    overwritePosition()
    navigate('/search', 'Search/Show')
    navigate(daily)
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
  })

  it('较旧的非目标 navigate 不清掉仍未提交的最新原生路径', () => {
    navigate(daily)
    const searchState = { page: new ArrayBuffer(4) }
    history.replaceState(searchState, '', '/search')
    captureHistoryScroll(new PopStateEvent('popstate', { state: searchState }))
    navigate(daily)
    pop()
    overwritePosition()
    navigate('/search', 'Search/Show')
    navigate(daily)
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
  })

  it.each(['commit', 'visit'])('%s 结束原生路径上下文后，同路径锚点仍不纠正', completion => {
    navigate(daily)
    const searchState = { page: new ArrayBuffer(4) }
    history.replaceState(searchState, '', '/search')
    captureHistoryScroll(new PopStateEvent('popstate', { state: searchState }))
    if (completion === 'commit') {
      navigate('/search', 'Search/Show')
      navigate(daily)
    } else {
      visit('before', 'new', daily)
      visit('start', 'new', daily)
      visit('finish', 'new', daily)
    }
    pop(`${daily}#source-hn`)
    navigate(`${daily}#source-hn`)
    flush()
    expect(scroll).not.toHaveBeenCalled()
  })

  it.each(['before', 'start', 'clientVisit'] as const)('%s 新访问让已排队纠正失效', event => {
    pop()
    navigate(daily)
    if (event === 'clientVisit') document.dispatchEvent(new CustomEvent('inertia:clientVisit', { detail: { page: { url: '/search' } } }))
    else visit(event, 'new')
    flush()
    expect(scroll).not.toHaveBeenCalled()
    expect(cancelAnimationFrame).toHaveBeenCalled()
  })

  it.each(['wheel', 'touchstart', 'pointerdown', 'keydown'])('%s 新输入取消纠正，原生 scroll 不取消', type => {
    pop()
    navigate(daily)
    window.dispatchEvent(new Event(type))
    flush()
    expect(scroll).not.toHaveBeenCalled()
  })

  it('框架 scroll 事件不被当作新用户意图', () => {
    pop()
    overwritePosition()
    navigate(daily)
    window.dispatchEvent(new Event('scroll'))
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
  })

  it('卸载取消帧并移除 capture、router 和输入监听', () => {
    pop()
    navigate(daily)
    stop()
    flush()
    pop('/weekly/2026-W36')
    navigate('/weekly/2026-W36', 'Weekly/Show')
    flush()
    expect(scroll).not.toHaveBeenCalled()
    expect(cancelAnimationFrame).toHaveBeenCalled()
  })

  it('VT 缓冲前捕获原生 snapshot，重放不以已损坏的 live state 重新捕获', async () => {
    let swapped!: () => void
    const updateCallbackDone = new Promise<void>(resolve => { swapped = resolve })
    const finished = Promise.resolve()
    const transition = { updateCallbackDone, finished } as unknown as ViewTransition
    ;(pageTurn('forward') as (transition: ViewTransition) => void)(transition)
    const state = { page: new ArrayBuffer(4), documentScrollPosition: { top: 1255, left: 7 } }
    history.replaceState(state, '', daily)
    window.dispatchEvent(new PopStateEvent('popstate', { state }))
    overwritePosition()
    navigate('/search', 'Search/Show')
    swapped()
    await updateCallbackDone
    await Promise.resolve()
    navigate(daily)
    flush()
    expect(scroll).toHaveBeenCalledWith(7, 1255)
    delete document.documentElement.dataset.vt
  })

  it('VT 等待中的新输入取消 snapshot，合成重放不能重新启用它', async () => {
    let swapped!: () => void
    const updateCallbackDone = new Promise<void>(resolve => { swapped = resolve })
    const transition = { updateCallbackDone, finished: Promise.resolve() } as unknown as ViewTransition
    ;(pageTurn('forward') as (transition: ViewTransition) => void)(transition)
    const state = { page: new ArrayBuffer(4), documentScrollPosition: { top: 1255, left: 7 } }
    history.replaceState(state, '', daily)
    window.dispatchEvent(new PopStateEvent('popstate', { state }))
    navigate('/search', 'Search/Show')
    window.dispatchEvent(new Event('wheel'))
    swapped()
    await updateCallbackDone
    await Promise.resolve()
    navigate(daily)
    flush()
    expect(scroll).not.toHaveBeenCalled()
    delete document.documentElement.dataset.vt
  })
})
