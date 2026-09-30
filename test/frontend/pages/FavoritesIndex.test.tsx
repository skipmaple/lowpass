import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import Index, { type FavoritesIndexProps } from '@/pages/Favorites/Index'
import { router } from '../support/inertia'
import { favoriteEntry } from '../support/props'

// 收藏页（PRD 5.10、R-10.6、R-10.7）：行沿用搜索结果行；取消后原地留「已取消收藏」与「恢复」。
// 文案是附录 B 原句。

const TITLE = 'Show HN: A terminal log viewer written in Rust'

function show(overrides: Partial<FavoritesIndexProps> = {}) {
  const props: FavoritesIndexProps = {
    entries: [favoriteEntry()],
    favorites: ['hash-termlog'],
    page: 1,
    pages: 1,
    latest_daily_key: '2026-09-08',
    daily_time: '06:00',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }

  return render(<Index {...props} />)
}

const ok = (body: Record<string, string> = {}, status = 201) => ({ ok: true, status, json: async () => body })

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="tok-123">'
})

afterEach(() => {
  document.head.innerHTML = ''
  vi.unstubAllGlobals()
  router.replaceProp.mockClear()
})

describe('收藏页的行', () => {
  it('页名是 h1「收藏」；一行有刊物签、来源、所在期、标题外链、所在期链接、原文与书签', () => {
    const { container } = show()

    expect(screen.getByRole('heading', { level: 1, name: '收藏' })).toBeInTheDocument()
    expect(document.title).toBe('收藏 · Lowpass')

    const row = container.querySelector('.search-row') as HTMLElement
    const eyebrow = row.querySelector('.search-eyebrow') as HTMLElement
    expect(eyebrow).toHaveTextContent('日刊')
    expect(eyebrow).toHaveTextContent('Hacker News')
    expect(eyebrow).toHaveTextContent('2026年9月8日')

    const title = within(row).getByRole('link', { name: TITLE })
    expect(within(row).getByRole('heading', { level: 2 })).toContainElement(title)
    expect(title).toHaveAttribute('href', 'https://example.com/termlog')
    expect(title).toHaveAttribute('target', '_blank')
    expect(title.getAttribute('rel')).toContain('noopener')
    expect(title).toHaveAttribute('lang', 'en')

    expect(within(row).getByRole('link', { name: /^所在期\s*·\s*2026年9月8日$/ })).toHaveAttribute('href', '/daily/2026-09-08?source=src-hn#item-itm-hn-1')
    expect(within(row).getByRole('link', { name: '原文' })).toHaveAttribute('href', 'https://example.com/termlog')
    expect(within(row).getByRole('button', { name: `取消收藏：${TITLE}` })).toHaveAttribute('data-on')
  })

  it('译文与摘要片段有就显示，没有就没有那一行', () => {
    const { container, unmount } = show()
    expect(container.querySelector('.item-translation')).toBeNull()
    expect(container.querySelector('.search-snippet')).toBeNull()
    unmount()

    const view = show({
      entries: [
        favoriteEntry({ title_zh: 'Show HN：一个用 Rust 写的终端日志查看器' }),
        favoriteEntry({ url_hash: 'hash-ruff', title: 'astral-sh/ruff', url: 'https://github.com/astral-sh/ruff', source_name: 'GitHub Trending', snippet: 'An extremely fast Python linter.', summary_zh: '一个极快的 Python 代码检查工具。' }),
      ],
      favorites: ['hash-termlog', 'hash-ruff'],
    })

    const rows = view.container.querySelectorAll('.search-row')
    // D25 的位置：标题译文紧跟标题，简介译文紧跟简介
    expect(rows[0].querySelector('.search-title')?.nextElementSibling).toHaveTextContent('Show HN：一个用 Rust 写的终端日志查看器')
    expect(rows[0].querySelector('.search-title')?.nextElementSibling).toHaveClass('item-translation')
    expect(rows[1].querySelector('.search-snippet')).toHaveTextContent('An extremely fast Python linter.')
    expect(rows[1].querySelector('.search-snippet')?.nextElementSibling).toHaveTextContent('一个极快的 Python 代码检查工具。')
  })

  it('周刊收藏的刊物签是「周刊」，所在期带周次与板块', () => {
    const { container } = show({
      entries: [favoriteEntry({ publication: 'weekly', source_name: '阮一峰科技爱好者周刊', where: { label: '2026年 · 第 36 周 · 工具', href: '/weekly/2026-W36#issue-366-%E5%B7%A5%E5%85%B7' } })],
    })

    expect(container.querySelector('.search-eyebrow')).toHaveTextContent('周刊')
    expect(screen.getByRole('link', { name: /^所在期\s*·\s*2026年\s*·\s*第 36 周\s*·\s*工具$/ })).toHaveAttribute('href', '/weekly/2026-W36#issue-366-%E5%B7%A5%E5%85%B7')
  })

  // 离开再回来时，历史恢复出来的旧列表里可能还带着已经取消的那一行（R-10.7：离开后不再出现）
  it('不在 favorites 里、这一次停留里也没取消过的行不画', () => {
    const { container } = show({ favorites: [] })

    expect(container.querySelectorAll('.search-row')).toHaveLength(0)
  })
})

