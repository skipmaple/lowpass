import { act, fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Index from '@/pages/Admin/Issues/Index'
import { router, setPageProps } from '../support/inertia'
import { adminIssueRow } from '../support/props'

// 期（5.6，画布 admin_issues() 与 admin_dialogs()）

function show(overrides: Record<string, unknown> = {}) {
  const props = {
    month: '2026-09',
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
    today_period_key: '2026-09-09',
    today_issue_state: null,
    active_runs: [],
    finished_runs: [],
    daily_time: '06:00',
    latest_weekly_key: null,
    ...overrides,
  }
  setPageProps({ ...props, flash: {}, errors: {} })
  const page = props as Parameters<typeof Index>[0]
  return { ...render(<Index {...page} />), props: page }
}

afterEach(() => {
  router.post.mockClear()
  router.reload.mockClear()
  vi.useRealTimers()
})

// 「理由」格里的静态状态标签；颜色由当前主题决定，不以旧内联墨色识别。
const reasonChip = (row: HTMLElement) => within(row).getAllByRole('cell')[5].querySelector('.chip-static')

describe('Admin/Issues/Index', () => {
  it('切换刊物类型保留当前历史月份', () => {
    show({ month: '2025-12', month_label: '2025 年 12 月', kind: 'daily' })

    expect(screen.getByRole('link', { name: '全部' })).toHaveAttribute('href', '/admin/issues?month=2025-12')
    expect(screen.getByRole('link', { name: '日刊' })).toHaveAttribute('href', '/admin/issues?kind=daily&month=2025-12')
    expect(screen.getByRole('link', { name: '周刊' })).toHaveAttribute('href', '/admin/issues?kind=weekly&month=2025-12')
  })

  it('期头、筛选、翻月、行与汇总', () => {
    const { container } = show()

    expect(screen.getByRole('link', { name: '刊物管理' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '日刊' })).toHaveAttribute('href', '/admin/issues?kind=daily&month=2026-09')
    expect(screen.getByRole('link', { name: '8 月' })).toHaveAttribute('href', '/admin/issues?month=2026-08')
    const rows = screen.getAllByRole('row')
    expect(rows).toHaveLength(4)
    expect(within(rows[1]).getByText('缺期', { selector: 'span' })).toBeInTheDocument()
    expect(within(rows[1]).getByRole('img', { name: '缺期' })).toBeInTheDocument()
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
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-09/backfill', {}, expect.any(Object))
  })

  it('重抓某源：对话框里选源再确认', async () => {
    show()

    await userEvent.click(screen.getAllByRole('button', { name: '重抓某源' })[0])
    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveTextContent('重抓 2026/09/08 的哪个来源？')
    await userEvent.click(within(dialog).getByRole('radio', { name: 'GitHub Trending' }))
    await userEvent.click(within(dialog).getByRole('button', { name: '重抓 GitHub Trending' }))

    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/refetch', { source_id: 'src-gh' }, expect.any(Object))
  })

  it('立即生成：无期直接 POST；有期先弹附录 B 的确认', async () => {
    show()
    await userEvent.click(screen.getByRole('button', { name: '生成今日日刊' }))
    expect(router.post).toHaveBeenCalledWith('/admin/today_issue', {}, expect.any(Object))

    router.post.mockClear()
    show({ today_issue_exists: true })
    // tsconfig 的 lib 是 ES2020，Array#at 没有类型声明（运行时其实支持）：改用下标取最后一个，跑 tsc 才过
    const buttons = screen.getAllByRole('button', { name: '重抓今日日刊' })
    await userEvent.click(buttons[buttons.length - 1])
    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveTextContent('今日日刊已存在。要对所有来源重抓吗？')
    await userEvent.click(within(dialog).getByRole('button', { name: '重抓全部' }))
    expect(router.post).toHaveBeenCalledWith('/admin/today_issue', { confirm: '1' }, expect.any(Object))
  })

  it('有进行中的任务：该行按钮禁用、轮询开着', () => {
    show({ active_runs: [{ id: 'r1', source_name: 'Hacker News', period_key: '2026-09-08' }] })

    const row = screen.getAllByRole('row')[2]
    expect(within(row).getByRole('button', { name: '进行中' })).toBeDisabled()
  })

  it('日刊行的理由格与整期重生成', async () => {
    show({ rows: [adminIssueRow({ reasons: { label: '缺 3 条', missing: 3, ready: true } }), adminIssueRow({ period_key: '2026-09-07', reasons: { label: '已生成', missing: 0, ready: true } })] })
    const rows = screen.getAllByRole('row')
    // Mixed 会把中文与数字切成几段，按完整状态文案断言。
    expect(reasonChip(rows[1])?.textContent).toBe('缺 3 条')
    expect(within(rows[2]).getByText('已生成')).toBeInTheDocument()
    expect(reasonChip(rows[2])).toBeNull()
    await userEvent.click(within(rows[1]).getByRole('button', { name: '重生成理由' }))
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/reasons', {}, expect.any(Object))
  })

  it('理由从排队到运行持续刷新，完成后停止轮询并恢复操作', () => {
    vi.useFakeTimers()
    const reason = { label: '缺 3 条', missing: 3, ready: true }
    const queued = { status: 'queued' as const, active: true, label: '已排队', detail: '等待模型任务开始', error: null }
    const { rerender, props } = show({ rows: [adminIssueRow({ reasons: { ...reason, progress: queued } })] })

    expect(screen.getByText('已排队')).toBeVisible()
    expect(screen.getByText('等待模型任务开始')).toBeVisible()
    expect(screen.getByRole('button', { name: '理由排队中…' })).toBeDisabled()
    act(() => vi.advanceTimersByTime(5000))
    expect(router.reload).toHaveBeenCalledTimes(1)
    expect(router.reload.mock.calls[0][0].only).toContain('rows')

    rerender(<Index {...props} rows={[adminIssueRow({ reasons: { ...reason, progress: { ...queued, status: 'running', label: '生成中', detail: '已处理 7 / 27 条' } } })]} />)
    expect(screen.getByRole('button', { name: '理由生成中…' })).toBeDisabled()
    expect(screen.getByText('已处理 7 / 27 条')).toBeVisible()
    act(() => vi.advanceTimersByTime(5000))
    expect(router.reload).toHaveBeenCalledTimes(2)

    rerender(<Index {...props} rows={[adminIssueRow({ reasons: { label: '已生成', missing: 0, ready: true, progress: { status: 'completed', active: false, label: '已完成', detail: '已生成 27 条', error: null } } })]} />)
    expect(screen.getByText('已完成')).toBeVisible()
    expect(screen.getByRole('button', { name: '重生成理由' })).toBeEnabled()
    act(() => vi.advanceTimersByTime(10000))
    expect(router.reload).toHaveBeenCalledTimes(2)
  })

  it('理由与抓取同时运行只开一组轮询，抓取结束后理由继续刷新', () => {
    vi.useFakeTimers()
    const rows = [adminIssueRow({ reasons: { label: '缺 3 条', missing: 3, ready: true, progress: { status: 'running', active: true, label: '生成中', detail: '已处理 7 / 27 条', error: null } } })]
    const { rerender, props } = show({ rows, active_runs: [{ id: 'r1', source_name: 'Hacker News', period_key: '2026-09-08' }] })
    act(() => vi.advanceTimersByTime(5000))
    expect(router.reload).toHaveBeenCalledTimes(1)
    rerender(<Index {...props} active_runs={[]} />)
    act(() => vi.advanceTimersByTime(5000))
    expect(router.reload).toHaveBeenCalledTimes(2)
  })

  it('失败结果保留具体原因，旧理由齐全也进入待处理筛选', () => {
    vi.useFakeTimers()
    const progress = { status: 'running' as const, active: true, label: '生成中', detail: '已处理 7 / 27 条', error: null }
    const reason = { label: '已生成', missing: 0, ready: true }
    const { rerender, props } = show({ rows: [adminIssueRow({ reasons: { ...reason, progress } })] })
    fireEvent.click(screen.getByRole('checkbox', { name: '待处理' }))
    expect(screen.getByRole('button', { name: '理由生成中…' })).toBeInTheDocument()
    rerender(<Index {...props} rows={[adminIssueRow({ reasons: { ...reason, progress: { status: 'failed', active: false, label: '生成失败', detail: '本次生成 0 条，原理由已保留', error: '模型连接超时' } } })]} />)

    expect(screen.getByText('生成失败')).toBeVisible()
    expect(screen.getByText('模型连接超时')).toBeVisible()
    expect(screen.getByText('本次生成 0 条，原理由已保留')).toBeVisible()
    expect(screen.getByRole('button', { name: '重生成理由' })).toBeEnabled()
    act(() => vi.advanceTimersByTime(5000))
    expect(router.reload).not.toHaveBeenCalled()
  })

  it('部分失败即使没有缺理由也属于待处理，已完成不属于', () => {
    const reason = { label: '已生成', missing: 0, ready: true }
    show({ rows: [
      adminIssueRow({ reasons: { ...reason, progress: { status: 'partial', active: false, label: '部分失败', detail: '成功 24 条，失败 3 条', error: '模型响应不完整' } } }),
      adminIssueRow({ period_key: '2026-09-07', reasons: { ...reason, progress: { status: 'completed', active: false, label: '已完成', detail: '已生成 27 条', error: null } } }),
    ] })
    fireEvent.click(screen.getByRole('checkbox', { name: '待处理' }))
    expect(screen.getByText('部分失败')).toBeVisible()
    expect(screen.queryByText('已完成')).toBeNull()
    expect(screen.getAllByRole('button', { name: '重生成理由' })).toHaveLength(1)
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
