import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import Show, { type DailyShowProps } from '@/pages/Daily/Show'
import { router } from '../support/inertia'
import { dailyIssue, item, source } from '../support/props'

// 日刊详情（也是首页 D20）。这里验的是页面自己的三件事：
// 期级状态选哪一句事实句、切来源只改地址栏、栏级状态与栏尾外链。
// 文案是服务端定稿的附录 B 原句，页面只负责选，不另写一份。

const sources = [
  source(),
  source({ id: 'src-gh', name: 'GitHub Trending', adapter: 'github_trending' }),
  source({ id: 'src-had', name: 'Hackaday', adapter: 'rss' }),
]

function show(overrides: Partial<DailyShowProps> = {}) {
  const props: DailyShowProps = {
    issue: dailyIssue(),
    missing: false,
    sources,
    items_by_source: { 'src-hn': [item()] },
    active_source_id: 'src-hn',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }

  return render(<Show {...props} />)
}

// 列表区顶上那句事实句（IssueNotice / SourceState 共用 .state-line）
function noticeText(container: HTMLElement) {
  return container.querySelector('.issue-body .state-line')?.textContent ?? null
}

beforeEach(() => {
  window.history.replaceState({ page: 'daily' }, '', '/daily/2026-09-08')
})

afterEach(() => {
  vi.restoreAllMocks()
  router.visit.mockClear()
})

describe('期级状态选哪一句（bodyNotice）', () => {
  // R-1.6 缺期不是 404：日期照常，列表区只有这一句，连来源索引条都没有
  it('缺期只有「本期未生成」，没有索引条', () => {
    const { container } = show({ missing: true, issue: dailyIssue({ state: null, status: '本期未生成' }) })

    expect(noticeText(container)).toBe('本期未生成')
    expect(screen.queryAllByRole('tab')).toHaveLength(0)
    expect(container.querySelectorAll('.item-row')).toHaveLength(0)
  })

  it('生成中在列表区说「生成中，约 1 分钟后刷新」，索引条还在', () => {
    const { container } = show({
      issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新', time_label: '06:00' }),
    })

    expect(noticeText(container)).toBe('生成中，约 1 分钟后刷新')
    expect(screen.getAllByRole('tab')).toHaveLength(3)
    expect(container.querySelectorAll('.item-row')).toHaveLength(0)
  })

  it('空刊说「今日为空刊，管理员已收到通知」', () => {
    const { container } = show({ issue: dailyIssue({ state: 'empty', status: '今日为空刊，管理员已收到通知' }) })

    expect(noticeText(container)).toBe('今日为空刊，管理员已收到通知')
  })

  // 已发布的期不在列表区说话，哪怕期头挂着「已于 06:42 修订」这种来历标签
  it('已发布没有事实句，直接是条目', () => {
    const { container } = show({ issue: dailyIssue({ status: '已于 06:42 修订' }) })

    expect(noticeText(container)).toBeNull()
    expect(container.querySelectorAll('.item-row')).toHaveLength(1)
  })
})

