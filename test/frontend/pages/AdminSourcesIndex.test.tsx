import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Index from '@/pages/Admin/Sources/Index'
import * as admin from '@/lib/admin'
import { router, setPageProps } from '../support/inertia'
import { adminSourceRow, testFetchResult } from '../support/props'

// 信息源列表（R-3.1，画布 admin_sources()）：表、汇总、新建按钮、停用对话框、列表里的测试抓取只弹提示

function show(rows = [adminSourceRow(), adminSourceRow({ id: 'src-ry', sort_order: 1, name: '阮一峰科技爱好者周刊', adapter: 'ruanyf_weekly', adapter_label: '阮一峰周刊', publication: 'weekly', health: 'consecutive_failures', health_label: '连续失败', last_fetch_label: '9月9日 09:00 · 失败 · GitHub API 403', next_run_label: '9月10日 09:00' })]) {
  const props = { sources: rows, summary: '2 个来源 · 1 个日刊 · 1 个周刊', active_runs: [], daily_time: '06:00', latest_weekly_key: null }
  setPageProps({ ...props, flash: {}, errors: {} })
  return render(<Index {...props} />)
}

afterEach(() => {
  router.delete.mockClear()
  vi.restoreAllMocks()
})

describe('Admin/Sources/Index', () => {
  it('期头、索引条与表', () => {
    const { container } = show()

    expect(screen.getByRole('heading', { level: 1, name: '管理后台' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: '信息源' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '新建来源' })).toHaveAttribute('href', '/admin/sources/new')
    const rows = screen.getAllByRole('row')
    expect(rows).toHaveLength(3)
    // 名称与适配器同为「Hacker News」（真实数据里源名与适配器标签常撞在一起）：取第一个匹配即名称列
    expect(within(rows[1]).getAllByText('Hacker News')[0]).toBeInTheDocument()
    expect(within(rows[1]).getByText('正常')).toBeInTheDocument()
    expect(within(rows[1]).getByRole('link', { name: '编辑' })).toHaveAttribute('href', '/admin/sources/src-hn/edit')
    expect(within(rows[2]).getByText('连续失败')).toBeInTheDocument()
    // 汇总走 Mixed（中文夹数字），文字被拆进多个 span：断言 textContent 而不是 getByText 整句
    expect(container.querySelector('.admin-summary')?.textContent).toContain('2 个来源 · 1 个日刊 · 1 个周刊')
  })

  it('停用先弹附录 B 的确认，确认后 DELETE enablement', async () => {
    show()

    await userEvent.click(screen.getAllByRole('button', { name: '停用' })[0])
    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveTextContent('停用后不再抓取，历史内容保留。确认停用 Hacker News？')

    await userEvent.click(within(dialog).getByRole('button', { name: '停用' }))
    expect(router.delete).toHaveBeenCalledWith('/admin/sources/src-hn/enablement')
  })

  it('停用的源给「启用」，直接 POST', async () => {
    show([adminSourceRow({ enabled: false, health: 'disabled', health_label: '已停用', next_run_label: null })])

    await userEvent.click(screen.getByRole('button', { name: '启用' }))
    expect(router.post).toHaveBeenCalledWith('/admin/sources/src-hn/enablement')
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('列表里的测试抓取只弹一条提示', async () => {
    const spy = vi.spyOn(admin, 'testFetch').mockResolvedValue(testFetchResult())
    show()

    await userEvent.click(screen.getAllByRole('button', { name: '测试抓取' })[0])

    expect(spy).toHaveBeenCalledWith(expect.objectContaining({ id: 'src-hn', adapter: 'hacker_news' }))
    expect(await screen.findByRole('status')).toHaveTextContent('解析 24 条 · 丢弃 0 条 · 用时 1.8 秒')
  })

  it('测试抓取失败弹失败句', async () => {
    vi.spyOn(admin, 'testFetch').mockResolvedValue(testFetchResult({ ok: false, error: '连接超时（30 秒），请检查地址或稍后重试。', entries: [], parsed: 0 }))
    show()

    await userEvent.click(screen.getAllByRole('button', { name: '测试抓取' })[0])

    expect(await screen.findByRole('status')).toHaveTextContent('连接超时（30 秒），请检查地址或稍后重试。')
  })
})