describe('取消与恢复（R-10.7、AC-10.4）', () => {
  it('取消后那一行原地留下「已取消收藏」与「恢复」，恢复凭取消时拿到的凭据', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(ok({ undo: 'signed-token' }, 200))
      .mockResolvedValueOnce(ok({ url_hash: 'hash-termlog' }))
    vi.stubGlobal('fetch', fetchMock)
    const { container } = show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))

    expect(container.querySelectorAll('.search-row')).toHaveLength(1)
    expect(screen.getByText('已取消收藏')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: `取消收藏：${TITLE}` })).toBeNull()
    const restore = screen.getByRole('button', { name: '恢复' })
    // 焦点跟到换上来的控件，读屏读到的说明是「已取消收藏」
    expect(restore).toHaveFocus()
    expect(restore).toHaveAccessibleDescription('已取消收藏')
    expect(fetchMock.mock.calls[0][0]).toBe('/favorites/hash-termlog')
    expect(fetchMock.mock.calls[0][1].method).toBe('DELETE')
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', []))

    await userEvent.click(restore)

    const mark = screen.getByRole('button', { name: `取消收藏：${TITLE}` })
    expect(mark).toHaveAttribute('data-on')
    expect(mark).toHaveFocus()
    expect(screen.queryByText('已取消收藏')).toBeNull()
    expect(fetchMock.mock.calls[1][0]).toBe('/favorites')
    expect(fetchMock.mock.calls[1][1].method).toBe('POST')
    expect(fetchMock.mock.calls[1][1].body).toBe(JSON.stringify({ undo: 'signed-token' }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenLastCalledWith('favorites', ['hash-termlog']))
  })

  it('取消没保存上：那一行回到已收藏并提示', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500, json: async () => ({}) }))
    show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))

    expect(await screen.findByText('取消收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toHaveAttribute('data-on')
    expect(screen.queryByText('已取消收藏')).toBeNull()
  })

  it('恢复没保存上：那一行仍是「已取消收藏」，可以再点恢复', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(ok({ undo: 'signed-token' }, 200))
      .mockResolvedValueOnce({ ok: false, status: 500, json: async () => ({}) })
      .mockResolvedValueOnce(ok({ url_hash: 'hash-termlog' }))
    vi.stubGlobal('fetch', fetchMock)
    show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledTimes(1))
    await userEvent.click(screen.getByRole('button', { name: '恢复' }))

    expect(await screen.findByText('收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByText('已取消收藏')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: '恢复' }))
    await waitFor(() => expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toBeInTheDocument())
    expect(fetchMock).toHaveBeenCalledTimes(3)
  })

  // 网慢的时候，读者可能在取消的请求回来之前就点了「恢复」：不丢这一下
  it('取消的请求还没回来就点「恢复」：凭据到手后接着恢复', async () => {
    let settle: (value: unknown) => void = () => undefined
    const fetchMock = vi.fn()
      .mockReturnValueOnce(new Promise((resolve) => { settle = resolve }))
      .mockResolvedValueOnce(ok({ url_hash: 'hash-termlog' }))
    vi.stubGlobal('fetch', fetchMock)
    show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))
    await userEvent.click(screen.getByRole('button', { name: '恢复' }))

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(screen.getByText('已取消收藏')).toBeInTheDocument()

    settle(ok({ undo: 'signed-token' }, 200))

    await waitFor(() => expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toBeInTheDocument())
    expect(fetchMock).toHaveBeenCalledTimes(2)
    expect(fetchMock.mock.calls[1][1].body).toBe(JSON.stringify({ undo: 'signed-token' }))
  })

  // 服务端说这条本来就不在了（204，没有凭据）：没什么可恢复的，这一行直接消失
  it('取消时服务端已经没有这条收藏：行消失', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 204, json: async () => ({}) }))
    const { container } = show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))

    await waitFor(() => expect(container.querySelectorAll('.search-row')).toHaveLength(0))
  })
})

describe('空态与分页', () => {
  // AC-10.10：一句原因加一个动作（附录 B）
  it('没有收藏：「还没有收藏。」与去最新日刊的链接', () => {
    const { container } = show({ entries: [], favorites: [], pages: 0 })

    expect(container.querySelector('.state-line')).toHaveTextContent('还没有收藏。')
    expect(screen.getByRole('link', { name: '阅读最新日刊' })).toHaveAttribute('href', '/daily/2026-09-08')
    expect(container.querySelectorAll('.search-row')).toHaveLength(0)
    expect(screen.queryByRole('navigation', { name: '分页' })).toBeNull()
  })

  it('一期日刊都没有时链接回首页', () => {
    show({ entries: [], favorites: [], pages: 0, latest_daily_key: null })

    expect(screen.getByRole('link', { name: '阅读最新日刊' })).toHaveAttribute('href', '/')
  })

  it('只有一页时没有分页；多页时地址是 /favorites?page=n，第 1 页不写 page', () => {
    const { unmount } = show()
    expect(screen.queryByRole('navigation', { name: '分页' })).toBeNull()
    unmount()

    show({ page: 2, pages: 3 })
    const pager = within(screen.getByRole('navigation', { name: '分页' }))
    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('href', '/favorites')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/favorites?page=3')
    expect(screen.getByRole('navigation', { name: '分页' })).toHaveTextContent('2 / 3')
  })

  // D28：不显示收藏总数
  it('页面上没有收藏总数', () => {
    const { container } = show()

    expect(container.textContent).not.toMatch(/共\s*\d+\s*条|\d+\s*条收藏/)
  })
})
