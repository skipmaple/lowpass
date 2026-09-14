import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'

import Dialog from '@/components/Dialog'

describe('Dialog', () => {
  it('open 时是 dialog，焦点在确认按钮，Escape 取消', async () => {
    const onCancel = vi.fn()
    const onConfirm = vi.fn()
    render(<Dialog open text="停用后不再抓取，历史内容保留。确认停用 Hackaday？" cancel="取消" confirm="停用" onCancel={onCancel} onConfirm={onConfirm} />)

    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveAttribute('aria-modal', 'true')
    // 名字指向那段问句本身，不是复制一份到 aria-label 上
    expect(dialog).toHaveAccessibleName('停用后不再抓取，历史内容保留。确认停用 Hackaday？')
    expect(screen.getByRole('button', { name: '停用' })).toHaveFocus()

    await userEvent.click(screen.getByRole('button', { name: '停用' }))
    expect(onConfirm).toHaveBeenCalledTimes(1)

    await userEvent.keyboard('{Escape}')
    expect(onCancel).toHaveBeenCalledTimes(1)
  })

  it('open 为 false 不渲染；busy 时确认按钮禁用', () => {
    const { rerender } = render(<Dialog open={false} text="x" cancel="取消" confirm="好" onCancel={() => {}} onConfirm={() => {}} />)
    expect(screen.queryByRole('dialog')).toBeNull()

    rerender(<Dialog open text="x" cancel="取消" confirm="好" busy onCancel={() => {}} onConfirm={() => {}} />)
    expect(screen.getByRole('button', { name: '好' })).toBeDisabled()
  })

  // 焦点不能跑到遮罩后面那一页上：走到两头就绕回来
  it('Tab 在纸卡里转圈：最后一个回到第一个，Shift+Tab 反过来', async () => {
    render(<Dialog open text="停用后不再抓取，历史内容保留。确认停用 Hackaday？" cancel="取消" confirm="停用" onCancel={() => {}} onConfirm={() => {}} />)

    const cancelButton = screen.getByRole('button', { name: '取消' })
    const confirmButton = screen.getByRole('button', { name: '停用' })
    expect(confirmButton).toHaveFocus()

    await userEvent.tab()
    expect(cancelButton).toHaveFocus()

    await userEvent.tab({ shift: true })
    expect(confirmButton).toHaveFocus()

    await userEvent.tab({ shift: true })
    expect(cancelButton).toHaveFocus()
  })

  // 父组件重渲染（比如 usePolling 每 5 秒 reload）时常会传一个新的内联 onCancel；
  // 副作用不该因为这个而重跑——重跑会把焦点收回去再塞回来，用户能看见按钮"闪"一下。
  it('rerender 时内联 onCancel 变了不重跑副作用：确认按钮不重新聚焦，Escape 仍调用最新回调', async () => {
    const onCancel1 = vi.fn()
    const onConfirm = vi.fn()
    const { rerender } = render(<Dialog open text="x" cancel="取消" confirm="停用" onCancel={onCancel1} onConfirm={onConfirm} />)

    const confirmButton = screen.getByRole('button', { name: '停用' })
    expect(confirmButton).toHaveFocus()
    const focusSpy = vi.spyOn(confirmButton, 'focus')

    const onCancel2 = vi.fn()
    rerender(<Dialog open text="x" cancel="取消" confirm="停用" onCancel={onCancel2} onConfirm={onConfirm} />)

    expect(focusSpy).not.toHaveBeenCalled()
    expect(confirmButton).toHaveFocus()

    await userEvent.keyboard('{Escape}')
    expect(onCancel1).not.toHaveBeenCalled()
    expect(onCancel2).toHaveBeenCalledTimes(1)
  })
})
