import { act, renderHook } from '@testing-library/react'
import { afterEach, expect, it, vi } from 'vitest'
import { useAdminOperations } from '@/lib/operations'
import { router } from '../support/inertia'

afterEach(() => { router.post.mockClear(); router.reload.mockClear() })
it('keeps two targets independent, rejects duplicate clicks, and retains a late transport failure', () => {
  const { result } = renderHook(() => useAdminOperations())
  act(() => {
    result.current.post('a', '2026-09-08', '/a')
    result.current.post('b', '2026-09-07', '/b')
    result.current.post('a', '2026-09-08', '/a')
  })
  expect(router.post).toHaveBeenCalledTimes(2)
  expect(result.current.busy('a')).toBe(true)
  expect(result.current.busy('b')).toBe(true)
  const first = router.post.mock.calls[0][2]
  const second = router.post.mock.calls[1][2]
  expect(first.async).toBe(true)
  expect(first.only).toEqual(['flash', 'errors'])
  act(() => second.onFinish())
  expect(result.current.busy('a')).toBe(true)
  expect(router.reload).not.toHaveBeenCalled()
  expect(result.current.busy('b')).toBe(false)
  expect(result.current.errors).toEqual([])
  act(() => { first.onNetworkError(new Error('offline')); first.onFinish() })
  expect(router.reload).toHaveBeenCalledTimes(1)
  expect(result.current.errors).toEqual([{ key: 'a', text: '2026-09-08 · 网络连接失败，请重试。' }])
  const cancelRefresh = vi.fn()
  act(() => router.reload.mock.calls[0][0].onCancelToken({ cancel: cancelRefresh }))
  act(() => result.current.post('a', '2026-09-08', '/a'))
  expect(cancelRefresh).toHaveBeenCalledTimes(1)
  expect(result.current.errors).toEqual([])
  expect(result.current.busy('a')).toBe(true)
})
