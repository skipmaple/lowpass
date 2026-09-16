import { act, cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Icon from '@/components/Icon'

// X 的两条对角线，三次贝塞尔的控制点仍在直线上。
const CLOSE_PATH = 'M18 6C14 10 10 14 6 18M6 6C10 10 14 14 18 18'

afterEach(() => {
  cleanup()
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

describe('Icon 状态过渡', () => {
  it('切换名称时原地变形，完成后保持目标图形', () => {
    vi.useFakeTimers()
    // 产品要求默认展示动效，不因系统偏好将它替换成静态切换。
    vi.stubGlobal('matchMedia', () => ({ matches: true }))
    const { rerender } = render(<Icon name="user" title="账户" />)
    const icon = screen.getByRole('img', { name: '账户' })
    const path = icon.querySelector('path')!
    const initial = path.getAttribute('d')

    rerender(<Icon name="x" title="关闭" />)

    expect(screen.getByRole('img', { name: '关闭' })).toBe(icon)
    expect(path.getAttribute('d')).toBe(initial)
    act(() => vi.advanceTimersByTime(100))
    expect(path.getAttribute('d')).not.toBe(initial)
    expect(path.getAttribute('d')).not.toBe(CLOSE_PATH)
    act(() => vi.advanceTimersByTime(2000))
    expect(path).toHaveAttribute('d', CLOSE_PATH)
  })
})
