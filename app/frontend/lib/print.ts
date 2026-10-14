import { useEffect, useState } from 'react'
import { flushSync } from 'react-dom'

// 打印（PRD D34）：日刊页平时只渲染当前来源；打印前把所有来源都渲染出来，打印完收回。
// beforeprint 之后浏览器立刻排打印页，React 的更新得同步落地（flushSync）。打印预览与无头浏览器模拟
// print 媒体时只有 matchMedia('print') 的 change，没有 beforeprint，两路都听。
export function usePrinting(): boolean {
  const [printing, setPrinting] = useState(false)

  useEffect(() => {
    const start = () => flushSync(() => setPrinting(true))
    const end = () => setPrinting(false)
    const media = window.matchMedia?.('print')
    const change = (event: MediaQueryListEvent) => (event.matches ? start() : end())
    window.addEventListener('beforeprint', start)
    window.addEventListener('afterprint', end)
    media?.addEventListener?.('change', change)
    return () => {
      window.removeEventListener('beforeprint', start)
      window.removeEventListener('afterprint', end)
      media?.removeEventListener?.('change', change)
    }
  }, [])

  return printing
}
