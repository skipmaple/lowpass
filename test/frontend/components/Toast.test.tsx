import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import Toast, { Toasts } from '@/components/Toast'

describe('Toast', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('ok 4 秒后自动收起，fail 不收', () => {
    const onClose = vi.fn()
    const { rerender } = render(<Toast kind="ok" text="已更新 Hackaday（10 条）" onClose={onClose} />)
    expect(screen.getByRole('status')).toHaveTextContent('已更新 Hackaday（10 条）')

    act(() => vi.advanceTimersByTime(4000))
    expect(onClose).toHaveBeenCalledTimes(1)

    const onCloseFail = vi.fn()
    rerender(<Toast kind="fail" text="重抓失败：连接超时。已保留原内容。" onClose={onCloseFail} />)
    act(() => vi.advanceTimersByTime(10000))
    expect(onCloseFail).not.toHaveBeenCalled()
  })

  it('关闭叉', async () => {
    vi.useRealTimers()
    const onClose = vi.fn()
    render(<Toast kind="fail" text="x" onClose={onClose} />)

    await userEvent.click(screen.getByRole('button', { name: '关闭' }))
    expect(onClose).toHaveBeenCalledTimes(1)
  })

  it('Toasts 按 flash 画 notice 与 alert', () => {
    render(<Toasts flash={{ notice: '已保存 Hackaday', alert: '今日日刊已存在' }} />)

    expect(screen.getAllByRole('status').map((s) => s.textContent)).toEqual(expect.arrayContaining([expect.stringContaining('已保存 Hackaday'), expect.stringContaining('今日日刊已存在')]))
  })
})
