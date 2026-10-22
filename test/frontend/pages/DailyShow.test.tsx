import { act, render, screen, within } from '@testing-library/react'
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
    favorites: [],
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
  router.replace.mockClear()
})

describe('期级状态选哪一句（bodyNotice）', () => {
  // R-1.6 缺期不是 404：日期照常，列表区只有这一句，连来源索引条都没有
  it('缺期只有「本期未生成」，没有索引条', () => {
    const { container } = show({ missing: true, issue: dailyIssue({ state: null, status: '本期未生成' }) })

    expect(noticeText(container)).toBe('本期未生成')
    expect(screen.queryAllByRole('link', { name: /^(Hacker News|GitHub Trending|Hackaday)$/ })).toHaveLength(0)
    expect(container.querySelectorAll('.item-row')).toHaveLength(0)
  })

  it('生成中在列表区说「生成中，约 1 分钟后刷新」，索引条还在', () => {
    const { container } = show({
      issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新', time_label: '06:00' }),
    })

    expect(noticeText(container)).toBe('生成中，约 1 分钟后刷新')
    expect(screen.getAllByRole('link', { name: /^(Hacker News|GitHub Trending|Hackaday)$/ })).toHaveLength(3)
    expect(container.querySelectorAll('.item-row')).toHaveLength(0)
  })

  // 「约 1 分钟后刷新」不是空话：生成中每 10 秒部分重载一次，发布了就不再请求
  it('生成中自己刷新，发布后停', () => {
    vi.useFakeTimers()
    const { unmount } = show({ issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新', time_label: '06:00' }) })

    vi.advanceTimersByTime(10_000)
    expect(router.reload).toHaveBeenCalledWith({ only: ['issue', 'missing', 'sources', 'items_by_source', 'favorites'] })
    unmount()

    router.reload.mockClear()
    show()
    vi.advanceTimersByTime(30_000)
    expect(router.reload).not.toHaveBeenCalled()
    vi.useRealTimers()
  })

  it('空刊说「本期为空刊，管理员已收到通知」', () => {
    const { container } = show({ issue: dailyIssue({ state: 'empty', status: '本期为空刊，管理员已收到通知' }) })

    expect(noticeText(container)).toBe('本期为空刊，管理员已收到通知')
  })

  // 已发布的期不在列表区说话，哪怕期头挂着「已于 06:42 修订」这种来历标签
  it('已发布没有事实句，直接是条目', () => {
    const { container } = show({ issue: dailyIssue({ status: '已于 06:42 修订' }) })

    expect(noticeText(container)).toBeNull()
    expect(container.querySelectorAll('.item-row')).toHaveLength(1)
  })
})

describe('连续阅读与来源目录', () => {
  it('每栏均可返回来源目录，失败或没有源站外链时也保留入口', () => {
    show({ sources: [sources[0], { ...sources[1], state: 'failed', home_url: null }, sources[2]] })
    const returns = screen.getAllByRole('link', { name: '返回来源目录' })
    expect(returns).toHaveLength(3)
    for (const link of returns) expect(link).toHaveAttribute('href', '#source-directory')
  })

  it('全部来源按配置顺序同时呈现，目录是到正文的原生锚点', () => {
    show({
      active_source_id: 'src-had',
      items_by_source: {
        'src-hn': [item()],
        'src-gh': [item({ id: 'itm-gh-1', url_hash: 'hash-gh', title: 'openclaw/openclaw' })],
        'src-had': [item({ id: 'itm-had-1', url_hash: 'hash-had', title: 'A rotary phone' })],
      },
    })
    const directory = within(screen.getByRole('navigation', { name: '来源' }))
    expect(directory.getByRole('link', { name: 'GitHub Trending' })).toHaveAttribute('href', '#source-src-gh')
    expect(screen.getAllByRole('heading', { level: 2 }).map((h) => h.textContent)).toEqual(['Hacker News', 'GitHub Trending', 'Hackaday'])
    expect(screen.getAllByRole('heading', { level: 3 }).map((h) => h.textContent)).toEqual(['Show HN: A terminal log viewer written in Rust', 'openclaw/openclaw', 'A rotary phone'])
    expect(screen.getByRole('region', { name: 'GitHub Trending' })).toContainElement(screen.getByText('openclaw/openclaw'))
  })

  it('失败来源保留事实句，后续来源照常可读', () => {
    show({
      sources: [sources[0], { ...sources[1], state: 'failed' }, sources[2]],
      items_by_source: { 'src-had': [item({ title: 'A rotary phone' })] },
    })
    expect(within(screen.getByRole('region', { name: 'GitHub Trending' })).getByText('本期抓取失败，已通知管理员')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'A rotary phone' })).toBeInTheDocument()
  })

  it('一个来源都没有时只留事实句', () => {
    const { container } = show({ sources: [], active_source_id: null, items_by_source: {}, issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新' }) })
    expect(noticeText(container)).toBe('生成中，约 1 分钟后刷新')
    expect(screen.queryByRole('navigation', { name: '来源' })).toBeNull()
  })
})

describe('栏级状态与栏尾外链（SourceBody）', () => {
  function panel() {
    return within(screen.getByRole('region', { name: 'Hacker News' }))
  }

  it('抓取失败留一句加上次成功时间', () => {
    show({
      sources: [source({ state: 'failed', last_ok_label: '9月7日 06:11' })],
      active_source_id: 'src-hn',
      items_by_source: {},
    })

    expect(panel().getByText('本期抓取失败，已通知管理员')).toBeInTheDocument()
    expect(panel().getByText('上次成功 9月7日').closest('span')?.parentElement).toHaveTextContent('上次成功 9月7日 06:11')
  })

  it('没有上次成功时间就只有那一句', () => {
    show({ sources: [source({ state: 'failed', last_ok_label: null })], active_source_id: 'src-hn', items_by_source: {} })

    expect(panel().getByText('本期抓取失败，已通知管理员')).toBeInTheDocument()
    expect(panel().queryByText(/上次成功/)).toBeNull()
  })

  // R-1.6 补生成的期：不支持回填的源（7.7）说自己的那一句，不是「本期抓取失败」
  it('无法回填只有一句，没有插图', () => {
    const { container } = show({ sources: [source({ state: 'no_backfill' })], active_source_id: 'src-hn', items_by_source: {} })

    expect(panel().getByText('该来源无法回填')).toBeInTheDocument()
    expect(container.querySelector('.source-state-failed')).toBeNull()
  })

  it('本期无新内容只有一句，没有插图', () => {
    const { container } = show({ sources: [source({ state: 'empty' })], active_source_id: 'src-hn', items_by_source: {} })

    expect(panel().getByText('本期无新内容')).toBeInTheDocument()
    expect(container.querySelector('.source-state-failed')).toBeNull()
  })

  // 措辞是第八轮定的「来源名 完整榜单 ↗」；箭头是图标，名字那半边走 Mixed 拆成两段，
  // 所以按类名取这条外链，再核对整条的文字
  it('栏尾是「来源名 完整榜单」，新标签页打开', () => {
    const { container } = show()

    const foot = container.querySelector('.source-foot[target="_blank"]')
    expect(foot).toHaveTextContent('Hacker News 完整榜单')
    expect(foot).toHaveAttribute('href', 'https://news.ycombinator.com/news')
    expect(foot).toHaveAttribute('target', '_blank')
    expect(foot?.getAttribute('rel')).toContain('noopener')
  })

  it('源站地址算不出来时整条收掉', () => {
    const { container } = show({ sources: [source({ home_url: null })], active_source_id: 'src-hn' })

    expect(container.querySelector('.source-foot[target="_blank"]')).toBeNull()
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

describe('按 hash 定位（搜索结果的所在期）', () => {
  // Inertia 自己的 scrollToAnchor 排在一个 setTimeout 里，中文锚点它找不到就滚回顶部（lib/anchors.ts 的注释）；
  // 我们的滚动也排进 setTimeout 才压得过它，所以这里用假时钟：挂载后不滚，时钟走完才滚一次
  beforeEach(() => {
    vi.useFakeTimers()
    Element.prototype.scrollIntoView = vi.fn()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('挂载后在下一个宏任务里把 #item-<id> 那一行滚进视口', () => {
    window.history.replaceState({ page: 'daily' }, '', '/daily/2026-09-08?source=src-hn#item-itm-hn-1')
    const scroll = vi.mocked(Element.prototype.scrollIntoView)

    const { container } = show()
    expect(scroll).not.toHaveBeenCalled()

    vi.runAllTimers()

    expect(scroll).toHaveBeenCalledTimes(1)
    expect(scroll.mock.contexts[0]).toBe(container.querySelector('#item-itm-hn-1'))
  })

  it('旧 source 查询参数定位来源，条目 hash 优先于 source', () => {
    window.history.replaceState({}, '', '/daily/2026-09-08?source=src-gh')
    const { container, unmount } = show()
    vi.runAllTimers()
    expect(vi.mocked(Element.prototype.scrollIntoView).mock.contexts[0]).toBe(container.querySelector('#source-src-gh'))
    unmount()
    vi.mocked(Element.prototype.scrollIntoView).mockClear()
    window.history.replaceState({}, '', '/daily/2026-09-08?source=src-gh#item-itm-hn-1')
    const next = show()
    vi.runAllTimers()
    expect(vi.mocked(Element.prototype.scrollIntoView).mock.contexts[0]).toBe(next.container.querySelector('#item-itm-hn-1'))
  })

  it('重抓后条目锚点已不存在时回到旧链接指定的来源栏首', () => {
    window.history.replaceState({}, '', '/daily/2026-09-08?source=src-gh#item-replaced')
    const { container } = show()
    vi.runAllTimers()
    const fallback = container.querySelector('#item-replaced')
    expect(fallback?.closest('.daily-source')).toBe(container.querySelector('#source-src-gh'))
    expect(vi.mocked(Element.prototype.scrollIntoView).mock.contexts[0]).toBe(fallback)
  })

  it('历史页面已完成初始化时不重新执行锚点定位，由 Inertia 恢复阅读位置', () => {
    window.history.replaceState({ documentScrollPosition: { top: 450, left: 0 } }, '', '/daily/2026-09-08?source=src-gh')
    show()
    vi.runAllTimers()
    expect(Element.prototype.scrollIntoView).not.toHaveBeenCalled()
  })

  it('没有 hash 或找不到元素时什么都不做', () => {
    window.history.replaceState({ page: 'daily' }, '', '/daily/2026-09-08#item-nope')
    const scroll = vi.mocked(Element.prototype.scrollIntoView)

    show()
    vi.runAllTimers()

    expect(scroll).not.toHaveBeenCalled()
  })

  it('卸载后不再滚动', () => {
    window.history.replaceState({ page: 'daily' }, '', '/daily/2026-09-08?source=src-hn#item-itm-hn-1')
    const scroll = vi.mocked(Element.prototype.scrollIntoView)

    const { unmount } = show()
    unmount()
    vi.runAllTimers()

    expect(scroll).not.toHaveBeenCalled()
  })
})

it('缺期只说一次事实，并链接最近可读日刊', () => {
 show({ missing: true, issue: dailyIssue({ state: null, status: '本期未生成' }), latest_daily_key: '2026-09-07' })
 expect(screen.getAllByText('本期未生成')).toHaveLength(1)
 expect(screen.getByRole('link', { name: '阅读最新日刊' })).toHaveAttribute('href', '/daily/2026-09-07')
})

it('管理员补生成保持等待状态并显示实际服务端结果', async () => {
 show({ missing: true, issue: dailyIssue({ state: null, status: '本期未生成' }), backfill_available: true })
 await userEvent.click(screen.getByRole('button', { name: '补生成本期' }))
 expect(screen.getByRole('button', { name: '正在补生成…' })).toBeDisabled()
 const options = router.post.mock.calls[router.post.mock.calls.length - 1][2]
 act(() => { options.onSuccess({ props: { flash: { alert: '这一天已有期' } } }); options.onFinish() })
 expect(screen.getByRole('status')).toHaveTextContent('这一天已有期')
 expect(screen.getByRole('button', { name: '补生成本期' })).toBeEnabled()
})

// PRD 5.10：页面把 favorites 交给 FavoritesProvider，条目行的书签对着它画
it('条目行有书签，已收藏的链接是实心', () => {
  const { unmount } = show()
  expect(screen.getByRole('button', { name: '收藏：Show HN: A terminal log viewer written in Rust' })).not.toHaveAttribute('data-on')
  unmount()

  show({ favorites: ['hash-termlog'] })
  expect(screen.getByRole('button', { name: '取消收藏：Show HN: A terminal log viewer written in Rust' })).toHaveAttribute('data-on')
})

describe('打印（D34）', () => {
  it('使用同一份完整正文，进入和退出打印不会卸载条目或重复来源', () => {
    show({ items_by_source: { 'src-hn': [item()], 'src-gh': [item({ id: 'itm-gh-1', url_hash: 'hash-gh', title: 'openclaw/openclaw' })] } })
    const article = screen.getByText('openclaw/openclaw')
    act(() => { window.dispatchEvent(new Event('beforeprint')) })
    expect(screen.getAllByRole('heading', { level: 2 })).toHaveLength(3)
    expect(screen.getByText('openclaw/openclaw')).toBe(article)
    act(() => { window.dispatchEvent(new Event('afterprint')) })
    expect(screen.getByText('openclaw/openclaw')).toBe(article)
  })

  it('期级事实句（生成中）打印时只印一次', () => {
    show({ issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新' }) })
    act(() => { window.dispatchEvent(new Event('beforeprint')) })
    expect(screen.getAllByText('生成中，约 1 分钟后刷新')).toHaveLength(1)
  })
})
