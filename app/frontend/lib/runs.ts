import { useEffect, useRef } from 'react'

import { useToasts } from '@/components/Toast'
import { usePolling } from '@/lib/polling'
import type { FinishedRun, ManualRun } from '@/types/lowpass'

// 手动重抓的进度与反馈（设计 6.3）：有进行中的任务就轮询；刚结束的任务各弹一次（附录 B 的两句），按 id 去重
export function useManualRuns({ active, finished, only }: { active: ManualRun[]; finished: FinishedRun[]; only: string[] }) {
  const { toasts, push, dismiss } = useToasts()
  const seen = useRef<Set<string>>(new Set())
  usePolling(active.length > 0, only)

  useEffect(() => {
    for (const run of finished) {
      if (seen.current.has(run.id)) continue
      seen.current.add(run.id)
      const target = run.period_key ? `${run.period_key} · ` : ''
      if (run.status === 'succeeded') push('ok', `${target}已更新 ${run.source_name}（${run.item_count ?? 0} 条）`, run.id)
      else push('fail', `${target}${run.source_name} · 重抓失败：${run.error_summary ?? run.status}。已保留原内容。`, run.id)
    }
  }, [finished, push])

  function running(periodKey: string, sourceName?: string): boolean {
    return active.some((run) => run.period_key === periodKey && (sourceName === undefined || run.source_name === sourceName))
  }

  return { toasts, dismiss, running }
}
