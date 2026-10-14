import { router } from '@inertiajs/react'

// 系统「减少动态效果」：所有动效都看它（设计 skill「动效」）。没有 matchMedia（jsdom）就当没开
export function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true
}

// 开场（M5）：每个标签页会话第一次整页加载时，期头大字、2px 底线、索引条、列表依次出现（motion.css 认 html[data-first-load]）。
// 同一会话里刷新、站内跳转、后退缓存恢复（脚本不重跑）都不播；减少动态效果、sessionStorage 不可用时也不播。
// 动画总长 ≤ 600ms，800ms 后摘掉标记；站内访问一开始也摘，免得新页面接着播。
const OPENED = 'lowpass:opened'
const FIRST_LOAD_MS = 800

export function markFirstLoad(storage: Storage | null = sessionStorageOrNull()): boolean {
  if (!storage || prefersReducedMotion()) return false
  try {
    if (storage.getItem(OPENED)) return false
    storage.setItem(OPENED, '1')
  } catch {
    return false
  }

  const root = document.documentElement
  root.dataset.firstLoad = ''
  const clear = () => {
    delete root.dataset.firstLoad
    off()
  }
  const off = router.on('start', clear)
  window.setTimeout(clear, FIRST_LOAD_MS)
  return true
}

function sessionStorageOrNull(): Storage | null {
  try {
    return window.sessionStorage
  } catch {
    return null
  }
}
