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
  incoming: Animation | null
  restore: (() => void) | null
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
  active = { token, transition, targetPage, direction, surface: null, incoming: null, restore: null }
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
  transition.ready.then(() => startPageTurnPlayback(token), () => completePageTurn(token, 'rejected'))
  transition.finished.then(() => completePageTurn(token, 'finished'), () => completePageTurn(token, 'rejected'))
}

function completePageTurn(token: object, reason: Completion): void {
  if (active?.token !== token) return
  const turn = active
  active = null
  turn.incoming?.cancel()
  turn.restore?.()
  delete document.documentElement.dataset.vtMasthead
  document.documentElement.style.removeProperty('--vt-date-x')
  document.documentElement.style.removeProperty('--vt-date-y')
  delete document.documentElement.dataset.vt
  delete document.documentElement.dataset.turn
  if (reason !== 'finished') turn.transition.skipTransition()
}

function commitPageTurn(page: Page, surface: HTMLElement): void {
  if (!active || active.targetPage !== page || active.surface) return
  active.surface = surface
  active.restore = preparePaper(surface)
  document.documentElement.dataset.vt = 'new'
  document.documentElement.dataset.vtMasthead = String(document.querySelector('.masthead') !== null)
}

// opacity 建立混合组：临时把外层纸面放到正文后面，图片的 multiply 仍以纸色为底。
function preparePaper(surface: HTMLElement): () => void {
  const properties = ['opacity', 'background-color', 'background-image', 'background-size', 'background-repeat', 'background-origin', 'background-position']
  const previous = properties.map((name) => [name, surface.style.getPropertyValue(name), surface.style.getPropertyPriority(name)])
  const paper = surface.closest<HTMLElement>('.paper')
  if (paper && paper !== surface) {
    const style = getComputedStyle(paper)
    const outer = paper.getBoundingClientRect()
    const inner = surface.getBoundingClientRect()
    surface.style.backgroundColor = style.backgroundColor
    surface.style.backgroundImage = style.backgroundImage
    surface.style.backgroundSize = style.backgroundSize
    surface.style.backgroundRepeat = style.backgroundRepeat
    surface.style.backgroundOrigin = 'border-box'
    surface.style.backgroundPosition = `${outer.left - inner.left}px ${outer.top - inner.top}px`
  }
  surface.style.opacity = '0'
  return () => previous.forEach(([name, value, priority]) => {
    if (value) surface.style.setProperty(name, value, priority)
    else surface.style.removeProperty(name)
  })
}

function positionOldDate(date: DOMRect | null): void {
  if (!date) return
  document.documentElement.style.setProperty('--vt-date-x', `${date.left}px`)
  document.documentElement.style.setProperty('--vt-date-y', `${date.top}px`)
}

function startPageTurnPlayback(token: object): void {
  if (active?.token !== token || !active.surface) return
  const turn = active
  positionOldDate(document.querySelector('.issue-head-date')?.getBoundingClientRect() ?? null)
  const roots = document.getAnimations().filter((animation) => (animation.effect as KeyframeEffect | null)?.pseudoElement === '::view-transition-old(root)')
  const native = roots.length === 1 ? roots[0] : null
  if (!native?.timeline) {
    completePageTurn(token, 'rejected')
    return
  }
  const timing = turn.direction
    ? { duration: 360, easing: 'cubic-bezier(0.65, 0, 0.35, 1)', fill: 'both' as const }
    : { duration: 240, easing: 'cubic-bezier(0.2, 0.7, 0.2, 1)', fill: 'both' as const }
  const incoming = new Animation(new KeyframeEffect(turn.surface, [{ opacity: 0 }, { opacity: 1 }], timing), native.timeline)
  turn.incoming = incoming
  if (native.startTime !== null) {
    incoming.startTime = native.startTime
  } else {
    // CSSAnimation 在 VT.ready 时仍 pending；同一 UA animation update 为两者设置起点。
    // 不使用 rAF/定时器自造时钟。原生 ready 之后严格核对，失败就立即显示终态。
    incoming.play()
    Promise.all([native.ready, incoming.ready]).then(() => {
      if (active?.token !== token) return
      if (native.startTime === null || incoming.startTime !== native.startTime || incoming.timeline !== native.timeline) {
        completePageTurn(token, 'rejected')
      }
    }, () => completePageTurn(token, 'rejected'))
  }
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
