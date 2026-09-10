import { render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import ItemRow from '@/components/ItemRow'
import { item } from '../support/props'

// 条目行（PRD 5.1「条目结构」）：十条格式一致，元数据行按适配器换内容但只有数字与记号。
// 相对时间要一个确定的「现在」：published_at 2026-09-08T17:12:00Z 在下面这个时钟里是 5h，
// 悬停的绝对时间按 Asia/Shanghai 是 09-09 01:12。

beforeEach(() => {
  vi.useFakeTimers({ shouldAdvanceTime: true })
  vi.setSystemTime(new Date('2026-09-08T22:12:00Z'))
})

afterEach(() => {
  vi.useRealTimers()
})

const hn = () =>
  item({
    meta: { score: 312, comments: 145, comments_url: 'https://news.ycombinator.com/item?id=41000001' },
  })

const gh = () =>
  item({
    id: 'itm-gh-1',
    title: 'openclaw/openclaw',
    url: 'https://github.com/openclaw/openclaw',
    meta: { language: 'Rust', stars: 12_345, stars_today: 312 },
  })

const rss = () =>
  item({
    id: 'itm-had-1',
    title: 'A 3D-printed rotary phone',
    url: 'https://hackaday.com/rotary-phone',
    author: 'Al Williams',
  })

describe('ItemRow 标题与摘要', () => {
  it('标题是标题元素，里面是带下划线的原文外链（R-8.4 新标签页）', () => {
    render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    const heading = screen.getByRole('heading', { level: 2 })
    const link = screen.getByRole('link', { name: 'Show HN: A terminal log viewer written in Rust' })

    expect(heading).toContainElement(link)
    expect(link).toHaveClass('t')
    expect(link).toHaveAttribute('href', 'https://example.com/termlog')
    expect(link).toHaveAttribute('target', '_blank')
    expect(link.getAttribute('rel')).toContain('noopener')
  })

  it('heading 传什么层级就渲染什么', () => {
    render(<ItemRow item={hn()} adapter="hacker_news" rank={1} heading="h4" />)

    expect(screen.getByRole('heading', { level: 4 })).toBeInTheDocument()
  })

  it('序号照传', () => {
    render(<ItemRow item={hn()} adapter="hacker_news" rank={7} />)

    expect(screen.getByText('7')).toHaveClass('item-rank')
  })

  it('有摘要才有摘要行', () => {
    const { container, unmount } = render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)
    expect(container.querySelector('.item-summary')).toBeNull()
    unmount()

    render(<ItemRow item={item({ summary: '一个用 Rust 写的终端日志查看器。' })} adapter="hacker_news" rank={1} />)
    expect(screen.getByText('一个用 Rust 写的终端日志查看器。')).toHaveClass('item-summary')
  })
})

describe('ItemRow 元数据（按适配器）', () => {
  it('HN：分数、评论数链到讨论页、相对时间带绝对时间的悬停', () => {
    render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    expect(screen.getByText('▲ 312')).toBeInTheDocument()

    const comments = screen.getByRole('link', { name: '145' })
    expect(comments).toHaveAttribute('href', 'https://news.ycombinator.com/item?id=41000001')
    expect(comments).toHaveAttribute('target', '_blank')
    expect(comments.getAttribute('rel')).toContain('noopener')

    const age = screen.getByTitle('09-09 01:12')
    expect(age).toHaveTextContent('5h')
  })

  it('HN：没有讨论页地址时评论数不是链接', () => {
    render(<ItemRow item={item({ meta: { score: 312, comments: 145 } })} adapter="hacker_news" rank={1} />)

    expect(screen.getByText('145')).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: '145' })).toBeNull()
  })

  it('GitHub：语言、收成 k 的 star 数、今日新增', () => {
    render(<ItemRow item={gh()} adapter="github_trending" rank={1} />)

    expect(screen.getByText('Rust')).toBeInTheDocument()
    expect(screen.getByText('★ 12.3k')).toBeInTheDocument()
    expect(screen.getByText('+312')).toBeInTheDocument()
    expect(screen.queryByText('▲ 312')).toBeNull()
  })

  it('GitHub：今日新增只有前三名反白成绿徽章', () => {
    const { unmount } = render(<ItemRow item={gh()} adapter="github_trending" rank={3} />)
    expect(screen.getByText('+312').getAttribute('style')).toContain('background: var(--green)')
    unmount()

    render(<ItemRow item={gh()} adapter="github_trending" rank={4} />)
    expect(screen.getByText('+312').getAttribute('style')).not.toContain('var(--green)')
  })

  it('RSS：作者与时间同属元数据，整行一个 Maple 角色', () => {
    render(<ItemRow item={rss()} adapter="rss" rank={1} />)

    expect(screen.getByText('Al Williams').style.fontFamily).toBe('var(--font-data)')
    expect(screen.getByTitle('09-09 01:12')).toHaveTextContent('5h')
    expect(screen.queryByText('Rust')).toBeNull()
  })

  it('没有发布时间就不渲染时间那一段', () => {
    render(<ItemRow item={item({ published_at: null, meta: { score: 312 } })} adapter="hacker_news" rank={1} />)

    expect(screen.getByText('▲ 312')).toBeInTheDocument()
    expect(screen.queryByTitle('09-09 01:12')).toBeNull()
  })
})

describe('ItemRow 推荐理由与兴趣标签', () => {
  it('两个字段为空时都不渲染', () => {
    const { container } = render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    expect(container.querySelector('.item-reason')).toBeNull()
    expect(container.querySelector('.item-tag')).toBeNull()
  })

  it('有值时理由成段、标签成墨色小块', () => {
    const { container } = render(
      <ItemRow item={item({ reason: '与你关注的终端工具相关。', interest_tag: 'AI' })} adapter="hacker_news" rank={1} />,
    )

    expect(screen.getByText('与你关注的终端工具相关。')).toHaveClass('item-reason')
    expect(container.querySelector('.item-tag')).toHaveTextContent('AI')
  })
})

describe('ItemRow 周刊那一版（D19）', () => {
  it('元数据只剩发布时间，不出现 HN / GitHub 那些数字', () => {
    render(<ItemRow item={hn()} adapter="hacker_news" rank={1} variant="weekly" />)

    expect(screen.getByText('09-09 01:12')).toBeInTheDocument()
    expect(screen.queryByText('▲ 312')).toBeNull()
    expect(screen.queryByRole('link', { name: '145' })).toBeNull()
  })

  it('整期同一天发布时（没有 published_at）整行不渲染', () => {
    const { container } = render(
      <ItemRow item={item({ published_at: null })} adapter="ruanyf_weekly" rank={1} variant="weekly" />,
    )

    expect(container.querySelector('.item-body')?.textContent).toBe('Show HN: A terminal log viewer written in Rust')
  })

  it('摘要走周刊那一档行高', () => {
    render(<ItemRow item={item({ summary: '本周的一条。' })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)

    expect(screen.getByText('本周的一条。')).toHaveClass('item-summary--weekly')
  })

  it('不生成推荐理由，也就没有兴趣标签', () => {
    const { container } = render(
      <ItemRow
        item={item({ reason: '不该出现。', interest_tag: 'AI' })}
        adapter="ruanyf_weekly"
        rank={1}
        variant="weekly"
      />,
    )

    expect(container.querySelector('.item-reason')).toBeNull()
    expect(container.querySelector('.item-tag')).toBeNull()
    expect(screen.queryByText('不该出现。')).toBeNull()
  })
})
