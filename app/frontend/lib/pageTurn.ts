import { router } from '@inertiajs/react'
import type { VisitOptions } from '@inertiajs/core'
import { useEffect } from 'react'

import { prefersReducedMotion } from '@/lib/motion'

// 翻页（设计 skill「动效」M2、M8，PRD D34）。前一期 / 后一期是有方向的翻页：报头不动，正文从左或从右滑入；
// 其余换页面的整页跳转只让正文淡入淡出。用浏览器原生的 View Transitions，经 Inertia 的 viewTransition 选项接进来。
//
// 过渡进行中给 <html> 打上 data-vt（motion.css 只在这时给报头、正文、期头大字起 view-transition-name）：
// 常驻的 view-transition-name 会让元素自成层叠上下文，报头的头像菜单会被正文里定位的元素盖住，周刊配图的
// 正片叠底也会失效。Inertia 调 startViewTransition 后立刻同步调这里的回调，旧画面在下一帧才截，标记来得及。
// 方向写在 data-turn。不支持的浏览器、减少动态效果时直接切换。

export type TurnDirection = 'back' | 'forward'

// 最近一次过渡的记号：连点两次时，前一次的收尾不能摘掉后一次的标记
let active: object | null = null

function track(transition: ViewTransition, direction: TurnDirection | null) {
  const token = {}
  active = token
  const root = document.documentElement
  root.dataset.vt = ''
  if (direction) root.dataset.turn = direction
  else delete root.dataset.turn
  transition.finished.finally(() => {
    if (active !== token) return
    active = null
    delete root.dataset.vt
    delete root.dataset.turn
  })
}

export function pageTurn(direction: TurnDirection): false | ((transition: ViewTransition) => void) {
  if (prefersReducedMotion()) return false
  return (transition) => track(transition, direction)
}

// 其余整页跳转（换了路径的 GET 访问）：正文淡入淡出。保留状态的访问、局部刷新、轮询、预取、表单提交不做，
// 已经带了 viewTransition 的访问（前一期 / 后一期）原样放过。Inertia 把这里的返回值盖在访问自带的选项上，
// 所以不该管的时候必须返回空对象，不能写 viewTransition: false。
export function crossfadeFor(href: string, options: VisitOptions): { viewTransition?: VisitOptions['viewTransition'] } {
  if (options.viewTransition !== undefined) return {}
  if ((options.method ?? 'get') !== 'get') return {}
  if (options.preserveState || options.async || options.prefetch || (options.only?.length ?? 0) > 0) return {}
  if (prefersReducedMotion()) return {}
  if (new URL(href, window.location.href).pathname === window.location.pathname) return {}
  return { viewTransition: (transition: ViewTransition) => track(transition, null) }
}

// 键盘翻页（M8）：焦点在输入框、索引条、菜单、对话框里，按着修饰键，或按住不放（repeat）时不翻
const IGNORE_WITHIN = '[role="tablist"], [role="menu"], [role="dialog"], [role="listbox"], [role="slider"], [contenteditable=""], [contenteditable="true"]'

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
