import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'

import Issues from '@/pages/Admin/Issues/Index'
import Sources from '@/pages/Admin/Sources/Index'
import Runs from '@/pages/Admin/Sources/Runs'
import Users from '@/pages/Admin/Users/Index'
import { setPageProps } from '../support/inertia'
import { adminIssueRow, adminSourceRow, adminRunRow, adminUserRow } from '../support/props'

beforeEach(() => {
  vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() }))
  setPageProps({ flash: {}, errors: {} })
})
afterEach(() => vi.unstubAllGlobals())

it('手机刊物先显示日期、状态和唯一操作，时间与结果放进详情', async () => {
  render(<Issues month="2026-09" month_label="2026 年 9 月" prev_month={null} next_month={null} summary="" kind="all" rows={[adminIssueRow({ time_label: '发布 06:12 · 修订 06:42' })]} today_issue_exists={false} today_period_key="2026-09-09" today_issue_state={null} active_runs={[]} finished_runs={[]} />)

  const row = screen.getByRole('listitem')
  expect(within(row).getByText('2026-09-08')).toBeVisible()
  expect(within(row).getByText('已发布')).toBeVisible()
  expect(screen.getAllByRole('link', { name: '查看' })).toHaveLength(1)
  expect(within(row).getByRole('button', { name: '重抓某源' })).toBeVisible()
  const details = within(row).getByText('刊物详情').closest('details')!
  expect(details).not.toHaveAttribute('open')
  await userEvent.click(within(row).getByText('刊物详情'))
  expect(details).toHaveAttribute('open')
  expect(details).toHaveTextContent('发布 06:12 · 修订 06:42')
})

it('手机来源保留编辑、记录和健康状态，计划只需展开一次', async () => {
  render(<Sources sources={[adminSourceRow()]} summary="" />)

  const row = screen.getByRole('listitem')
  expect(within(row).getByText('正常')).toBeVisible()
  expect(screen.getAllByRole('link', { name: '编辑' })).toHaveLength(1)
  expect(within(row).getByRole('link', { name: '记录' })).toBeVisible()
  const details = within(row).getByText('抓取计划', { selector: 'summary' }).closest('details')!
  expect(details).not.toHaveAttribute('open')
  await userEvent.click(within(row).getByText('抓取计划', { selector: 'summary' }))
  expect(details).toHaveTextContent('上次抓取')
  expect(details).toHaveTextContent('下次计划')
  expect(details.querySelector('details')).toBeNull()
})

it('手机抓取记录直接显示状态和错误，指标可展开', async () => {
  render(<Runs source={{ id: 'src-hn', name: 'Hacker News', adapter_label: 'Hacker News', publication: 'daily' }} status="failed" runs={[adminRunRow({ status: 'failed', status_label: '失败', error_summary: '连接超时' })]} latest_issue={null} active_runs={[]} finished_runs={[]} />)

  const row = screen.getByRole('listitem')
  expect(within(row).getByText('失败')).toBeVisible()
  expect(within(row).getByText('连接超时')).toBeVisible()
  await userEvent.click(within(row).getByText('抓取详情', { selector: 'summary' }))
  expect(within(row).getByText('尝试')).toBeVisible()
})

it('手机用户保留身份、角色和邮箱，把登录元数据收起', async () => {
  render(<Users users={[adminUserRow()]} summary="" />)

  const row = screen.getByRole('listitem')
  expect(within(row).getByText('Drew Lee')).toBeVisible()
  expect(within(row).getByText('管理员')).toBeVisible()
  expect(within(row).getByText(adminUserRow().email!)).toBeVisible()
  const details = within(row).getByText('登录详情').closest('details')!
  expect(details).not.toHaveAttribute('open')
  await userEvent.click(within(row).getByText('登录详情'))
  expect(details).toHaveTextContent('Google · GitHub')
})
