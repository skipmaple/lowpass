import { router } from '@inertiajs/react'
import type { GlobalEvent } from '@inertiajs/core'

type Snapshot = { href: string; top: number; left: number }
let capturePopstate: ((event: PopStateEvent) => void) | null = null

// pageTurn 在缓冲原生 popstate 之前调用；合成重放不能重新读取已被旧 scroll timer 改写的位置。
export function captureHistoryScroll(event: PopStateEvent): void {
  capturePopstate?.(event)
}

// Inertia 3.7 的滚动记录延迟100ms，恢复却在下一帧读取 live history.state。
// Back 已选中历史 entry 后，离开页遗留的记录可能先写入0。保留原生事件的阅读快照，
// 在框架已排入的恢复帧之后只纠正一次；新访问或读者的新输入优先，不按时间反复拉回。
export function restoreHistoryScroll(): () => void {
  const route = (href: string) => {
    const url = new URL(href, window.location.origin)
    return url.pathname + url.search
  }
  let committedRoute = route(window.location.href)
  let outgoing: { id: string; route: string } | null = null
  // 路径上下文独立于可取消的位置快照；新输入取消旧纠正，不抹掉尚未提交的原生跳转。
  let nativeRoute: string | null = null
  let pending: Snapshot | null = null
  let frame: number | null = null

  const cancel = () => {
    pending = null
    if (frame !== null) window.cancelAnimationFrame(frame)
    frame = null
  }
  const newVisit = () => {
    cancel()
    nativeRoute = null
  }
  const capture = (event: PopStateEvent) => {
    const previousNativeRoute = nativeRoute
    cancel()
    const targetRoute = route(window.location.href)
    // 原生 Back/Forward 不发 XHR start；即使中间页没有位置记录，也保留尚未提交的路径。
    nativeRoute = targetRoute
    // 原生页内锚点 entry 会继承旧 snapshot，不能把它当作跨页阅读恢复。
    // 例外：跨路径访问尚未提交，或原生 Back/Forward 已经往返，最后提交路径仍是日刊。
    const crossedNativeRoute = previousNativeRoute !== null && previousNativeRoute !== targetRoute
    if (targetRoute === committedRoute && (!outgoing || outgoing.route === committedRoute) && !crossedNativeRoute) return
    const position = event.state?.documentScrollPosition
    if (!event.state?.page || !position || !Number.isFinite(position.top) || !Number.isFinite(position.left) || position.top < 0 || position.left < 0) return
    pending = { href: window.location.href, top: position.top, left: position.left }
  }
  capturePopstate = capture

  const offs = [
    router.on('before', newVisit),
    router.on('start', (event) => {
      newVisit()
      outgoing = { id: event.detail.visit.id, route: route(event.detail.visit.url.href) }
    }),
    router.on('finish', (event) => {
      if (outgoing?.id === event.detail.visit.id) outgoing = null
    }),
    router.on('navigate', (event) => {
      const page = event.detail.page
      const href = new URL(page.url, window.location.origin).href
      // VT 缓冲时 live location 已经 Back，提交的组件仍可能是刚离开的 Search。
      committedRoute = route(href)
      if (nativeRoute === committedRoute) nativeRoute = null
      // 原生锚点 entry 的 hash 比加密 page.url 新；组件提交按 route 匹配，执行时仍核对完整原生 href。
      if (!pending || route(pending.href) !== route(href) || frame !== null || !['Daily/Show', 'Weekly/Show'].includes(page.component)) return
      const snapshot = pending
      frame = window.requestAnimationFrame(() => {
        if (pending !== snapshot) return
        frame = null
        pending = null
        const state = window.history.state
        if (window.location.href !== snapshot.href || !state?.page) return
        // page 可能是加密 ArrayBuffer；保留当前全部不透明字段，只写回这一份位置。
        if (state.documentScrollPosition?.top !== snapshot.top || state.documentScrollPosition?.left !== snapshot.left) {
          window.history.replaceState({ ...state, documentScrollPosition: { top: snapshot.top, left: snapshot.left } }, '')
        }
        if (window.scrollY !== snapshot.top || window.scrollX !== snapshot.left) window.scrollTo(snapshot.left, snapshot.top)
      })
    }),
  ]
  const clientVisit = (event: GlobalEvent<'clientVisit'>) => {
    newVisit()
    committedRoute = route(event.detail.page.url)
  }
  document.addEventListener('inertia:clientVisit', clientVisit)
  const inputs = ['wheel', 'touchstart', 'pointerdown', 'keydown'] as const
  inputs.forEach(type => window.addEventListener(type, cancel, { capture: true, passive: true }))

  return () => {
    newVisit()
    if (capturePopstate === capture) capturePopstate = null
    offs.forEach(off => off())
    document.removeEventListener('inertia:clientVisit', clientVisit)
    inputs.forEach(type => window.removeEventListener(type, cancel, true))
  }
}
