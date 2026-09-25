import { act, renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'

import { useManualRuns } from '@/lib/runs'
import { router } from '../support/inertia'

afterEach(() => router.reload.mockClear())

describe('useManualRuns', () => {
  it('刚结束的任务各弹一次提示，成功与失败句不同；同一个 id 不重复', () => {
    const finished = [
      { id: 'r1', source_name: 'Hackaday', period_key: '2026-09-08', status: 'succeeded' as const, item_count: 10, error_summary: null },
      { id: 'r2', source_name: 'GitHub Trending', period_key: '2026-09-07', status: 'timed_out' as const, item_count: null, error_summary: '连接超时' },
    ]
    const { result, rerender } = renderHook(({ f }) => useManualRuns({ active: [], finished: f, only: ['rows'] }), { initialProps: { f: finished } })

    expect(result.current.toasts.map((t) => t.text)).toEqual(['2026-09-08 · 已更新 Hackaday（10 条）', '2026-09-07 · GitHub Trending · 重抓失败：连接超时。已保留原内容，可稍后再重抓。'])
    expect(result.current.toasts.map((t) => t.kind)).toEqual(['ok', 'fail'])

    rerender({ f: finished })
    expect(result.current.toasts).toHaveLength(2)

    act(() => result.current.dismiss('r1'))
    expect(result.current.toasts.map((t) => t.id)).toEqual(['r2'])
  })

  // 没记下原因时也不把状态的英文枚举（failed / timed_out）放进提示
  it('失败原因缺失时用中文兜底', () => {
    const finished = [
      { id: 'r3', source_name: 'Hacker News', period_key: '2026-09-08', status: 'failed' as const, item_count: null, error_summary: null },
      { id: 'r4', source_name: 'Hackaday', period_key: '2026-09-08', status: 'timed_out' as const, item_count: null, error_summary: null },
    ]
    const { result } = renderHook(() => useManualRuns({ active: [], finished, only: ['rows'] }))

    expect(result.current.toasts.map((t) => t.text)).toEqual([
      '2026-09-08 · Hacker News · 重抓失败：原因未记录。已保留原内容，可稍后再重抓。',
      '2026-09-08 · Hackaday · 重抓失败：连接超时。已保留原内容，可稍后再重抓。',
    ])
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
