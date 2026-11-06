import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Index from '@/pages/Admin/Issues/Index'
import { router, setPageProps } from '../support/inertia'
import { adminIssueReasons, adminIssueRow } from '../support/props'

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
  vi.unstubAllGlobals()
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

  it('重抓选源的 Tab 首尾跟随当前单选项，箭头改选后仍留在框内', async () => {
    const user = userEvent.setup()
    show({ rows: [adminIssueRow({ refetchable_sources: [
      { id: 'src-hn', name: 'Hacker News' },
      { id: 'src-gh', name: 'GitHub Trending' },
      { id: 'src-had', name: 'Hackaday' },
    ] })] })
    const opener = screen.getByRole('button', { name: '重抓某源' })
    await user.click(opener)
    const dialog = screen.getByRole('dialog')
    await user.tab({ shift: true })
    expect(within(dialog).getByRole('radio', { name: 'Hacker News' })).toHaveFocus()

    for (const name of ['GitHub Trending', 'Hackaday']) {
      await user.keyboard('{ArrowDown}')
      const selected = within(dialog).getByRole('radio', { name })
      expect(selected).toBeChecked()
      expect(selected).toHaveFocus()
      await user.tab({ shift: true })
      expect(within(dialog).getByRole('button', { name: `重抓 ${name}` })).toHaveFocus()
      await user.tab()
      expect(selected).toHaveFocus()
      await user.tab()
      expect(within(dialog).getByRole('button', { name: '取消' })).toHaveFocus()
      await user.tab()
      await user.tab()
      expect(selected).toHaveFocus()
      expect(selected).toBeChecked()
    }
    await user.keyboard('{Escape}')
    expect(opener).toHaveFocus()
    expect(router.post).not.toHaveBeenCalled()
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
    show({ rows: [adminIssueRow({ reasons: adminIssueReasons({ missing: 3 }) }), adminIssueRow({ period_key: '2026-09-07', reasons: adminIssueReasons() })] })
    const rows = screen.getAllByRole('row')
    // Mixed 会把中文与数字切成几段，按完整状态文案断言。
    expect(reasonChip(rows[1])?.textContent).toBe('缺 3 条')
    expect(within(rows[2]).getAllByRole('cell')[5]).toHaveTextContent('已有理由 30 条')
    expect(reasonChip(rows[2])).toBeNull()
    await userEvent.click(within(rows[1]).getByRole('button', { name: '重生成理由' }))
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/reasons', {}, expect.any(Object))
  })

  it('理由从排队到运行持续刷新，完成后停止轮询并恢复操作', () => {
    vi.useFakeTimers()
    const reason = { ...adminIssueReasons(), label: '缺 3 条', missing: 3, ready: true }
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

    rerender(<Index {...props} rows={[adminIssueRow({ reasons: { ...adminIssueReasons(), label: '已生成', missing: 0, ready: true, progress: { status: 'completed', active: false, label: '已完成', detail: '已生成 27 条', error: null } } })]} />)
    expect(screen.getByText('已完成')).toBeVisible()
    expect(screen.getByRole('button', { name: '重生成理由' })).toBeEnabled()
    act(() => vi.advanceTimersByTime(10000))
    expect(router.reload).toHaveBeenCalledTimes(2)
  })

  it('理由与抓取同时运行只开一组轮询，抓取结束后理由继续刷新', () => {
    vi.useFakeTimers()
    const rows = [adminIssueRow({ reasons: { ...adminIssueReasons(), label: '缺 3 条', missing: 3, ready: true, progress: { status: 'running', active: true, label: '生成中', detail: '已处理 7 / 27 条', error: null } } })]
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
    const reason = { ...adminIssueReasons(), label: '已生成', missing: 0, ready: true }
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
    const reason = { ...adminIssueReasons(), label: '已生成', missing: 0, ready: true }
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
        adminIssueRow({ reasons: adminIssueReasons({ missing: 10, ready: false, unready_label: '未配置模型供应商' }) }),
        adminIssueRow({ period_key: '2026-09-07', reasons: adminIssueReasons({ missing: 10, ready: false, unready_label: '兴趣画像为空' }) }),
        adminIssueRow({ kind: 'weekly', period_key: '2026-W36', reasons: null }),
      ],
    })
    const rows = screen.getAllByRole('row')
    expect(within(rows[1]).getByText('未配置模型供应商')).toBeInTheDocument()
    expect(within(rows[1]).getByRole('button', { name: '重生成理由' })).toBeDisabled()
    // 准备状态不覆盖真实缺失；只有缺失数量使用反白签。
    expect(reasonChip(rows[2])?.textContent).toBe('缺 10 条')
    expect(within(rows[2]).getByText('兴趣画像为空')).toBeInTheDocument()
    expect(within(rows[2]).getByRole('button', { name: '重生成理由' })).toBeDisabled()
    expect(within(rows[3]).queryByRole('button', { name: '重生成理由' })).toBeNull()
  })

  it('shows four real reason counts and separate readiness', () => {
    show({ rows: [adminIssueRow({ reasons: adminIssueReasons({ with_reason: 3, abstained: 2, retained: 1, missing: 4, ready: false, unready_label: '未配置模型供应商', last_assessed_label: '最后处理 2026-10-23 09:30' }) })] })
    const row = screen.getAllByRole('row')[1]
    const cell = within(row).getAllByRole('cell')[5]
    for (const text of ['已有理由 3 条', '资料不足未写 2 条', '保留旧理由 1 条（本次资料不足）', '缺 4 条', '最后处理 2026-10-23 09:30', '未配置模型供应商']) {
      expect(cell).toHaveTextContent(text)
    }
    expect(reasonChip(row)?.textContent).toBe('缺 4 条')
    expect(within(row).getByRole('button', { name: '重生成理由' })).toBeDisabled()
    expect(within(row).getByRole('button', { name: '重生成理由' })).toHaveAttribute('title', '未配置模型供应商')
  })

  it('excludes legal abstentions from pending issues', async () => {
    show({ rows: [
      adminIssueRow({ period_key: '2026-09-08', reasons: adminIssueReasons({ with_reason: 0, abstained: 3, retained: 2 }) }),
      adminIssueRow({ period_key: '2026-09-07', reasons: adminIssueReasons({ missing: 1 }) }),
    ] })
    await userEvent.click(screen.getByRole('checkbox', { name: '待处理' }))
    expect(screen.queryByText('2026/09/08')).toBeNull()
    expect(screen.getByText('2026/09/07')).toBeInTheDocument()
  })

  it('只有保留原文仍能进入重评，零目标不能确认，画像为空不影响翻译', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce({ ok: true, json: async () => ({ token: 'normal', target_count: 0 }) }).mockResolvedValueOnce({ ok: true, json: async () => ({ token: 'reassess', target_count: 2 }) })
    vi.stubGlobal('fetch', fetcher)
    show({ rows: [adminIssueRow({ reasons: adminIssueReasons({ ready: false, unready_label: '兴趣画像为空' }), translations: { pending: 0, preserved: 2, ready: true, unready_label: null } })] })
    const opener = screen.getByRole('button', { name: '补齐译文' })
    expect(opener).toBeEnabled()
    await userEvent.click(opener)
    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveTextContent('可能产生额外模型费用')
    await waitFor(() => expect(dialog).toHaveTextContent('本次处理 0 条'))
    expect(within(dialog).getByRole('button', { name: '提交补全' })).toBeDisabled()
    await userEvent.click(within(dialog).getByRole('checkbox', { name: '重新评估保留原文的条目' }))
    await waitFor(() => expect(within(dialog).getByRole('button', { name: '提交补全' })).toBeEnabled())
    await userEvent.click(within(dialog).getByRole('button', { name: '提交补全' }))
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/translations', { token: 'reassess' }, expect.any(Object))
    // 提交时按钮禁用，焦点应留在对应行，而非丢到 BODY。
    expect(opener.closest('[data-table-row-key]')).toHaveFocus()
  })

  it('预览加载可取消，较慢旧选项响应不能覆盖新预览', async () => {
    let resolveOld!: (value: unknown) => void
    const old = new Promise((resolve) => { resolveOld = resolve })
    const fetcher = vi.fn().mockReturnValueOnce(old).mockResolvedValueOnce({ ok: true, json: async () => ({ token: 'new', target_count: 3 }) })
    vi.stubGlobal('fetch', fetcher)
    show({ rows: [adminIssueRow({ translations: { pending: 1, preserved: 2, ready: true, unready_label: null } })] })
    await userEvent.click(screen.getByRole('button', { name: '补齐译文' }))
    const dialog = screen.getByRole('dialog')
    expect(within(dialog).getByRole('button', { name: '取消' })).toBeEnabled()
    expect(within(dialog).getByRole('button', { name: '提交补全' })).toBeDisabled()
    await userEvent.click(within(dialog).getByRole('checkbox'))
    await waitFor(() => expect(dialog).toHaveTextContent('本次处理 3 条'))
    await act(async () => { resolveOld({ ok: true, json: async () => ({ token: 'old', target_count: 1 }) }); await old })
    await userEvent.click(within(dialog).getByRole('button', { name: '提交补全' }))
    expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/translations', { token: 'new' }, expect.any(Object))
  })

  it('缺译文计入待处理，保留原文不算故障，预览失败明确可取消', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 403 }))
    show({ rows: [
      adminIssueRow({ translations: { pending: 1, preserved: 0, ready: true, unready_label: null } }),
      adminIssueRow({ period_key: '2026-09-07', translations: { pending: 0, preserved: 2, ready: true, unready_label: null } }),
    ] })
    await userEvent.click(screen.getByRole('checkbox', { name: '待处理' }))
    expect(screen.getByText('2026/09/08')).toBeInTheDocument()
    expect(screen.queryByText('2026/09/07')).toBeNull()
    const opener = screen.getByRole('button', { name: '补齐译文' })
    await userEvent.click(opener)
    const dialog = screen.getByRole('dialog')
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('无法获取预览（403），请重新打开确认')
    expect(within(dialog).getByRole('button', { name: '提交补全' })).toBeDisabled()
    await userEvent.keyboard('{Escape}')
    expect(opener).toHaveFocus()
  })

  it.each([
    ['网络中断', () => Promise.reject(new TypeError('Failed to fetch: private proxy diagnostics')), '网络连接失败，请重新打开确认'],
    ['非JSON响应', () => Promise.resolve(new Response('<html>upstream response</html>', { status: 200 })), '预览响应无法读取，请重新打开确认'],
    ['不完整数据', () => Promise.resolve(new Response('null', { status: 200 })), '预览不完整，请重新打开确认'],
    ['空凭据', () => Promise.resolve(new Response(JSON.stringify({ token: '', target_count: 1 }), { status: 200 })), '预览不完整，请重新打开确认'],
  ])('%s有可恢复的中文反馈且不能提交', async (_label, response, message) => {
    vi.stubGlobal('fetch', vi.fn(response))
    show({ rows: [adminIssueRow({ translations: { pending: 1, preserved: 0, ready: true, unready_label: null } })] })
    const opener = screen.getByRole('button', { name: '补齐译文' })
    await userEvent.click(opener)
    const dialog = screen.getByRole('dialog')
    expect(await within(dialog).findByRole('alert')).toHaveTextContent(message)
    expect(dialog).not.toHaveTextContent(/Failed to fetch|Unexpected token|upstream response|private proxy/)
    expect(within(dialog).getByRole('button', { name: '提交补全' })).toBeDisabled()
    await userEvent.keyboard('{Escape}')
    expect(opener).toHaveFocus()
    expect(router.post).not.toHaveBeenCalled()
  })

  it('会话失效重定向有登录提示，不解析登录HTML也不能提交', async () => {
    const response = new Response('<html>login</html>', { status: 200 })
    Object.defineProperties(response, { redirected: { value: true }, url: { value: 'https://lowpass.test/login?next=%2Fadmin%2Fissues' } })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response))
    show({ rows: [adminIssueRow({ translations: { pending: 1, preserved: 0, ready: true, unready_label: null } })] })
    await userEvent.click(screen.getByRole('button', { name: '补齐译文' }))
    const dialog = screen.getByRole('dialog')
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('登录状态已失效，请刷新后重试')
    expect(within(dialog).getByRole('button', { name: '提交补全' })).toBeDisabled()
    expect(router.post).not.toHaveBeenCalled()
  })

})
