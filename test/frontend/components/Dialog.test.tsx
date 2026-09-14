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
})
