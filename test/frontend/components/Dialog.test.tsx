import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'

import Dialog from '@/components/Dialog'

describe('Dialog', () => {
  it('open 时是 dialog，焦点在取消按钮，Escape 取消', async () => {
    const onCancel = vi.fn()
    const onConfirm = vi.fn()
    render(<Dialog open text="停用后不再抓取，历史内容保留。确认停用 Hackaday？" cancel="取消" confirm="停用" onCancel={onCancel} onConfirm={onConfirm} />)

    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveAttribute('aria-modal', 'true')
    // 名字指向那段问句本身，不是复制一份到 aria-label 上
    expect(dialog).toHaveAccessibleName('停用后不再抓取，历史内容保留。确认停用 Hackaday？')
    expect(screen.getByRole('button', { name: '取消' })).toHaveFocus()

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
    expect(screen.getByRole('button', { name: '好' })).toHaveAttribute('aria-busy', 'true')
  })

  it('未满足确认条件时仍可取消，不把不可用误报为正在执行', async () => {
    const onCancel = vi.fn()
    const onConfirm = vi.fn()
    render(<Dialog open text="请选择来源" cancel="取消" confirm="重抓来源" confirmDisabled onCancel={onCancel} onConfirm={onConfirm} />)

    expect(screen.getByRole('dialog')).toHaveAttribute('aria-busy', 'false')
    expect(screen.getByRole('button', { name: '重抓来源' })).toBeDisabled()
    expect(screen.getByRole('button', { name: '重抓来源' })).toHaveAttribute('aria-busy', 'false')
    expect(screen.getByRole('button', { name: '取消' })).toBeEnabled()
    expect(screen.getByRole('button', { name: '取消' })).toHaveFocus()
    await userEvent.click(screen.getByRole('button', { name: '取消' }))
    expect(onCancel).toHaveBeenCalledTimes(1)
    expect(onConfirm).not.toHaveBeenCalled()
  })

  it.each([false, true])('busy 恢复后纸卡上的焦点按 Tab 进入按钮（shift=%s）', async (shift) => {
    const user = userEvent.setup()
    const props = { text: '确认删除？', cancel: '取消', confirm: '确认删除', onCancel: () => {}, onConfirm: () => {} }
    const { rerender } = render(<Dialog open busy {...props} />)
    expect(screen.getByRole('dialog')).toHaveFocus()
    await user.tab({ shift })
    expect(screen.getByRole('dialog')).toHaveFocus()
    rerender(<Dialog open {...props} />)
    await user.tab({ shift })
    expect(screen.getByRole('button', { name: shift ? '确认删除' : '取消' })).toHaveFocus()
  })

  it('另一 form 的同名单选项不会替换当前 form 的首停点', async () => {
    const user = userEvent.setup()
    render(<Dialog open text="确认选择？" cancel="取消" confirm="确认" onCancel={() => {}} onConfirm={() => {}}>
      <form><label><input type="radio" name="source" />第一组</label></form>
      <form><label><input type="radio" name="source" defaultChecked />第二组</label></form>
    </Dialog>)
    await user.tab()
    await user.tab()
    expect(screen.getByRole('radio', { name: '第一组' })).toHaveFocus()
  })

  it('无名单选项保留独立首停点', async () => {
    const user = userEvent.setup()
    render(<Dialog open text="确认选择？" cancel="取消" confirm="确认" onCancel={() => {}} onConfirm={() => {}}>
      <label><input type="radio" />第一项</label>
      <label><input type="radio" defaultChecked />第二项</label>
    </Dialog>)
    await user.tab()
    await user.tab()
    expect(screen.getByRole('radio', { name: '第一项' })).toHaveFocus()
  })

  // 焦点不能跑到遮罩后面那一页上：走到两头就绕回来
  it('Tab 在纸卡里转圈：最后一个回到第一个，Shift+Tab 反过来', async () => {
    render(<Dialog open text="停用后不再抓取，历史内容保留。确认停用 Hackaday？" cancel="取消" confirm="停用" onCancel={() => {}} onConfirm={() => {}} />)

    const cancelButton = screen.getByRole('button', { name: '取消' })
    const confirmButton = screen.getByRole('button', { name: '停用' })
    expect(cancelButton).toHaveFocus()
    confirmButton.focus()

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

    const confirmButton = screen.getByRole('button', { name: '取消' })
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

it('等待文案只播报当前状态，等待期间保留确认和取消禁用', async () => {
  const onCancel = vi.fn()
  const onConfirm = vi.fn()
  const props = { open: true, text: '确认注销？', cancel: '取消', confirm: '确认注销', busyConfirm: '正在注销…', onCancel, onConfirm }
  const { rerender } = render(<Dialog {...props} />)
  expect(screen.getByRole('button', { name: '确认注销' })).toBeEnabled()

  rerender(<Dialog {...props} busy />)
  const confirm = screen.getByRole('button', { name: '正在注销…' })
  expect(confirm).toBeDisabled()
  expect(confirm).toHaveAttribute('aria-busy', 'true')
  expect(screen.getByRole('button', { name: '取消' })).toBeDisabled()
  await userEvent.keyboard('{Escape}')
  expect(onCancel).not.toHaveBeenCalled()
  expect(onConfirm).not.toHaveBeenCalled()
})

it('关闭时恢复触发按钮与背景滚动', async () => {
 const trigger = document.createElement('button')
 document.body.append(trigger)
 trigger.focus()
 const props = { text: '确认删除？', cancel: '取消', confirm: '删除', onCancel: () => {}, onConfirm: () => {} }
 const { rerender } = render(<Dialog open {...props} />)
 expect(screen.getByRole('button', { name: '取消' })).toHaveFocus()
 expect(document.documentElement.style.overflow).toBe('hidden')
 expect(document.body.style.overflow).toBe('hidden')
 expect(trigger).toHaveAttribute('inert')
 rerender(<Dialog open={false} {...props} />)
 expect(trigger).toHaveFocus()
 expect(trigger).not.toHaveAttribute('inert')
 expect(document.documentElement.style.overflow).toBe('')
 expect(document.body.style.overflow).toBe('')
 trigger.remove()
})

it.each(['close', 'unmount'] as const)('%s 原样恢复根节点和 body 各自的 overflow 值与优先级', (action) => {
  const root = document.documentElement, body = document.body
  root.style.setProperty('overflow-x', 'clip', 'important')
  root.style.setProperty('overflow-y', 'auto')
  body.style.setProperty('overflow', 'scroll', 'important')
  const read = (node: HTMLElement) => ['overflow-x', 'overflow-y'].map(property => [node.style.getPropertyValue(property), node.style.getPropertyPriority(property)])
  const before = [read(root), read(body)]
  const props = { text: '确认删除？', cancel: '取消', confirm: '删除', onCancel: () => {}, onConfirm: () => {} }
  const view = render(<Dialog open {...props} />)
  try {
    expect(root.style.overflow).toBe('hidden')
    expect(body.style.overflow).toBe('hidden')
    if (action === 'close') view.rerender(<Dialog open={false} {...props} />)
    else view.unmount()
    expect([read(root), read(body)]).toEqual(before)
  } finally {
    view.unmount()
    root.style.removeProperty('overflow')
    body.style.removeProperty('overflow')
  }
})
