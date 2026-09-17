import { act, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Show, { type SearchShowProps } from '@/pages/Search/Show'
import { emitRouterEvent, router } from '../support/inertia'
import { searchFilters, searchResult } from '../support/props'

// 搜索页（PRD 5.4、6.2，设计 6.2）：搜索状态由服务端 state 决定，文案是附录 B 原句；
// 筛选、排序、翻页全是地址；点标题或原文先上报 search_click。

function showProps(overrides: Partial<SearchShowProps> = {}): SearchShowProps {
  return {
    q: '',
    truncated: false,
    filters: searchFilters(),
    source_options: [
      { id: 'src-hn', name: 'Hacker News', enabled: true },
      { id: 'src-ruanyf', name: '阮一峰科技爱好者周刊', enabled: false },
    ],
    date_presets: { '7d': { from: '2026-09-05', to: '2026-09-11' }, '30d': { from: '2026-08-13', to: '2026-09-11' } },
    state: 'initial',
    results: [],
    total: 0,
    page: 1,
    pages: 0,
    latest_daily_key: '2026-09-08',
    latest_daily_label: '2026年9月8日',
    daily_time: '06:00',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }
}

function show(overrides: Partial<SearchShowProps> = {}) {
  return render(<Show {...showProps(overrides)} />)
}

const results = (overrides: Partial<SearchShowProps> = {}) =>
  show({ q: 'kuber rust', state: 'results', results: [searchResult()], total: 1, page: 1, pages: 1, ...overrides })

afterEach(() => {
  router.get.mockClear()
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
  window.history.replaceState({}, '', '/')
})

describe('搜索状态', () => {
  it('未搜索：占位句、筛选器、最新日刊入口，没有结果与计数', () => {
    const { container } = show()

    // PRD 6.4 标题层级：页面的 h1 是「搜索」（视觉上隐藏，读屏器能读到），结果标题才是 h2
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('搜索')
    expect(screen.getByRole('searchbox', { name: '搜索' })).toHaveAttribute('placeholder', '搜标题、摘要或来源。拼写不准也可以。')
    // 「最新日刊 · 2026年9月8日」经 Mixed 拆成多个相邻 <span>，jsdom 的可访问名计算会把落在段边界上的
    // 空格吃掉（最新日刊·2026年9月8日），可见渲染与 textContent 都不受影响；用正则容忍空格差异。
    expect(screen.getByRole('link', { name: /^最新日刊\s*·\s*2026年9月8日$/ })).toHaveAttribute('href', '/daily/2026-09-08')
    expect(screen.getByRole('navigation', { name: '刊物' })).toBeInTheDocument()
    expect(container.querySelectorAll('.search-row')).toHaveLength(0)
    expect(container.querySelector('.search-count')).toBeNull()
  })

  it('一期日刊都没有时没有入口', () => {
    show({ latest_daily_key: null, latest_daily_label: null })

    expect(screen.queryByRole('link', { name: /最新日刊/ })).toBeNull()
  })

  it('有结果：计数、结果行；只有一页时不显示分页', () => {
    const { container } = results()

    expect(container.querySelector('.search-count')?.textContent).toContain('1 条结果')
    expect(container.querySelectorAll('.search-row')).toHaveLength(1)
    expect(screen.getByRole('status')).toHaveTextContent('1 条结果')
    expect(screen.queryByRole('navigation', { name: '分页' })).toBeNull()
  })

  it('无结果且有筛选：附录 B 那句带查询词，清除筛选只留 q', () => {
    show({ q: '量子 咖啡机', state: 'empty', filters: searchFilters({ type: 'weekly', sources: ['src-hn'] }) })

    expect(screen.getByText('没有找到「量子 咖啡机」相关内容。试试更短的关键词，或放宽筛选。')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: '清除筛选' })).toHaveAttribute('href', '/search?q=%E9%87%8F%E5%AD%90+%E5%92%96%E5%95%A1%E6%9C%BA')
  })

  it('清除筛选使用未提交的查询词', async () => {
    const user = userEvent.setup()
    show({ q: 'old', state: 'empty', filters: searchFilters({ type: 'daily' }) })

    const input = screen.getByRole('searchbox', { name: '搜索' })
    await user.clear(input)
    await user.type(input, '  rust  ')

    expect(screen.getByRole('link', { name: '清除筛选' })).toHaveAttribute('href', '/search?q=rust')
  })

  it('无结果且没有筛选：修改关键词会聚焦并选中搜索词', async () => {
    const user = userEvent.setup()
    show({ q: '量子咖啡机', state: 'empty' })
    const input = screen.getByRole('searchbox', { name: '搜索' }) as HTMLInputElement

    input.blur()
    await user.click(screen.getByRole('button', { name: '修改关键词' }))

    expect(input).toHaveFocus()
    expect(input.selectionStart).toBe(0)
    expect(input.selectionEnd).toBe('量子咖啡机'.length)
    expect(screen.queryByRole('link', { name: '清除筛选' })).toBeNull()
  })

  it('限流与不可用各一句', () => {
    const { unmount } = show({ q: 'kuber', state: 'limited' })
    expect(screen.getByRole('status')).toHaveTextContent('操作过于频繁')
    unmount()

    show({ q: 'kuber', state: 'unavailable' })
    expect(screen.getByRole('status')).toHaveTextContent('搜索暂不可用')
  })

  it.each([
    ['empty', '没有找到'],
    ['limited', '操作过于频繁'],
    ['unavailable', '搜索暂不可用'],
    ['unsupported', '请输入至少 2 个字母'],
  ] as const)('搜索完成为 %s 时给出对应 live 通知', (state, message) => {
    const { rerender } = show({ q: 'a' })
    act(() => emitRouterEvent('start'))
    expect(screen.getByRole('status')).toHaveTextContent('正在搜索')

    rerender(<Show {...showProps({ q: 'a', state })} />)
    act(() => emitRouterEvent('finish'))

    expect(screen.getByRole('status')).toHaveTextContent(message)
    expect(screen.getByRole('searchbox', { name: '搜索' })).toHaveFocus()
  })

  it('不支持的查询说明约束，修改操作聚焦并选中输入', async () => {
    const user = userEvent.setup()
    show({ q: 'a', state: 'unsupported' })
    const input = screen.getByRole('searchbox', { name: '搜索' }) as HTMLInputElement
    expect(input).toHaveAttribute('aria-invalid', 'true')
    expect(input).toHaveAccessibleDescription(/至少 2 个字母.*C、C\+\+、C#/)
    input.blur()

    await user.click(screen.getByRole('button', { name: '修改关键词' }))

    expect(input).toHaveFocus()
    expect(input.selectionStart).toBe(0)
    expect(input.selectionEnd).toBe(1)
  })

  it.each(['limited', 'unavailable'] as const)('%s 可以保留筛选与当前页重试', async (state) => {
    const user = userEvent.setup()
    show({ q: 'rust', state, filters: searchFilters({ type: 'weekly' }), page: 2 })
    if (state === 'limited') expect(screen.getByRole('status')).toHaveTextContent('1 分钟')

    await user.click(screen.getByRole('button', { name: '重试' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=rust&type=weekly&page=2')

    act(() => emitRouterEvent('start'))
    expect(screen.getByRole('button', { name: '重试' })).toBeDisabled()
    expect(screen.getByRole('button', { name: '搜索' })).toBeDisabled()
    expect(screen.getByRole('status')).not.toHaveClass('sr-only')
  })

  it('超长查询提示已截断', () => {
    show({ q: 'k'.repeat(100), truncated: true, state: 'empty' })

    expect(screen.getByText('已截断到 100 字')).toBeInTheDocument()
  })
})

describe('搜索框', () => {
  it('初次进入自动聚焦；清除按钮清空后把焦点留在输入框', async () => {
    const user = userEvent.setup()
    show({ q: 'old' })
    const input = screen.getByRole('searchbox', { name: '搜索' })

    expect(input).toHaveFocus()
    await user.click(screen.getByRole('button', { name: '清除搜索词' }))

    expect(input).toHaveValue('')
    expect(input).toHaveFocus()
  })

  it('回车提交：Inertia 访问 /search，带上现有筛选，页码归 1', async () => {
    const user = userEvent.setup()
    show({ q: 'old', state: 'empty', filters: searchFilters({ type: 'daily', sort: 'date' }), page: 3 })

    const input = screen.getByRole('searchbox', { name: '搜索' })
    await user.clear(input)
    await user.type(input, 'kuber{Enter}')

    expect(router.get).toHaveBeenCalledWith('/search?q=kuber&type=daily&sort=date')
  })

  it('按钮也提交', async () => {
    const user = userEvent.setup()
    show()

    await user.type(screen.getByRole('searchbox', { name: '搜索' }), '终端')
    await user.click(screen.getByRole('button', { name: '搜索' }))

    expect(router.get).toHaveBeenCalledWith('/search?q=%E7%BB%88%E7%AB%AF')
  })

  it('未提交的查询词用于刊物、来源和日期筛选', async () => {
    const user = userEvent.setup()
    show({ q: 'old', filters: searchFilters({ range: 'custom', from: null, to: null }) })
    const input = screen.getByRole('searchbox', { name: '搜索' })

    await user.clear(input)
    await user.type(input, '  rust  ')

    expect(screen.getByRole('link', { name: '周刊' })).toHaveAttribute('href', '/search?q=rust&type=weekly&range=custom')
    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=rust&source=src-hn&range=custom', {}, { preserveState: true })
    await user.type(screen.getByLabelText('起始日期'), '2026-09-01')
    expect(router.get).toHaveBeenLastCalledWith('/search?q=rust&from=2026-09-01&range=custom', {}, { preserveState: true })
    expect(input).toHaveValue('  rust  ')
  })

  it('普通重渲染保留草稿，服务端查询词变化时同步输入框', async () => {
    const user = userEvent.setup()
    const { rerender } = show({ q: 'first' })
    const input = screen.getByRole('searchbox', { name: '搜索' })

    await user.clear(input)
    await user.type(input, 'draft')
    rerender(<Show {...showProps({ q: 'first', total: 2 })} />)
    expect(input).toHaveValue('draft')

    rerender(<Show {...showProps({ q: 'history' })} />)
    expect(input).toHaveValue('history')
  })

  it('同一查询词的导航地址变化也会同步输入框', async () => {
    const user = userEvent.setup()
    window.history.replaceState({}, '', '/search?q=first&type=daily')
    const { rerender } = show({ q: 'first', filters: searchFilters({ type: 'daily' }) })
    const input = screen.getByRole('searchbox', { name: '搜索' })

    await user.clear(input)
    await user.type(input, 'draft')
    window.history.replaceState({}, '', '/search?q=first&type=weekly')
    rerender(<Show {...showProps({ q: 'first', filters: searchFilters({ type: 'weekly' }) })} />)

    expect(input).toHaveValue('first')
  })

  it('Inertia 访问期间通过 live region 宣告加载状态', () => {
    show()

    act(() => emitRouterEvent('start'))
    expect(screen.getByRole('status')).toHaveTextContent('正在搜索…')
    act(() => emitRouterEvent('finish'))
    expect(screen.getByRole('status')).toBeEmptyDOMElement()
  })
})

describe('结果行', () => {
  it('眉行、命中下划线、所在期与原文', () => {
    const { container } = results()
    const row = container.querySelector('.search-row') as HTMLElement

    expect(row.querySelector('.search-eyebrow')?.textContent).toContain('日刊')
    expect(row.querySelector('.search-eyebrow')?.textContent).toContain('Hacker News')
    expect(Array.from(row.querySelectorAll('.search-title .hit')).map((hit) => hit.textContent)).toEqual(['Kuber', 'Rust'])
    expect(Array.from(row.querySelectorAll('.search-snippet .hit')).map((hit) => hit.textContent)).toEqual(['Kubernetes'])

    // HitText 把每个 run 包成独立的 <span>（下划线要挂在命中的 run 上，D22），命中/非命中 run 相邻时
    // jsdom 的可访问名计算会把落在 run 边界上的空格吃掉（Kubernetes operator inRust）；
    // 可见渲染与上面按 .hit 取 textContent 的断言都不受影响，这里用正则容忍空格差异。
    const title = within(row).getByRole('link', { name: /^Kubernetes\s*operator\s*in\s*Rust$/ })
    expect(title).toHaveAttribute('href', 'https://example.com/k8s-rust')
    expect(title).toHaveAttribute('target', '_blank')
    expect(title).toHaveAttribute('rel', 'noopener noreferrer')
    expect(within(row).getByRole('link', { name: /^所在期\s*·\s*2026年9月8日$/ })).toHaveAttribute('href', '/daily/2026-09-08?source=src-hn#item-itm-hn-1')
    expect(within(row).getByRole('link', { name: '原文' })).toHaveAttribute('href', 'https://example.com/k8s-rust')
  })

  // 日刊的所在期就是那一天，日期与它相同：眉行只写一次；周刊的所在期是「2026年 · 第 36 周 · 工具」，日期另有信息，两个都写
  it('所在期与日期相同时眉行只写一次', () => {
    const daily = results()
    expect(daily.container.querySelector('.search-eyebrow')?.textContent).toBe('日刊Hacker News·2026年9月8日')
    daily.unmount()

    const weekly = results({
      results: [
        searchResult({
          publication: 'weekly',
          source_name: '阮一峰科技爱好者周刊',
          where: { label: '2026年 · 第 36 周 · 工具', href: '/weekly/2026-W36#issue-366-%E5%B7%A5%E5%85%B7' },
          published_label: '2026年9月4日',
        }),
      ],
    })
    expect(weekly.container.querySelector('.search-eyebrow')?.textContent).toBe('周刊阮一峰科技爱好者周刊·2026年 · 第 36 周 · 工具·2026年9月4日')
  })

  it('没有摘要就没有片段行', () => {
    const { container } = results({ results: [searchResult({ snippet_runs: null })] })

    expect(container.querySelector('.search-snippet')).toBeNull()
  })

  // 9.1 search_click：先 fetch(keepalive) 再由浏览器打开；令牌从 meta 读
  it('点标题上报一次点击，带 CSRF 令牌', async () => {
    const fetchSpy = vi.fn().mockResolvedValue(undefined)
    vi.stubGlobal('fetch', fetchSpy)
    document.head.innerHTML = '<meta name="csrf-token" content="tok">'
    const user = userEvent.setup()
    const { container } = results()

    // 正则容忍 HitText run 边界的空格差异（同上「眉行、命中下划线…」一条的注释）
    const title = within(container.querySelector('.search-row') as HTMLElement).getByRole('link', { name: /^Kubernetes\s*operator\s*in\s*Rust$/ })
    title.addEventListener('click', (event) => event.preventDefault())
    await user.click(title)

    expect(fetchSpy).toHaveBeenCalledTimes(1)
    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('/search/clicks')
    expect(init.method).toBe('POST')
    expect(init.keepalive).toBe(true)
    expect((init.headers as Record<string, string>)['X-CSRF-Token']).toBe('tok')
    expect(JSON.parse(init.body as string)).toEqual({ item_id: 'itm-hn-1', rank: 1, q: 'kuber rust' })
  })

  it('所在期直链不上报', async () => {
    const fetchSpy = vi.fn().mockResolvedValue(undefined)
    vi.stubGlobal('fetch', fetchSpy)
    const user = userEvent.setup()
    results()

    // 正则容忍 Mixed run 边界的空格差异（同上「眉行、命中下划线…」一条的注释）
    const where = screen.getByRole('link', { name: /^所在期\s*·\s*2026年9月8日$/ })
    where.addEventListener('click', (event) => event.preventDefault())
    await user.click(where)

    expect(fetchSpy).not.toHaveBeenCalled()
  })
})

describe('排序与分页', () => {
  it('排序分段：当前项 aria-current，另一项换 sort 并回到第 1 页', () => {
    const { container } = results({ page: 2, pages: 3, total: 41 })
    const count = within(container.querySelector('.search-count') as HTMLElement)

    expect(count.getByRole('link', { name: '相关度' })).toHaveAttribute('aria-current', 'true')
    expect(count.getByRole('link', { name: '时间' })).toHaveAttribute('href', '/search?q=kuber+rust&sort=date')
  })

  it('排序使用未提交的查询词并回到第 1 页', async () => {
    const user = userEvent.setup()
    const { container } = results({ page: 2, pages: 3, total: 41 })
    const input = screen.getByRole('searchbox', { name: '搜索' })

    await user.clear(input)
    await user.type(input, '  fresh  ')

    const count = within(container.querySelector('.search-count') as HTMLElement)
    expect(count.getByRole('link', { name: '时间' })).toHaveAttribute('href', '/search?q=fresh&sort=date')
  })

  it('草稿变化时分页先从新查询第 1 页开始，未变化时正常翻页', async () => {
    const user = userEvent.setup()
    results({ page: 2, pages: 3, total: 41 })
    let pager = within(screen.getByRole('navigation', { name: '分页' }))
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/search?q=kuber+rust&page=3')

    const input = screen.getByRole('searchbox', { name: '搜索' })
    await user.clear(input)
    await user.type(input, 'new query')

    pager = within(screen.getByRole('navigation', { name: '分页' }))
    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('href', '/search?q=new+query')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/search?q=new+query')
  })

  it('第 1 页没有上一页，最后一页没有下一页', () => {
    const { unmount } = results({ page: 1, pages: 3, total: 41 })
    let pager = within(screen.getByRole('navigation', { name: '分页' }))
    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('aria-disabled', 'true')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/search?q=kuber+rust&page=2')
    unmount()

    results({ page: 3, pages: 3, total: 41 })
    pager = within(screen.getByRole('navigation', { name: '分页' }))
    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('href', '/search?q=kuber+rust&page=2')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('aria-disabled', 'true')
    expect(screen.getByRole('navigation', { name: '分页' })).toHaveTextContent('3 / 3')
  })
})
