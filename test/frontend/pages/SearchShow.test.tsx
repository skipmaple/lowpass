import { act, fireEvent, render, screen, within } from '@testing-library/react'
import type { ActiveVisit, Page, VisitOptions } from '@inertiajs/core'
import userEvent from '@testing-library/user-event'
import { StrictMode } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Show, { type SearchShowProps } from '@/pages/Search/Show'
import { emitRouterEvent, router, visitRouterEvent } from '../support/inertia'
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
    favorites: [],
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

function filterVisit(): VisitOptions {
  return router.get.mock.calls[router.get.mock.calls.length - 1][2] ?? {}
}

function searchResponse(filters: SearchShowProps['filters']): Page<SearchShowProps> {
  return { component: 'Search/Show', props: { ...showProps({ q: 'kuber', filters }), errors: {} }, url: window.location.pathname + window.location.search, version: null, flash: {}, rescuedProps: [], rememberedState: {} }
}

const results = (overrides: Partial<SearchShowProps> = {}) =>
  show({ q: 'kuber rust', state: 'results', results: [searchResult()], total: 1, page: 1, pages: 1, ...overrides })

afterEach(() => {
  router.get.mockClear()
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
  window.history.replaceState({}, '', '/')
})

describe('原生片段返回搜索结果', () => {
  const url = '/search?q=rust&type=weekly'
  const href = '/weekly/2026-W36#issue-366-tools'
  const firstId = '0000000000000000000000001'
  const originalId = '000000000000000000000000d'
  const first = searchResult({ item_id: firstId, where: { label: '工具', href } })
  const original = searchResult({ item_id: originalId, where: { label: '工具', href } })
  const props = showProps({ q: 'rust', state: 'results', results: [first, original], total: 2 })

  function returnToResult() {
    window.history.replaceState({}, '', `${url}#search-result-${originalId}`)
  }

  it('共用板块 href 时仍恢复原条目，下一 Tab 到该行原文', async () => {
    returnToResult()
    const focus = vi.spyOn(HTMLElement.prototype, 'focus')
    render(<main id="main-content"><Show {...props} /></main>)
    const links = screen.getAllByRole('link', { name: /所在期/ })

    expect(links[1]).toHaveFocus()
    expect(focus).toHaveBeenCalledWith({ preventScroll: true })
    await userEvent.setup().tab()
    expect(within(links[1].closest('article')!).getByRole('link', { name: '原文' })).toHaveFocus()
  })

  it('原条目消失则聚焦 h1，不猜另一个共 href 的结果', () => {
    returnToResult()
    const focus = vi.spyOn(HTMLElement.prototype, 'focus')
    render(<main id="main-content"><Show {...props} results={[first]} /></main>)

    expect(screen.getByRole('heading', { level: 1 })).toHaveFocus()
    expect(focus).toHaveBeenCalledWith({ preventScroll: true })
  })

  it('普通新查询没有片段，仍聚焦输入框', () => {
    window.history.replaceState({}, '', '/search?q=fresh')
    render(<main id="main-content"><Show {...props} q="fresh" /></main>)

    expect(screen.getByRole('searchbox')).toHaveFocus()
  })

  it('StrictMode 纯读取同一片段，不消费返回身份', () => {
    returnToResult()
    render(<StrictMode><main id="main-content"><Show {...props} /></main></StrictMode>)

    expect(screen.getAllByRole('link', { name: /所在期/ })[1]).toHaveFocus()
    expect(window.location.hash).toBe('#search-result-000000000000000000000000d')
  })

  it('main 已有焦点时让路，普通 rerender 不再恢复旧结果', () => {
    returnToResult()
    const main = document.createElement('main')
    main.id = 'main-content'
    const input = document.createElement('input')
    const container = document.createElement('div')
    main.append(input, container)
    document.body.append(main)
    input.focus()
    const { rerender, unmount } = render(<Show {...props} />, { container })
    expect(input).toHaveFocus()

    const filter = screen.getByRole('button', { name: 'Hacker News' })
    filter.focus()
    rerender(<Show {...props} total={3} />)
    expect(filter).toHaveFocus()
    unmount()
    main.remove()
  })

  it('收藏写回仅同步 hash 时，未提交草稿和焦点都保留', async () => {
    window.history.replaceState({}, '', url)
    const { rerender } = render(<Show {...props} />)
    const input = screen.getByRole('searchbox')
    const user = userEvent.setup()
    await user.clear(input)
    await user.type(input, 'unsubmitted draft')

    returnToResult()
    rerender(<Show {...props} favorites={['hash-k8s-rust']} />)

    expect(input).toHaveValue('unsubmitted draft')
    expect(input).toHaveFocus()
  })

  it('普通点击所在期只给当前搜索地址写原条目的稳定片段', () => {
    window.history.replaceState({}, '', url)
    render(<main id="main-content"><Show {...props} /></main>)
    fireEvent.click(screen.getAllByRole('link', { name: /所在期/ })[1])

    expect(window.location.pathname + window.location.search + window.location.hash).toBe('/search?q=rust&type=weekly#search-result-000000000000000000000000d')
  })

  it.each([{ ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { altKey: true }, { button: 1 }])('修饰键或非左键点击所在期不改地址 %j', (click) => {
    window.history.replaceState({}, '', url)
    render(<main id="main-content"><Show {...props} /></main>)
    // 浏览器默认的新窗口动作不属于本测试；在 React 处理事件后拦住 jsdom 导航。
    window.addEventListener('click', (event) => event.preventDefault(), { once: true })
    fireEvent.click(screen.getAllByRole('link', { name: /所在期/ })[1], click)

    expect(window.location.hash).toBe('')
  })
})

describe('搜索导航的加载提示', () => {
  it('已有结果时用加载提示替换旧计数，结果和排序仍留在原处', () => {
    const { container } = results()
    const count = container.querySelector('.search-count')!
    const row = container.querySelector('.search-row')!
    expect(count).toHaveTextContent('1 条结果')

    act(() => emitRouterEvent('start'))
    expect(screen.getByRole('status')).toHaveTextContent('正在搜索…')
    expect(screen.getByRole('status')).toHaveClass('sr-only')
    expect(count).toHaveTextContent('正在搜索…')
    expect(count).not.toHaveTextContent('1 条结果')
    expect(container.querySelector('.search-row')).toBe(row)
    expect(within(count as HTMLElement).getByRole('link', { name: '时间' })).toBeInTheDocument()

    act(() => emitRouterEvent('finish'))
    expect(count).toHaveTextContent('1 条结果')
  })

  it('进入所在期时保留原结果计数，只有搜索访问才宣告加载', () => {
    results()
    act(() => emitRouterEvent('start', visitRouterEvent('start', { url: '/weekly/2026-W36' })))

    expect(screen.getByRole('status')).toHaveTextContent('1 条结果')
    expect(screen.getByRole('status')).toHaveClass('sr-only')
    expect(screen.getByRole('button', { name: '搜索' })).toBeEnabled()

    act(() => emitRouterEvent('start'))
    expect(screen.getByRole('status')).toHaveTextContent('正在搜索…')
    expect(screen.getByRole('button', { name: '搜索' })).toBeDisabled()
    act(() => emitRouterEvent('finish'))
    expect(screen.getByRole('status')).toHaveTextContent('1 条结果')
  })
})

describe('搜索状态', () => {
  it('未搜索：占位句、筛选器、最新日刊入口，没有结果与计数', () => {
    const { container } = show()

    // PRD 6.4 标题层级：页面的 h1 是「搜索」（视觉上隐藏，读屏器能读到），结果标题才是 h2
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('搜索')
    expect(screen.getByRole('searchbox', { name: '搜索' })).toHaveAttribute('placeholder', '搜标题、摘要或来源。拼写不准也可以。')
    expect(screen.getByRole('searchbox', { name: '搜索' })).toHaveAccessibleDescription('搜标题、摘要或来源。拼写不准也可以。')
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
    expect(input).toHaveAccessibleDescription(/请输入至少 2 个字母.*搜标题、摘要或来源/)
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
    expect(router.get).toHaveBeenLastCalledWith('/search?q=rust&source=src-hn&range=custom', {}, expect.objectContaining({ preserveState: true }))
    // 日期框失焦才提交（打字过程中不发请求）
    await user.type(screen.getByLabelText('起始日期'), '2026-09-01')
    await user.tab()
    expect(router.get).toHaveBeenLastCalledWith('/search?q=rust&source=src-hn&from=2026-09-01&range=custom', {}, expect.objectContaining({ preserveState: true }))
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
  it('已有日刊译文紧跟相应原文，没有理由也能显示', () => {
    const result = searchResult({ title_zh: '用 Rust 编写的控制器', summary_zh: '使用 Rust 构建的控制器' })
    const { container } = show({ state: 'results', q: 'rust', results: [result], total: 1, pages: 1 })
    const row = container.querySelector('.search-row') as HTMLElement
    const children = Array.from(row.children)
    const translations = row.querySelectorAll('.item-translation')
    expect(Array.from(translations).map((element) => element.textContent)).toEqual(['用 Rust 编写的控制器', '使用 Rust 构建的控制器'])
    expect(children.indexOf(translations[0])).toBe(children.indexOf(row.querySelector('.search-title') as Element) + 1)
    expect(children.indexOf(translations[1])).toBe(children.indexOf(row.querySelector('.search-snippet') as Element) + 1)
    expect(translations[0].closest('a')).toBeNull()
  })

  it('周刊或缺少原文片段时不显示不匹配的译文', () => {
    const weekly = searchResult({ publication: 'weekly', title_zh: '不应出现', summary_zh: '不应出现' })
    const withoutSnippet = searchResult({ item_id: 'no-summary', snippet_runs: null, summary_zh: '没有原文的译文' })
    const { container } = show({ state: 'results', q: 'rust', results: [weekly, withoutSnippet], total: 2, pages: 1 })
    expect(container.querySelectorAll('.item-translation')).toHaveLength(0)
  })
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

  // 所在期集中在可操作的链接里；不同的发布时间仍保留在来源旁。
  it('所在期只显示在链接中，独立发布时间仍保留', () => {
    const daily = results()
    expect(daily.container.querySelector('.search-eyebrow')?.textContent).toBe('日刊Hacker News')
    expect(screen.getByRole('link', { name: /^所在期\s*·\s*2026年9月8日$/ })).toBeInTheDocument()
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
    expect(weekly.container.querySelector('.search-eyebrow')?.textContent).toBe('周刊阮一峰科技爱好者周刊·2026年9月4日')
    expect(screen.getByRole('link', { name: /^所在期\s*·\s*2026年\s*·\s*第 36 周\s*·\s*工具$/ })).toBeInTheDocument()
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
  it('先点时间再选来源，排序尚未返回时也保留最新排序条件', async () => {
    const user = userEvent.setup()
    results({ q: 'kuber', page: 2, pages: 3, total: 41 })
    // 旧分段的测试替身只是链接；拦住它的浏览器默认导航，仍执行真实控件的 React 点击处理。
    window.addEventListener('click', (event) => event.preventDefault(), { once: true })
    await user.click(screen.getByRole('link', { name: '时间' }))
    await user.click(screen.getByRole('button', { name: 'Hacker News' }))

    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&source=src-hn&sort=date', {}, expect.objectContaining({ preserveState: true }))
    expect(router.get).toHaveBeenCalledTimes(2)
    expect(screen.getByRole('link', { name: '时间' })).toHaveAttribute('aria-current', 'true')
    expect(screen.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/search?q=kuber&source=src-hn&sort=date')
  })

  it('来源还在待确认时，排序和分页链接保留该来源并从第一页开始', async () => {
    results({ q: 'kuber', page: 2, pages: 3, total: 41 })
    await userEvent.setup().click(screen.getByRole('button', { name: 'Hacker News' }))

    expect(screen.getByRole('link', { name: '时间' })).toHaveAttribute('href', '/search?q=kuber&source=src-hn&sort=date')
    expect(screen.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/search?q=kuber&source=src-hn')
    expect(screen.getByRole('status')).toHaveTextContent('41 条结果')
    expect(screen.getByRole('link', { name: '原文' })).toHaveAttribute('href', 'https://example.com/k8s-rust')
  })

  it('日期还在待确认时，排序、分页与查询提交使用同一对日期', () => {
    results({ q: 'kuber', filters: searchFilters({ range: 'custom', from: '2026-08-01' }), page: 2, pages: 3, total: 41 })
    const to = screen.getByLabelText('结束日期')
    fireEvent.change(to, { target: { value: '2026-09-08' } })
    fireEvent.blur(to)

    expect(screen.getByRole('link', { name: '时间' })).toHaveAttribute('href', '/search?q=kuber&from=2026-08-01&to=2026-09-08&range=custom&sort=date')
    expect(screen.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/search?q=kuber&from=2026-08-01&to=2026-09-08&range=custom')
    fireEvent.submit(screen.getByRole('search'))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-08-01&to=2026-09-08&range=custom')
  })

  it('筛选访问失败后，搜索重试保留待确认条件并从第一页开始', async () => {
    const user = userEvent.setup()
    show({ q: 'kuber', state: 'unavailable', filters: searchFilters({ type: 'weekly' }), page: 2 })
    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    const pending = filterVisit()
    act(() => emitRouterEvent('start'))
    act(() => {
      pending.onFinish?.(visitRouterEvent('finish').detail.visit as ActiveVisit)
      emitRouterEvent('finish')
    })
    await user.click(screen.getByRole('button', { name: '重试' }))

    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&type=weekly&source=src-hn')
  })

  it('服务端确认与外部导航会同步更新整页导航目标，不能残留旧的待确认来源', async () => {
    const user = userEvent.setup()
    const initial = { q: 'kuber', state: 'results' as const, results: [searchResult()], total: 41, page: 2, pages: 3 }
    const { rerender } = show(initial)
    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    expect(screen.getByRole('link', { name: '时间' })).toHaveAttribute('href', '/search?q=kuber&source=src-hn&sort=date')
    const pending = filterVisit()
    act(() => {
      pending.onSuccess?.(searchResponse(searchFilters()))
      pending.onFinish?.(visitRouterEvent('finish').detail.visit as ActiveVisit)
    })
    expect(screen.getByRole('link', { name: '时间' })).toHaveAttribute('href', '/search?q=kuber&sort=date')

    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    act(() => filterVisit().onFinish?.(visitRouterEvent('finish').detail.visit as ActiveVisit))
    window.history.replaceState({}, '', '/search?q=kuber&type=weekly')
    rerender(<Show {...showProps({ ...initial, filters: searchFilters({ type: 'weekly' }) })} />)
    expect(screen.getByRole('link', { name: '时间' })).toHaveAttribute('href', '/search?q=kuber&type=weekly&sort=date')
    fireEvent.submit(screen.getByRole('search'))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&type=weekly')
  })

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

// PRD 5.10：书签在底行右端，名字用没有高亮切分的整句标题
describe('结果行的书签', () => {
  it('结果行有书签，状态照 favorites', () => {
    const { container, unmount } = results()
    const mark = within(container.querySelector('.search-links') as HTMLElement).getByRole('button', { name: '收藏：Kubernetes operator in Rust' })
    expect(mark).toHaveClass('favorite-button', 'search-mark')
    unmount()

    results({ favorites: ['hash-k8s-rust'] })
    expect(screen.getByRole('button', { name: '取消收藏：Kubernetes operator in Rust' })).toHaveAttribute('data-on')
  })
})
