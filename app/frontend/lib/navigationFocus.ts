import { router } from '@inertiajs/react'

// 换页后的焦点（PRD 6.4）：Inertia 换页不重载文档，读者刚按下的链接随旧页卸载，焦点掉到 body，读屏也不播报
// 新页。换到另一个路径时把焦点移到新页的一级标题（带锚点就移到锚点，都没有就移到正文），不滚动页面。
// 同一路径内的访问不动焦点：筛选、翻页码、切来源的 router.replace、轮询 reload 都还在读者原来的位置上。
// navigate 在首次加载、每次访问与前进后退都会触发；首次加载的路径就是起点，所以不会抢走整页加载时的焦点。
export function focusMainOnNavigate(): () => void {
  let path = window.location.pathname

  return router.on('navigate', (event) => {
    const url = new URL(event.detail.page.url, window.location.origin)
    if (url.pathname === path) return

    path = url.pathname
    // navigate 在新页的 props 交给 React 时触发，等这一帧画完再找标题
    window.requestAnimationFrame(() => focusMain(url.hash))
  })
}

export function focusMain(hash = ''): void {
  const main = document.getElementById('main-content')
  if (!main) return

  const anchor = hash.length > 1 ? document.getElementById(hash.slice(1)) : null
  const target = anchor ?? main.querySelector<HTMLElement>('h1') ?? main
  if (!target.hasAttribute('tabindex')) target.setAttribute('tabindex', '-1')
  target.focus({ preventScroll: true })
}
