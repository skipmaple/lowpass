import { renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { usePolling } from '@/lib/polling'
import { router } from '../support/inertia'

describe('usePolling', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => {
    vi.useRealTimers()
    router.reload.mockClear()
  })

  it('active 时每 5 秒 reload 指定的 props，停下后不再调', () => {
    const { rerender } = renderHook(({ active }) => usePolling(active, ['rows', 'active_runs']), { initialProps: { active: true } })

    vi.advanceTimersByTime(5000)
    expect(router.reload).toHaveBeenCalledWith({ only: ['rows', 'active_runs'] })
    vi.advanceTimersByTime(5000)
    expect(router.reload).toHaveBeenCalledTimes(2)

    rerender({ active: false })
    vi.advanceTimersByTime(10000)
    expect(router.reload).toHaveBeenCalledTimes(2)
  })
})
