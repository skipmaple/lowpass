import { act, fireEvent, render, screen, within } from '@testing-library/react'
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

function media(compact: boolean) {
  let change: (event: { matches: boolean }) => void = () => {}
  vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: compact, addEventListener: (_name: string, listener: typeof change) => { change = listener }, removeEventListener: vi.fn() }))
  return (matches: boolean) => act(() => change({ matches }))
}

const focusHeaders = ['名称', '操作']
const focusWidths = ['1fr', '1fr']
const focusMobile = { primary: [0, 1], detailsLabel: '详情' }
const focusRows = ['Alpha', 'Beta'].map((name) => ({ key: name, cells: [name, <div>
  <a data-table-focus="edit" href={`/${name}/edit`}>编辑</a>
  <a data-table-focus="records" href={`/${name}/records`}>记录</a>
  <details><summary data-table-focus="more">更多操作</summary><button data-table-focus="test" type="button">测试抓取</button></details>
</div>] }))

function focusRow(name = 'Beta') {
  return screen.getByText(name).closest('li, [role="row"]') as HTMLElement
}

describe('Table responsive focus', () => {
  it.each([true, false])('跨断点往返仍在同一行编辑，下一Tab到本行记录（compact=%s）', async (compact) => {
    const resize = media(compact)
    render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} />)
    within(focusRow()).getByRole('link', { name: '编辑' }).focus()

    resize(!compact)
    expect(document.activeElement).toHaveAttribute('href', '/Beta/edit')
    await userEvent.tab()
    expect(document.activeElement).toHaveAttribute('href', '/Beta/records')
    resize(compact)
    expect(document.activeElement).toHaveAttribute('href', '/Beta/records')
  })

  it('恢复嵌套按钮时打开必要祖先，但聚焦summary本身不自动展开', async () => {
    const resize = media(false)
    render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={{ primary: [0], detailsLabel: '详情' }} />)
    const more = within(focusRow()).getByText('更多操作')
    await userEvent.click(more)
    within(focusRow()).getByRole('button', { name: '测试抓取' }).focus()

    resize(true)
    expect(document.activeElement).toBe(within(focusRow()).getByRole('button', { name: '测试抓取', hidden: true }))
    const details = focusRow().querySelectorAll('details')
    expect([...details].every((node) => node.open)).toBe(true)
    resize(false)
    expect(document.activeElement).toBe(within(focusRow()).getByRole('button', { name: '测试抓取', hidden: true }))
    expect(focusRow().querySelector('details')).toHaveAttribute('open')
    fireEvent.click(within(focusRow()).getByText('更多操作'))
    within(focusRow()).getByText('更多操作').focus()
    resize(true)
    expect(document.activeElement).toBe(within(focusRow()).getByText('更多操作'))
    expect(document.activeElement?.closest('details')).not.toHaveAttribute('open')
  })

  it('手机专有summary消失时回同一行现有入口', () => {
    const resize = media(true)
    render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} />)
    within(focusRow()).getByText('详情').focus()
    resize(false)
    expect(document.activeElement).toHaveAttribute('href', '/Beta/edit')
  })

  it.each([true, false])('焦点在已展开summary上也保留展开与后续Tab路径（compact=%s）', async (compact) => {
    const resize = media(compact)
    render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} />)
    await userEvent.click(within(focusRow()).getByText('更多操作'))
    resize(!compact)
    const summary = within(focusRow()).getByText('更多操作')
    expect(document.activeElement).toBe(summary)
    expect(summary.closest('details')).toHaveAttribute('open')
    await userEvent.tab()
    expect(document.activeElement).toBe(within(focusRow()).getByRole('button', { name: '测试抓取' }))
  })

  it('只读行没有入口时聚焦该行，往返可回详情且不增加Tab停点', () => {
    const resize = media(true)
    render(<Table headers={['名称', '邮箱']} widths={focusWidths} rows={[{ key: 'Alpha', cells: ['Alpha', 'a@example.com'] }, { key: 'Beta', cells: ['Beta', 'b@example.com'] }]} mobile={{ primary: [0], detailsLabel: '详情' }} />)
    within(focusRow()).getByText('详情').focus()
    resize(false)
    expect(document.activeElement).toBe(focusRow())
    expect(document.activeElement).toHaveAttribute('tabindex', '-1')
    resize(true)
    expect(document.activeElement).toBe(within(focusRow()).getByText('详情'))
  })

  it('焦点在表外或切换时被别处接管均不抢夺', () => {
    const resize = media(true)
    render(<><button type="button">表外</button><Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} /></>)
    const outside = screen.getByRole('button', { name: '表外' })
    outside.focus()
    resize(false)
    expect(document.activeElement).toBe(outside)
    within(focusRow()).getByRole('link', { name: '编辑' }).focus()
    act(() => { resize(true); outside.focus() })
    expect(document.activeElement).toBe(outside)
  })

  it('重排按稳定行键，目标禁用或隐藏时不误认另一动作', () => {
    const resize = media(true)
    const { rerender } = render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} />)
    within(focusRow()).getByRole('link', { name: '记录' }).focus()
    const changed = [{ ...focusRows[1], cells: ['Beta', <div><a data-table-focus="other" href="/Beta/other" hidden>隐藏</a><a data-table-focus="edit" href="/Beta/edit">编辑</a><button data-table-focus="records" disabled>进行中…</button></div>] }, focusRows[0]]
    act(() => {
      resize(false)
      rerender(<Table headers={focusHeaders} widths={focusWidths} rows={changed} mobile={focusMobile} />)
    })
    expect(document.activeElement).toHaveAttribute('href', '/Beta/edit')
  })

  it('同表另一行在提交前接管焦点时保留最新选择', () => {
    const resize = media(true)
    render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} />)
    within(focusRow()).getByRole('link', { name: '编辑' }).focus()
    act(() => {
      resize(false)
      within(focusRow('Alpha')).getByRole('link', { name: '记录' }).focus()
    })
    expect(document.activeElement).toHaveAttribute('href', '/Alpha/records')
  })

  it('同批往返未卸载控件，后续再次跨断点仍恢复当前焦点', () => {
    const resize = media(true)
    render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} />)
    const edit = within(focusRow()).getByRole('link', { name: '编辑' })
    edit.focus()
    act(() => { resize(false); resize(true) })
    expect(document.activeElement).toBe(edit)
    resize(false)
    expect(document.activeElement).toHaveAttribute('href', '/Beta/edit')
  })

  it('同批更新移除原行时回表格上下文，不能跳到别的行', () => {
    const resize = media(true)
    const { rerender } = render(<Table headers={focusHeaders} widths={focusWidths} rows={focusRows} mobile={focusMobile} />)
    within(focusRow()).getByRole('link', { name: '编辑' }).focus()
    act(() => {
      resize(false)
      rerender(<Table headers={focusHeaders} widths={focusWidths} rows={[focusRows[0]]} mobile={focusMobile} />)
    })
    expect(document.activeElement).toBe(screen.getByRole('table'))
    expect(document.activeElement).toHaveAttribute('tabindex', '-1')
  })

  it('回退入口的focus处理器转移焦点后不再抢下一个入口', () => {
    const resize = media(true)
    function show(withTarget: boolean) {
      return <><button type="button">表外</button><Table headers={focusHeaders} widths={focusWidths} rows={[{ key: 'Beta', cells: ['Beta', <div>
        <a data-table-focus="edit" href="/Beta/edit" onFocus={() => screen.getByRole('button', { name: '表外' }).focus()}>编辑</a>
        <a data-table-focus="records" href="/Beta/records">记录</a>
        {withTarget ? <button data-table-focus="test" type="button">测试抓取</button> : null}
      </div>] }]} mobile={focusMobile} /></>
    }
    const { rerender } = render(show(true))
    screen.getByRole('button', { name: '测试抓取' }).focus()
    act(() => { resize(false); rerender(show(false)) })
    expect(document.activeElement).toBe(screen.getByRole('button', { name: '表外' }))
  })
})
