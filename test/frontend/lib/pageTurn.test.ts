import { renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { crossfadeFor, ignoresArrow, pageTurn, useArrowTurns } from '@/lib/pageTurn'
import { router } from '../support/inertia'

// 翻页（设计说明 2026-10-14 M2、M8）：方向写在 <html data-turn>，过渡进行中有 <html data-vt>，结束就摘掉

function fakeTransition() {
  let finish!: () => void
  let swapped!: () => void
  const finished = new Promise<void>((resolve) => { finish = resolve })
  const updateCallbackDone = new Promise<void>((resolve) => { swapped = resolve })
  return { transition: { finished, updateCallbackDone } as unknown as ViewTransition, finish, swapped }
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
    expect(document.documentElement.dataset.vt).toBe('')

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
    expect(crossfadeFor('/weekly', {})).toEqual({})
  })
})

describe('键盘翻页', () => {
  const key = (init: KeyboardEventInit & { key: string }, target: EventTarget = document.body) => {
    const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, ...init })
    Object.defineProperty(event, 'target', { value: target })
    return event
  }

  it('来源目录链接获得焦点时，左右键不翻到其他刊期', () => {
    renderHook(() => useArrowTurns('/daily/2026-09-07', '/daily/2026-09-09'))
    const directory = document.createElement('nav')
    directory.id = 'source-directory'
    const link = document.createElement('a')
    link.href = '#source-github'
    directory.appendChild(link)
    document.body.appendChild(directory)
    link.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true, cancelable: true }))
    link.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true, cancelable: true }))
    expect(router.visit).not.toHaveBeenCalled()
    directory.remove()
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
