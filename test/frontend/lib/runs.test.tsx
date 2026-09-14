import { act, renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'

import { useManualRuns } from '@/lib/runs'
import { router } from '../support/inertia'

afterEach(() => router.reload.mockClear())

describe('useManualRuns', () => {
  it('刚结束的任务各弹一次提示，成功与失败句不同；同一个 id 不重复', () => {
    const finished = [
      { id: 'r1', source_name: 'Hackaday', status: 'succeeded' as const, item_count: 10, error_summary: null },
      { id: 'r2', source_name: 'GitHub Trending', status: 'timed_out' as const, item_count: null, error_summary: '连接超时' },
    ]
    const { result, rerender } = renderHook(({ f }) => useManualRuns({ active: [], finished: f, only: ['rows'] }), { initialProps: { f: finished } })

    expect(result.current.toasts.map((t) => t.text)).toEqual(['已更新 Hackaday（10 条）', '重抓失败：连接超时。已保留原内容。'])
    expect(result.current.toasts.map((t) => t.kind)).toEqual(['ok', 'fail'])

    rerender({ f: finished })
    expect(result.current.toasts).toHaveLength(2)

    act(() => result.current.dismiss('r1'))
    expect(result.current.toasts.map((t) => t.id)).toEqual(['r2'])
  })

  it('running 按期与源判断', () => {
    const active = [{ id: 'r9', source_name: 'Hacker News', period_key: '2026-09-08' }]
    const { result } = renderHook(() => useManualRuns({ active, finished: [], only: ['rows'] }))

    expect(result.current.running('2026-09-08')).toBe(true)
    expect(result.current.running('2026-09-08', 'Hacker News')).toBe(true)
    expect(result.current.running('2026-09-08', 'Hackaday')).toBe(false)
    expect(result.current.running('2026-09-07')).toBe(false)
  })
})
