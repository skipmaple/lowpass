import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'

import Index from '@/pages/Admin/Issues/Index'
import { router, setPageProps } from '../support/inertia'
import { adminIssueRow } from '../support/props'

// 期（5.6，画布 admin_issues() 与 admin_dialogs()）

function show(overrides: Record<string, unknown> = {}) {
  const props = {
    month_label: '2026 年 9 月',
    prev_month: { key: '2026-08', label: '8 月' },
    next_month: null,
    summary: '9 月 · 8 期 · 1 空刊 · 1 缺期',
    kind: 'all' as const,
    rows: [
      adminIssueRow({ period_key: '2026-09-09', state: 'missing', state_label: '缺期', time_label: null, source_marks: null, refetchable_sources: [] }),
      adminIssueRow(),
      adminIssueRow({ kind: 'weekly', period_key: '2026-W36', time_label: '9月4日 09:03', source_marks: '阮一峰 42', refetchable_sources: [{ id: 'src-ry', name: '阮一峰科技爱好者周刊' }] }),
    ],
    today_issue_exists: false,
    active_runs: [],
    finished_runs: [],
    daily_time: '06:00',
    latest_weekly_key: null,
    ...overrides,
  }
  setPageProps({ ...props, flash: {}, errors: {} })
  return render(<Index {...(props as Parameters<typeof Index>[0])} />)
}

afterEach(() => {
  router.post.mockClear()
  router.reload.mockClear()
})

// 「理由」格里的反白小签（第 6 格）。整行找会撞上状态格里同样是墨色方块的 Mark
const reasonChip = (row: HTMLElement) => within(row).getAllByRole('cell')[5].querySelector('span[style*="background: var(--ink)"]')

describe('Admin/Issues/Index', () => {
  it('期头、筛选、翻月、行与汇总', () => {
    const { container } = show()

    expect(screen.getByRole('link', { name: '期' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '日刊' })).toHaveAttribute('href', '/admin/issues?kind=daily')
    expect(screen.getByRole('link', { name: '8 月' })).toHaveAttribute('href', '/admin/issues?month=2026-08')
    const rows = screen.getAllByRole('row')
    expect(rows).toHaveLength(4)
    expect(within(rows[1]).getByText('缺期')).toBeInTheDocument()
    expect(within(rows[1]).getByRole('button', { name: '补生成' })).toBeInTheDocument()
    expect(within(rows[2]).getByText('HN 10 · GH 10 · HAD 10')).toBeInTheDocument()
    expect(within(rows[2]).getByRole('link', { name: '查看' })).toHaveAttribute('href', '/daily/2026-09-08')
    expect(within(rows[3]).getByRole('link', { name: '查看' })).toHaveAttribute('href', '/weekly/2026-W36')
    // 汇总走 Mixed（中文夹数字，且「月/期」是中文相邻规则里的日期单位），文字被拆进多个 span：
    // 断言 textContent 而不是 getByText 整句（与 AdminSourcesIndex.test.tsx 的 .admin-summary 断言同一个理由）
    expect(container.querySelector('.admin-summary')?.textContent).toContain('9 月 · 8 期 · 1 空刊 · 1 缺期')
  })

  it('补生成 POST backfill', async () => {
    show()

    await userEvent.click(screen.getByRole('button', { name: '补生成' }))
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-09/backfill')
  })

  it('重抓某源：对话框里选源再确认', async () => {
    show()

    await userEvent.click(screen.getAllByRole('button', { name: '重抓某源' })[0])
    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveTextContent('重抓 2026-09-08 的哪个来源？')
    await userEvent.click(within(dialog).getByRole('button', { name: 'GitHub Trending' }))
    await userEvent.click(within(dialog).getByRole('button', { name: '重抓' }))

    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/refetch', { source_id: 'src-gh' })
  })

  it('立即生成：无期直接 POST；有期先弹附录 B 的确认', async () => {
    show()
    await userEvent.click(screen.getByRole('button', { name: '立即生成今日日刊' }))
    expect(router.post).toHaveBeenCalledWith('/admin/today_issue', {})

    router.post.mockClear()
    show({ today_issue_exists: true })
    // tsconfig 的 lib 是 ES2020，Array#at 没有类型声明（运行时其实支持）：改用下标取最后一个，跑 tsc 才过
    const buttons = screen.getAllByRole('button', { name: '立即生成今日日刊' })
    await userEvent.click(buttons[buttons.length - 1])
    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveTextContent('今日日刊已存在。要对所有来源重抓吗？')
    await userEvent.click(within(dialog).getByRole('button', { name: '重抓全部' }))
    expect(router.post).toHaveBeenCalledWith('/admin/today_issue', { confirm: '1' })
  })

  it('有进行中的任务：该行按钮禁用、轮询开着', () => {
    show({ active_runs: [{ id: 'r1', source_name: 'Hacker News', period_key: '2026-09-08' }] })

    const row = screen.getAllByRole('row')[2]
    expect(within(row).getByRole('button', { name: '进行中' })).toBeDisabled()
  })

  it('日刊行的理由格与整期重生成', async () => {
    show({ rows: [adminIssueRow({ reasons: { label: '缺 3 条', missing: 3, ready: true } }), adminIssueRow({ period_key: '2026-09-07', reasons: { label: '已生成', missing: 0, ready: true } })] })
    const rows = screen.getAllByRole('row')
    // 缺 N 条是反白小签（设计 §6.2）：文字在墨色块里，Mixed 会把中文与数字切成几段，按 textContent 断言
    expect(reasonChip(rows[1])?.textContent).toBe('缺 3 条')
    expect(within(rows[2]).getByText('已生成')).toBeInTheDocument()
    expect(reasonChip(rows[2])).toBeNull()
    await userEvent.click(within(rows[1]).getByRole('button', { name: '重生成理由' }))
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/reasons')
  })

  it('生成不了时理由格写明、按钮禁用（看 ready 不看文案）；周刊行没有理由格', () => {
    show({
      rows: [
        adminIssueRow({ reasons: { label: '未配置模型供应商', missing: 10, ready: false } }),
        adminIssueRow({ period_key: '2026-09-07', reasons: { label: '兴趣画像为空', missing: 10, ready: false } }),
        adminIssueRow({ kind: 'weekly', period_key: '2026-W36', reasons: null }),
      ],
    })
    const rows = screen.getAllByRole('row')
    expect(within(rows[1]).getByText('未配置模型供应商')).toBeInTheDocument()
    expect(within(rows[1]).getByRole('button', { name: '重生成理由' })).toBeDisabled()
    // 生成不了的时候那一格不是「缺 N 条」，也就不该反白
    expect(reasonChip(rows[2])).toBeNull()
    expect(within(rows[2]).getByText('兴趣画像为空')).toBeInTheDocument()
    expect(within(rows[2]).getByRole('button', { name: '重生成理由' })).toBeDisabled()
    expect(within(rows[3]).queryByRole('button', { name: '重生成理由' })).toBeNull()
  })
})