describe('切来源（本地状态 + ?source= 深链）', () => {
  it('切一次只改地址栏，不回服务端', async () => {
    const user = userEvent.setup()
    const replaceState = vi.spyOn(window.history, 'replaceState')
    show()

    await user.click(screen.getAllByRole('tab')[1])

    expect(replaceState).toHaveBeenCalledTimes(1)
    // 带上现有的 history.state：Inertia 的页面快照存在那里，前进后退还要用
    expect(replaceState).toHaveBeenCalledWith(
      { page: 'daily' },
      '',
      expect.stringContaining('/daily/2026-09-08?source=src-gh'),
    )
    expect(window.location.search).toBe('?source=src-gh')
    expect(router.visit).not.toHaveBeenCalled()
  })

  it('切换换掉的是条目，不是整页', async () => {
    const user = userEvent.setup()
    show({
      items_by_source: {
        'src-hn': [item()],
        'src-gh': [item({ id: 'itm-gh-1', title: 'openclaw/openclaw', url: 'https://github.com/openclaw/openclaw' })],
      },
    })

    expect(screen.getByRole('link', { name: 'Show HN: A terminal log viewer written in Rust' })).toBeInTheDocument()

    await user.click(screen.getAllByRole('tab')[1])

    expect(screen.getByRole('link', { name: 'openclaw/openclaw' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Show HN: A terminal log viewer written in Rust' })).toBeNull()
  })

  // 服务端已经按 ?source= 挑好了当前来源（DailyIssuesController#show），页面拿它当种子
  it('当前来源的种子来自 props', () => {
    show({ active_source_id: 'src-had', items_by_source: { 'src-had': [item({ title: 'A 3D-printed rotary phone' })] } })

    expect(screen.getAllByRole('tab')[2]).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('link', { name: 'A 3D-printed rotary phone' })).toBeInTheDocument()
  })

  it('一个来源都没有时只留事实句', () => {
    const { container } = show({
      sources: [],
      active_source_id: null,
      items_by_source: {},
      issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新' }),
    })

    expect(noticeText(container)).toBe('生成中，约 1 分钟后刷新')
    expect(screen.queryAllByRole('tab')).toHaveLength(0)
  })
})

describe('栏级状态与栏尾外链（SourceBody）', () => {
  function panel() {
    return within(screen.getByRole('tabpanel'))
  }

  it('抓取失败留一句加上次成功时间', () => {
    show({
      sources: [source({ state: 'failed', last_ok_label: '9月7日 06:11' })],
      active_source_id: 'src-hn',
      items_by_source: {},
    })

    expect(panel().getByText('今日抓取失败，已通知管理员')).toBeInTheDocument()
    expect(panel().getByText('上次成功 9月7日').closest('span')?.parentElement).toHaveTextContent('上次成功 9月7日 06:11')
  })

  it('没有上次成功时间就只有那一句', () => {
    show({ sources: [source({ state: 'failed', last_ok_label: null })], active_source_id: 'src-hn', items_by_source: {} })

    expect(panel().getByText('今日抓取失败，已通知管理员')).toBeInTheDocument()
    expect(panel().queryByText(/上次成功/)).toBeNull()
  })

  it('今日无新内容只有一句，没有插图', () => {
    const { container } = show({ sources: [source({ state: 'empty' })], active_source_id: 'src-hn', items_by_source: {} })

    expect(panel().getByText('今日无新内容')).toBeInTheDocument()
    expect(container.querySelector('.source-state-failed')).toBeNull()
  })

  // 措辞是第八轮定的「来源名 完整榜单 ↗」；箭头是图标，名字那半边走 Mixed 拆成两段，
  // 所以按类名取这条外链，再核对整条的文字
  it('栏尾是「来源名 完整榜单」，新标签页打开', () => {
    const { container } = show()

    const foot = container.querySelector('.source-foot')
    expect(foot).toHaveTextContent('Hacker News 完整榜单')
    expect(foot).toHaveAttribute('href', 'https://news.ycombinator.com/news')
    expect(foot).toHaveAttribute('target', '_blank')
    expect(foot?.getAttribute('rel')).toContain('noopener')
  })

  it('源站地址算不出来时整条收掉', () => {
    const { container } = show({ sources: [source({ home_url: null })], active_source_id: 'src-hn' })

    expect(container.querySelector('.source-foot')).toBeNull()
  })

  it('条目按 props 里的顺序排，序号用 rank', () => {
    const { container } = show({
      items_by_source: {
        'src-hn': [item({ id: 'a', title: '第一条', rank: 1 }), item({ id: 'b', title: '第二条', rank: 2 })],
      },
    })

    const ranks = Array.from(container.querySelectorAll('.item-rank')).map((el) => el.textContent)
    const titles = Array.from(container.querySelectorAll('.item-title')).map((el) => el.textContent)
    expect(ranks).toEqual(['1', '2'])
    expect(titles).toEqual(['第一条', '第二条'])
  })

  it('rank 为空时按位置补序号', () => {
    const { container } = show({
      items_by_source: { 'src-hn': [item({ id: 'a', rank: null }), item({ id: 'b', rank: null })] },
    })

    expect(Array.from(container.querySelectorAll('.item-rank')).map((el) => el.textContent)).toEqual(['1', '2'])
  })
})
