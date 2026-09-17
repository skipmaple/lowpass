import { act, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, expect, it } from 'vitest'
import Issues from '@/pages/Admin/Issues/Index'
import Runs from '@/pages/Admin/Sources/Runs'
import { router, setPageProps } from '../support/inertia'
import { adminIssueRow, adminRunRow } from '../support/props'

const props = { month: '2026-09', month_label: '2026 年 9 月', prev_month: null, next_month: null, summary: '', kind: 'all' as const, today_issue_exists: true, today_period_key: '2026-09-08', today_issue_state: 'published' as const, active_runs: [], finished_runs: [], rows: [adminIssueRow(), adminIssueRow({ period_key: '2026-09-07', state: 'missing', reasons: null, refetchable_sources: [] })] }
afterEach(() => router.post.mockClear())
function show() { setPageProps({ flash: {} }); return render(<Issues {...props} />) }
it('uses the actual today state and independently reports the target request error', async () => {
  show()
  expect(screen.getByRole('button', { name: '重抓今日日刊' })).toBeEnabled()
  await userEvent.click(screen.getByRole('button', { name: '补生成' }))
  expect(screen.getByRole('button', { name: '正在补生成…' })).toBeDisabled()
  const options = router.post.mock.calls[0][2]
  act(() => { options.onError({ base: '请求被拒绝' }); options.onFinish() })
  expect(screen.getByRole('alert')).toHaveTextContent('2026-09-07 · 请求被拒绝')
  expect(screen.getByRole('button', { name: '补生成' })).toBeEnabled()
})
it('offers native source radios and confirms the selected source and issue', async () => {
  show()
  await userEvent.click(screen.getByRole('button', { name: '重抓某源' }))
  const dialog = screen.getByRole('dialog')
  await userEvent.click(within(dialog).getByRole('radio', { name: 'GitHub Trending' }))
  expect(dialog).toHaveTextContent('2026-09-08')
  await userEvent.click(within(dialog).getByRole('button', { name: '重抓 GitHub Trending' }))
  expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/refetch', { source_id: 'src-gh' }, expect.any(Object))
})
it('filters pending issues using missing publication and reason counts', async () => {
  show()
  await userEvent.click(screen.getByRole('checkbox', { name: '待处理' }))
  expect(screen.queryByRole('link', { name: '查看' })).toBeNull()
  expect(screen.getByRole('button', { name: '补生成' })).toBeInTheDocument()
})
it('latest refetch confirms source and latest date even while viewing historical failures', async () => {
  setPageProps({ flash: {} })
  render(<Runs source={{ id: 'src-had', name: 'Hackaday', adapter_label: 'RSS/Atom', publication: 'daily' }} status="failed" runs={[adminRunRow({ error_summary: 'Historical error '.repeat(10), status: 'failed' })]} latest_issue={{ period_key: '2026-09-08', label: '9月8日' }} active_runs={[]} finished_runs={[]} />)
  await userEvent.click(screen.getByRole('button', { name: '重抓最新一期 · 9月8日' }))
  expect(router.post).not.toHaveBeenCalled()
  const dialog = screen.getByRole('dialog')
  expect(dialog).toHaveTextContent('2026-09-08')
  expect(dialog).toHaveTextContent('Hackaday')
  await userEvent.click(within(dialog).getByRole('button', { name: '确认重抓' }))
  expect(router.post).toHaveBeenCalledWith('/admin/issues/2026-09-08/refetch', { source_id: 'src-had' }, expect.any(Object))
  const disclosure = screen.getByText('错误详情').closest('details')!
  expect(disclosure).not.toHaveAttribute('open')
  await userEvent.click(screen.getByText('错误详情'))
  expect(disclosure).toHaveAttribute('open')
})

it('keeps today unavailable while its actual background run is active', () => {
  setPageProps({ flash: {} })
  render(<Issues {...props} active_runs={[{ id: 'active', period_key: '2026-09-08', source_name: 'Hacker News' }]} />)
  expect(screen.getByRole('button', { name: '今日日刊处理中…' })).toBeDisabled()
})

it('includes failed source outcomes in pending work without treating valid empty issues as failure', async () => {
  setPageProps({ flash: {} })
  render(<Issues {...props} rows={[adminIssueRow({ period_key: '2026-09-06', source_marks: 'HN 失败', reasons: null }), adminIssueRow({ period_key: '2026-09-05', state: 'empty', source_marks: 'HN 0', reasons: null })]} />)
  await userEvent.click(screen.getByRole('checkbox', { name: '待处理' }))
  expect(screen.getByRole('link', { name: '查看' })).toHaveAttribute('href', '/daily/2026-09-06')
})

it('keeps today generating unavailable while browsing a different month without manual runs', () => {
  setPageProps({ flash: {} })
  render(<Issues {...props} today_issue_state="generating" month="2026-08" month_label="2026 年 8 月" rows={[adminIssueRow({ period_key: '2026-08-31' })]} />)
  expect(screen.getByRole('button', { name: '今日日刊处理中…' })).toBeDisabled()
})
