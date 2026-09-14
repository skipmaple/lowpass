import { router } from '@inertiajs/react'
import { useEffect } from 'react'

// 有进行中的手动任务时每 5 秒部分重载（设计 6.3）；停了就不再打扰服务端
export function usePolling(active: boolean, only: string[], intervalMs = 5000): void {
  const key = only.join(',')
  useEffect(() => {
    if (!active) return
    const timer = setInterval(() => router.reload({ only: key.split(',') }), intervalMs)
    return () => clearInterval(timer)
  }, [active, key, intervalMs])
}
