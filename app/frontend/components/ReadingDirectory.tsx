import { useRef, type PropsWithChildren } from 'react'

// 目录高度属于阅读位置：历史返回须在滚动恢复前还原展开状态，普通新访问仍收起。
export default function ReadingDirectory({ id, label, className, children }: PropsWithChildren<{ id: string; label: string; className: string }>) {
  const key = useRef(typeof window === 'undefined' ? '' : `reading-directory:${window.location.pathname}:${id}`)
  let open = false
  if (typeof window !== 'undefined') {
    try {
      open = window.location.hash === `#${id}` || (window.history.state?.documentScrollPosition?.top > 0 && sessionStorage.getItem(key.current) === 'open')
    } catch {
      open = window.location.hash === `#${id}`
    }
  }

  function remember(open: boolean) {
    try {
      sessionStorage.setItem(key.current, open ? 'open' : 'closed')
    } catch {
      // 存储不可用时目录仍可正常使用。
    }
  }

  return (
    <details className={className} open={open} onToggle={(event) => remember(event.currentTarget.open)}>
      <summary>{label}</summary>
      {children}
    </details>
  )
}
