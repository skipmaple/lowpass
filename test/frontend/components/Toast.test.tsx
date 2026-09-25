import { act, fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import Toast, { ToastRegion, Toasts } from '@/components/Toast'

describe('Toast', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('ok 5 秒后自动收起，fail 不收', () => {
    const onClose = vi.fn()
    const { rerender } = render(<Toast kind="ok" text="已更新 Hackaday（10 条）" onClose={onClose} />)
    expect(screen.getByText('已更新 Hackaday（10 条）')).toBeInTheDocument()

    act(() => vi.advanceTimersByTime(4999))
    expect(onClose).not.toHaveBeenCalled()
    act(() => vi.advanceTimersByTime(1))
    expect(onClose).toHaveBeenCalledTimes(1)

    const onCloseFail = vi.fn()
    rerender(<Toast kind="fail" text="重抓失败：连接超时。已保留原内容。" onClose={onCloseFail} />)
    act(() => vi.advanceTimersByTime(10000))
    expect(onCloseFail).not.toHaveBeenCalled()
  })

  // 读者正看着（鼠标停留或焦点在提示上）就不收；离开后重新计满 5 秒
  it('鼠标停留与聚焦时暂停', () => {
    const onClose = vi.fn()
    render(<Toast kind="ok" text="已保存" onClose={onClose} />)
    const toast = screen.getByText('已保存').closest('.toast')!

    act(() => vi.advanceTimersByTime(3000))
    fireEvent.mouseEnter(toast)
    act(() => vi.advanceTimersByTime(10000))
    expect(onClose).not.toHaveBeenCalled()

    fireEvent.mouseLeave(toast)
    act(() => vi.advanceTimersByTime(4999))
    expect(onClose).not.toHaveBeenCalled()

    fireEvent.focus(screen.getByRole('button', { name: '关闭' }))
    act(() => vi.advanceTimersByTime(10000))
    expect(onClose).not.toHaveBeenCalled()
  })

  // 父组件重渲染（比如轮询）时常会传一个新的内联 onClose；5 秒计时器不该被这个重置——
  // 不然一条提示在轮询期间可能永远等不到自动收起。
  it('rerender 时内联 onClose 变了不重置计时器', () => {
    const onClose1 = vi.fn()
    const { rerender } = render(<Toast kind="ok" text="已更新 Hackaday（10 条）" onClose={onClose1} />)

    act(() => vi.advanceTimersByTime(4000))
    const onClose2 = vi.fn()
    rerender(<Toast kind="ok" text="已更新 Hackaday（10 条）" onClose={onClose2} />)

    act(() => vi.advanceTimersByTime(1000))
    expect(onClose1).not.toHaveBeenCalled()
    expect(onClose2).toHaveBeenCalledTimes(1)
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

    const region = screen.getByRole('status')
    expect(region).toHaveTextContent('已保存 Hackaday')
    expect(region).toHaveTextContent('今日日刊已存在')
  })

  // live region 要先在页面上：提示插进一个已经存在的 role="status"，读屏才会播报；没有提示时区域也在
  it('提示画进常驻的 live region', () => {
    const { rerender } = render(<Toasts />)
    const region = screen.getByRole('status')
    expect(region).toBeEmptyDOMElement()

    rerender(<Toasts flash={{ id: 'r1', notice: '已保存' }} />)
    expect(screen.getByRole('status')).toBe(region)
    expect(region).toHaveTextContent('已保存')
  })

  it('有 Layout 的提示区时画进那个区域', () => {
    const region = document.createElement('div')
    document.body.appendChild(region)
    render(<ToastRegion.Provider value={region}><Toasts flash={{ notice: '已保存' }} /></ToastRegion.Provider>)

    expect(region).toHaveTextContent('已保存')
    region.remove()
  })
})

it('后续请求相同反馈可重新显示', async () => {
 const { rerender } = render(<Toasts flash={{ id: 'request-1', notice: '已保存' }} />)
 await userEvent.click(screen.getByRole('button', { name: '关闭' }))
 expect(screen.queryByText('已保存')).toBeNull()
 rerender(<Toasts flash={{ id: 'request-2', notice: '已保存' }} />)
 expect(screen.getByRole('status')).toHaveTextContent('已保存')
})

it('新请求的相同提示重新计时，避免刚出现就消失', () => {
 vi.useFakeTimers()
 const { rerender } = render(<Toasts flash={{ id: 'first', notice: '已保存' }} />)
 act(() => vi.advanceTimersByTime(4000))
 rerender(<Toasts flash={{ id: 'second', notice: '已保存' }} />)
 act(() => vi.advanceTimersByTime(1000))
 expect(screen.getByRole('status')).toHaveTextContent('已保存')
 act(() => vi.advanceTimersByTime(4000))
 expect(screen.queryByText('已保存')).toBeNull()
 vi.useRealTimers()
})
