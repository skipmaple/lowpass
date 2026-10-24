import { router } from '@inertiajs/react'
import type { Page, VisitOptions } from '@inertiajs/core'
import { useEffect, useLayoutEffect, type RefObject } from 'react'

import { captureHistoryScroll } from '@/lib/historyScroll'
import { prefersReducedMotion } from '@/lib/motion'

// OLD 保留原生视口快照，NEW 在匹配的 React 提交时退出所有命名捕获。
export type TurnDirection = 'back' | 'forward'
type Completion = 'finished' | 'input' | 'replaced' | 'unmatched' | 'rejected'
type PageTurn = {
  token: object
  transition: ViewTransition
  targetPage: Page | null
  direction: TurnDirection | null
  surface: HTMLElement | null
}
let active: PageTurn | null = null
let pendingPage: Page | null = null

// 过渡的换页回调要等下一帧才跑，Inertia 处理后退却是一串 promise：读者在这一帧里按了后退，Inertia 先把后退的那一页
// 换上，过渡回调随后又把刚才要去的那一页换回来——地址是后退后的，页面却停在前一页。后退赶上过渡还没换完页时，
// 先扣下这次 popstate（捕获阶段、在 Inertia 之前），等过渡换完页，再把同一个 state 原样交给 Inertia。
let swapping: Promise<unknown> | null = null
let replaying = false

if (typeof window !== 'undefined') {
  router.on('beforeUpdate', (event) => { pendingPage = event.detail.page })
  router.on('before', () => { pendingPage = null })
  router.on('finish', () => { pendingPage = null })
  router.on('clientVisit', () => { pendingPage = null })
  window.addEventListener('popstate', (event) => {
    if (!replaying) captureHistoryScroll(event)
    if (replaying || !swapping) return
    event.stopImmediatePropagation()
    const state = event.state
    const replay = () => {
      replaying = true
      window.dispatchEvent(new PopStateEvent('popstate', { state }))
      replaying = false
    }
    swapping.then(replay, replay)
  }, true)
}

function track(transition: ViewTransition, direction: TurnDirection | null) {
  const targetPage = pendingPage
  pendingPage = null
  if (active) completePageTurn(active.token, 'replaced')
  const token = {}
  active = { token, transition, targetPage, direction, surface: null }
  const root = document.documentElement
  root.dataset.vt = 'old'
  if (direction) root.dataset.turn = direction
  else delete root.dataset.turn

  const done = transition.updateCallbackDone
  swapping = done
  done.then(() => {
    if (swapping === done) swapping = null
    if (active?.token === token && !active.surface) completePageTurn(token, 'unmatched')
  }, () => {
    if (swapping === done) swapping = null
    completePageTurn(token, 'rejected')
  })
  transition.ready.catch(() => completePageTurn(token, 'rejected'))
  transition.finished.then(() => completePageTurn(token, 'finished'), () => completePageTurn(token, 'rejected'))
}

function completePageTurn(token: object, reason: Completion): void {
  if (active?.token !== token) return
  const turn = active
  active = null
  delete document.documentElement.dataset.vt
  delete document.documentElement.dataset.turn
  if (reason !== 'finished') turn.transition.skipTransition()
}

function commitPageTurn(page: Page, surface: HTMLElement): void {
  if (!active || active.targetPage !== page || active.surface) return
  active.surface = surface
  document.documentElement.dataset.vt = 'new'
}

export function usePageTurnCommit(page: Page, surface: RefObject<HTMLElement | null>): void {
  useLayoutEffect(() => {
    if (surface.current) commitPageTurn(page, surface.current)
  }, [page, surface])
}

export function pageTurn(direction: TurnDirection): false | ((transition: ViewTransition) => void) {
  if (prefersReducedMotion()) return false
  return (transition) => track(transition, direction)
}

// 其余整页跳转（换了路径的 GET 访问）：正文淡入淡出。保留状态的访问、局部刷新、轮询、预取、表单提交不做，
// 自己带了过渡回调的访问（前一期 / 后一期）原样放过。Inertia 把这里的返回值盖在访问自带的选项上，
// 所以不该管的时候必须返回空对象，不能写 viewTransition: false。
// <Link> 默认把 viewTransition: false 一路传进访问，所以 false 不算「调用方要求不做」：只认回调与 true。
export function crossfadeFor(href: string, options: VisitOptions): { viewTransition?: VisitOptions['viewTransition'] } {
  if (typeof options.viewTransition === 'function' || options.viewTransition === true) return {}
  if ((options.method ?? 'get') !== 'get') return {}
  if (options.preserveState || options.async || options.prefetch || (options.only?.length ?? 0) > 0) return {}
  if (prefersReducedMotion()) return {}
  if (new URL(href, window.location.href).pathname === window.location.pathname) return {}
  return { viewTransition: (transition: ViewTransition) => track(transition, null) }
}

// 键盘翻页（M8）：焦点在输入框、索引条、菜单、对话框里，按着修饰键，或按住不放（repeat）时不翻
const IGNORE_WITHIN = '#source-directory, .weekly-directory, .anchors, [role="tablist"], [role="menu"], [role="dialog"], [role="listbox"], [role="slider"], [contenteditable=""], [contenteditable="true"]'

export function ignoresArrow(event: KeyboardEvent): boolean {
  if (event.defaultPrevented || event.repeat || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return true
  const target = event.target instanceof Element ? event.target : null
  if (target && (target.matches('input, textarea, select') || target.closest(IGNORE_WITHIN))) return true
  return document.querySelector('.dialog-shade') !== null
}

export function useArrowTurns(prevHref: string | null, nextHref: string | null): void {
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return
      if (ignoresArrow(event)) return
      const back = event.key === 'ArrowLeft'
      const href = back ? prevHref : nextHref
      if (!href) return
      event.preventDefault()
      router.visit(href, { viewTransition: pageTurn(back ? 'back' : 'forward') })
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [prevHref, nextHref])
}
