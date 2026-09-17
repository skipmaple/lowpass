import { act, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Table from '@/components/Table'

afterEach(() => vi.unstubAllGlobals())

describe('Table', () => {
  it('小屏优先身份和操作，详情按需展开，切回桌面只保留一套控件', async () => {
    let onChange: (event: { matches: boolean }) => void = () => {}
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: true, addEventListener: (_name: string, listener: typeof onChange) => { onChange = listener }, removeEventListener: vi.fn() }))
    render(<Table headers={['名称', '邮箱', '操作']} widths={['1fr', '1fr', '1fr']} rows={[{ key: 'a', cells: ['Drew', 'drew@example.com', <button type="button">编辑</button>] }]} mobile={{ primary: [0, 2], detailsLabel: '账户详情' }} />)

    expect(screen.queryByRole('table')).toBeNull()
    const row = screen.getByRole('listitem')
    expect(within(row).getByText('Drew')).toBeVisible()
    expect(within(row).getByRole('button', { name: '编辑' })).toBeVisible()
    const disclosure = within(row).getByText('账户详情').closest('details')!
    expect(disclosure).not.toHaveAttribute('open')
    await userEvent.click(within(row).getByText('账户详情'))
    expect(disclosure).toHaveAttribute('open')
    expect(within(disclosure).getByText('drew@example.com')).toBeInTheDocument()

    act(() => onChange({ matches: false }))
    expect(screen.getByRole('table')).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: '编辑' })).toHaveLength(1)
    expect(screen.queryByRole('listitem')).toBeNull()
    expect(screen.getByText('drew@example.com')).toBeVisible()
  })

  it('表头与行', () => {
    render(<Table headers={['名称', '状态']} widths={['1fr', '80px']} rows={[{ key: 'a', cells: ['Hacker News', '启用'] }]} />)

    expect(screen.getByRole('table')).toBeInTheDocument()
    expect(screen.getAllByRole('columnheader').map((h) => h.textContent)).toEqual(['名称', '状态'])
    expect(screen.getAllByRole('row')).toHaveLength(2)
    expect(screen.getByText('Hacker News')).toBeInTheDocument()
  })

  it('空表显示一句', () => {
    render(<Table headers={['名称']} widths={['1fr']} rows={[]} empty="还没有来源" />)

    expect(screen.getByText('还没有来源')).toBeInTheDocument()
    expect(screen.getAllByRole('row')).toHaveLength(1)
  })
})
