import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'

import Runs from '@/pages/Admin/Sources/Runs'
import { router, setPageProps } from '../support/inertia'
import { adminRunRow } from '../support/props'

// 抓取记录（R-3.9、R-3.10，画布 admin_runs()）

function show(overrides: Record<string, unknown> = {}) {
  const props = {
    source: { id: 'src-had', name: 'Hackaday', adapter_label: 'RSS/Atom', publication: 'daily' as const },
    status: 'all' as const,
    runs: [adminRunRow(), adminRunRow({ id: 'run-2', status: 'failed', status_label: '失败', attempt_label: '3 / 3', item_count: null, dropped_count: null, error_summary: '连接超时', started_label: '9月7日 07:07:30', duration_label: '60.0 秒' })],
    latest_issue: { period_key: '2026-09-08', label: '9月8日' },
    active_runs: [],
    finished_runs: [],
    daily_time: '06:00',
    latest_weekly_key: null,
    ...overrides,
  }
  setPageProps({ ...props, flash: {}, errors: {} })
  return render(<Runs {...(props as Parameters<typeof Runs>[0])} />)
}

afterEach(() => {
  router.post.mockClear()
  router.reload.mockClear()
})

describe('Admin/Sources/Runs', () => {
  it('期头、筛选分段、表与汇总', () => {
    const { container } = show()

    expect(screen.getByRole('heading', { level: 1, name: 'Hackaday' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: '全部' })).toHaveAttribute('aria-current', 'true')
    expect(screen.getByRole('link', { name: '失败' })).toHaveAttribute('href', '/admin/sources/src-had/runs?status=failed')
    const rows = screen.getAllByRole('row')
    expect(rows).toHaveLength(3)
    // 开始时间、耗时都走 Mixed 按字符段拆分：日期单位与「秒」是文楷，数字与冒号是 Maple——
    // 整段套 .data（纯 Maple）会让这些汉字掉进操作系统回退字体（Fix round 1）。
    // Mixed 给 CJK 段的是内联 style.fontFamily，不是 className（lib/typeset.tsx 里核实过没有 className）；
    // 断言方式与仓库既有的 ItemRow.test.tsx / Footer.test.tsx / typeset.test.tsx 一致。
    expect(within(rows[1]).getByText('9月8日').style.fontFamily).toBe('var(--font-cjk)')
    expect(within(rows[1]).getByText('秒').style.fontFamily).toBe('var(--font-cjk)')
    expect(within(rows[2]).getByText('连接超时')).toBeInTheDocument()
    expect(within(rows[2]).getByText('3 / 3')).toBeInTheDocument()
    // 汇总走 Mixed（中文夹数字），文字被拆进多个 span：断言 textContent 而不是 getByText 整句
    // （与 AdminSourcesIndex.test.tsx 的 .admin-summary 断言同一个理由）
    expect(container.querySelector('.admin-toolbar')?.textContent).toContain('最近 50 次 · 保留 30 天 · 2 条')
  })

  it('重抓最新一期：POST refetch 带 source_id；进行中时禁用', async () => {
    show()

    await userEvent.click(screen.getByRole('button', { name: '重抓 9月8日' }))
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/refetch', { source_id: 'src-had' })

    show({ active_runs: [{ id: 'r1', source_name: 'Hackaday', period_key: '2026-09-08' }] })
    // tsconfig 的 lib 是 ES2020，Array#at 没有类型声明（运行时其实支持）：改用下标取最后一个，跑 tsc 才过
    const buttons = screen.getAllByRole('button', { name: '进行中' })
    expect(buttons[buttons.length - 1]).toBeDisabled()
  })

  it('没有期时不画重抓按钮', () => {
    show({ latest_issue: null })

    expect(screen.queryByRole('button', { name: /重抓/ })).toBeNull()
  })
})
