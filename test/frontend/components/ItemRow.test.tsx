import { act, fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import ItemRow from '@/components/ItemRow'
import { FavoritesProvider } from '@/lib/favorites'
import type { ItemMeta } from '@/types/lowpass'
import { setPageProps } from '../support/inertia'
import { item } from '../support/props'

// 条目行（PRD 5.1「条目结构」）：十条格式一致，元数据按适配器区分信息、收藏与时间来源。
// 相对时间要一个确定的「现在」：published_at 2026-09-08T17:12:00Z 在下面这个时钟里是 5 小时前，
// 绝对时间按 Asia/Shanghai 是 2026-09-09 01:12。

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

  it('带标签的英文标题保留每个原字符、链接可读名与地址，换文重渲染不遗留旧标题', () => {
    const title = '  Tailwind\tLabs is  joining Shopify  '
    const { container, rerender } = render(<ItemRow item={item({ title, interest_tag: '前端开发' })} adapter="hacker_news" rank={1} />)
    const link = screen.getByRole('link', { name: 'Tailwind\tLabs is joining Shopify' })

    expect(link.textContent).toBe(title)
    expect(link).toHaveAttribute('href', 'https://example.com/termlog')
    expect(link.closest('h2')?.nextElementSibling).toHaveTextContent('前端开发')
    expect(link.closest('h2')).not.toHaveTextContent('前端开发')

    const changed = item({ title: 'Hunting the Wild Vibrotruck', interest_tag: '电子机械与自动化' })
    rerender(<ItemRow item={changed} adapter="rss" rank={1} />)
    rerender(<ItemRow item={changed} adapter="rss" rank={1} />)
    expect(screen.getByRole('link', { name: changed.title }).textContent).toBe(changed.title)
    expect(container.querySelector('.item-tag')).toHaveTextContent(changed.interest_tag!)
    expect(screen.queryByRole('link', { name: 'Tailwind\tLabs is joining Shopify' })).toBeNull()
  })

  it('单 token、含汉字、无标签与周刊的标题保留直接原文节点', () => {
    const { rerender } = render(<ItemRow item={gh()} adapter="github_trending" rank={1} />)
    const unchanged = [
      { title: 'TauricResearch/TradingAgents', interest_tag: 'AI' },
      { title: '用 Rust 制作终端工具', interest_tag: '终端工具' },
      { title: 'Tailwind Labs is joining Shopify', interest_tag: null },
    ]
    for (const props of unchanged) {
      rerender(<ItemRow item={item(props)} adapter="hacker_news" rank={1} />)
      const link = screen.getByRole('link', { name: props.title })
      expect(link.childNodes).toHaveLength(1)
      expect(link.firstChild?.nodeType).toBe(Node.TEXT_NODE)
      expect(link.textContent).toBe(props.title)
    }

    rerender(<ItemRow item={item({ title: 'Hunting the Wild Vibrotruck', interest_tag: '电子机械与自动化' })} adapter="rss" rank={1} variant="weekly" />)
    const weekly = screen.getByRole('link', { name: 'Hunting the Wild Vibrotruck' })
    expect(weekly.childNodes).toHaveLength(1)
    expect(weekly.firstChild?.nodeType).toBe(Node.TEXT_NODE)
    expect(screen.queryByText('电子机械与自动化')).toBeNull()
  })
})

describe('ItemRow 元数据（按适配器）', () => {
  it('页面停留时刷新相对时间，并在重新显示页面时立即校准', () => {
    render(<ItemRow item={item({ published_at: '2026-09-08T22:11:00Z' })} adapter="hacker_news" rank={1} />)
    const age = screen.getByText('1 分钟前提交').closest('time')!

    act(() => vi.advanceTimersByTime(60_000))
    expect(age).toHaveTextContent('2 分钟前提交')

    act(() => {
      vi.setSystemTime(new Date('2026-09-09T00:12:00Z'))
      document.dispatchEvent(new Event('visibilitychange'))
    })
    expect(age).toHaveTextContent('2 小时前提交')
    expect(age).toHaveAttribute('datetime', '2026-09-08T22:11:00Z')
  })

  it('多条时间共用时钟，隐藏后恢复立即更新，离开页面时释放时钟', () => {
    const interval = vi.spyOn(globalThis, 'setInterval')
    const clear = vi.spyOn(globalThis, 'clearInterval')
    const visibility = vi.spyOn(document, 'visibilityState', 'get')
    visibility.mockReturnValue('visible')
    const { unmount } = render(<>
      <ItemRow item={item({ id: 'first', published_at: '2026-09-08T22:11:00Z' })} adapter="hacker_news" rank={1} />
      <ItemRow item={item({ id: 'second', published_at: '2026-09-08T22:10:00Z' })} adapter="hacker_news" rank={2} />
    </>)
    const ages = screen.getAllByTitle(/09-09 06:1/)
    expect(interval).toHaveBeenCalledTimes(1)

    visibility.mockReturnValue('hidden')
    act(() => vi.advanceTimersByTime(120_000))
    expect(ages[0]).toHaveTextContent('1 分钟前提交')
    visibility.mockReturnValue('visible')
    act(() => document.dispatchEvent(new Event('visibilitychange')))
    expect(ages[0]).toHaveTextContent('3 分钟前提交')
    expect(ages[1]).toHaveTextContent('4 分钟前提交')

    unmount()
    expect(clear).toHaveBeenCalledTimes(1)
    visibility.mockRestore()
    interval.mockRestore()
    clear.mockRestore()
  })

  it('HN：分数、评论数链到讨论页、相对时间带绝对时间的悬停', () => {
    render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    expect(screen.getByText('312')).toBeInTheDocument()
    expect(screen.getByRole('img', { name: '得分' })).toBeInTheDocument()

    const comments = screen.getByRole('link', { name: '145 条评论，在 Hacker News 打开' })
    expect(comments).toHaveAttribute('href', 'https://news.ycombinator.com/item?id=41000001')
    expect(comments).toHaveAttribute('target', '_blank')
    expect(comments.getAttribute('rel')).toContain('noopener')

    const age = screen.getByText('5 小时前提交').closest('time')!
    expect(age).toHaveAttribute('title', '提交到 Hacker News：2026-09-09 01:12（Asia/Shanghai）')
    expect(age).toHaveAttribute('aria-label', '5 小时前提交，提交到 Hacker News：2026-09-09 01:12（Asia/Shanghai）')
    expect(age).toHaveAttribute('datetime', '2026-09-08T17:12:00Z')
    expect(age.querySelector('svg')).toBeNull()
  })

  it('评论图标响应悬停与键盘聚焦，离开后恢复，不改变讨论链接', async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)
    const comments = screen.getByRole('link', { name: '145 条评论，在 Hacker News 打开' })
    const path = comments.querySelector('path')!
    const initial = path.getAttribute('d')

    await user.hover(comments)
    act(() => vi.advanceTimersByTime(2000))
    expect(path.getAttribute('d')).not.toBe(initial)
    await user.unhover(comments)
    act(() => vi.advanceTimersByTime(2000))
    expect(path).toHaveAttribute('d', initial!)

    await user.tab()
    await user.tab()
    expect(comments).toHaveFocus()
    act(() => vi.advanceTimersByTime(2000))
    expect(path.getAttribute('d')).not.toBe(initial)
    await user.hover(comments)
    await user.unhover(comments)
    act(() => vi.advanceTimersByTime(2000))
    expect(path.getAttribute('d')).not.toBe(initial)
    await user.tab()
    act(() => vi.advanceTimersByTime(2000))
    expect(path).toHaveAttribute('d', initial!)
    expect(comments).toHaveAttribute('href', 'https://news.ycombinator.com/item?id=41000001')
  })

  it('HN：没有讨论页地址时评论数不是链接', () => {
    render(<ItemRow item={item({ meta: { score: 312, comments: 145 } })} adapter="hacker_news" rank={1} />)

    expect(screen.getByText('145')).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /145 条评论/ })).toBeNull()
    expect(screen.getByRole('img', { name: '评论' })).toBeInTheDocument()
  })

  it('GitHub：语言、收成 k 的 star 数、今日新增', () => {
    render(<ItemRow item={gh()} adapter="github_trending" rank={1} />)

    expect(screen.getByText('Rust')).toHaveClass('item-meta-text')
    expect(screen.getByText('12.3k')).toBeInTheDocument()
    expect(screen.getByRole('img', { name: 'Star' })).toBeInTheDocument()
    expect(screen.getByText('+312')).toBeInTheDocument()
    expect(screen.queryByRole('img', { name: '得分' })).toBeNull()
  })

  it('GitHub：今日新增只有前三名反白成绿徽章', () => {
    const { unmount } = render(<ItemRow item={gh()} adapter="github_trending" rank={3} />)
    expect(screen.getByText('+312').getAttribute('style')).toContain('background: var(--green)')
    unmount()

    render(<ItemRow item={gh()} adapter="github_trending" rank={4} />)
    expect(screen.getByText('+312').getAttribute('style')).not.toContain('var(--green)')
  })

  it('RSS：作者与发布时间同属元数据', () => {
    render(<ItemRow item={rss()} adapter="rss" rank={1} />)

    expect(screen.getByText('Al Williams').style.fontFamily).toBe('var(--font-data)')
    expect(screen.getByText('Al Williams')).toHaveClass('item-meta-text')
    const age = screen.getByText('5 小时前发布').closest('time')!
    expect(age).toHaveAttribute('title', '发布：2026-09-09 01:12（Asia/Shanghai）')
    expect(screen.queryByText('Rust')).toBeNull()
  })

  it('RSS 缺少源发布时间时明确标为收录时间', () => {
    render(<ItemRow item={item({ meta: { time_from_fetch: true } })} adapter="rss" rank={1} />)

    const age = screen.getByText('5 小时前收录').closest('time')!
    expect(age).toHaveAttribute('aria-label', '5 小时前收录，收录：2026-09-09 01:12（Asia/Shanghai）')
    expect(age).toHaveAttribute('datetime', '2026-09-08T17:12:00Z')
    expect(screen.queryByText(/前发布/)).toBeNull()
  })

  it('整天年龄继续按当前时钟计算，绝对时间的年份也按上海时区', () => {
    vi.setSystemTime(new Date('2027-01-03T16:30:00Z'))
    render(<ItemRow item={item({ published_at: '2026-12-31T16:30:00Z' })} adapter="hacker_news" rank={1} />)

    const age = screen.getByText('3 天前提交').closest('time')!
    expect(age).toHaveAttribute('title', '提交到 Hacker News：2027-01-01 00:30（Asia/Shanghai）')
  })

  it('没有发布时间就不渲染时间那一段', () => {
    render(<ItemRow item={item({ published_at: null, meta: { score: 312 } })} adapter="hacker_news" rank={1} />)

    expect(screen.getByText('312')).toBeInTheDocument()
    expect(screen.queryByText(/前提交/)).toBeNull()
  })

  it('无法解析的发布时间不留下图标或占位', () => {
    const { container } = render(<ItemRow item={item({ published_at: 'not a date', meta: { score: 312 } })} adapter="hacker_news" rank={1} />)

    expect(screen.queryByText('NaNd')).toBeNull()
    expect(screen.getByText('312')).toBeInTheDocument()
    expect(screen.queryByRole('img', { name: '发布时间' })).toBeNull()
    expect(container.querySelector('.item-meta')?.children).toHaveLength(1)
  })
})

describe('ItemRow 推荐理由与兴趣标签', () => {
  it('两个字段为空时都不渲染', () => {
    const { container } = render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    expect(container.querySelector('.item-reason')).toBeNull()
    expect(container.querySelector('.item-tag')).toBeNull()
  })

  it('有值时理由成段；标签紧跟在标题元素后面，不进标题的可读名称', () => {
    const { container } = render(
      <ItemRow item={item({ reason: '与你关注的终端工具相关。', interest_tag: 'AI' })} adapter="hacker_news" rank={1} />,
    )

    expect(screen.getByText('与你关注的终端工具相关。').closest('.item-reason')).toBeInTheDocument()
    const heading = screen.getByRole('heading', { level: 2 })
    expect(container.querySelector('.item-heading')).not.toHaveClass('item-heading--tagged')
    expect(heading.nextElementSibling).toHaveClass('item-tag')
    expect(heading).not.toHaveTextContent('AI')
    expect(container.querySelector('.item-tag .item-interest-chip')).toHaveClass('chip-outline')
  })
})

describe('ItemRow 标题译文（D25）', () => {
  const translated = () => ({ ...hn(), title_zh: 'Show HN：一个用 Rust 写的终端日志查看器' })

  it('紧跟标题、在元数据之前；只是文字，不是第二个链接', () => {
    const { container } = render(<ItemRow item={translated()} adapter="hacker_news" rank={1} />)

    const translation = container.querySelector('.item-translation')
    expect(translation).toHaveTextContent('Show HN：一个用 Rust 写的终端日志查看器')
    expect(container.querySelector('.item-heading')?.nextElementSibling).toBe(translation)
    expect(translation?.nextElementSibling).toHaveClass('item-meta')
    expect(translation?.querySelector('a')).toBeNull()
    expect(screen.getAllByRole('link').map((link) => link.getAttribute('href'))).toEqual([
      'https://example.com/termlog',
      'https://news.ycombinator.com/item?id=41000001',
    ])
  })

  // 设计 skill：译文里的中文走文楷，夹着的产品名与项目名跟原标题一样走 Newsreader
  it('按字符段分配字体：中文段文楷，拉丁段 Newsreader', () => {
    const { container } = render(<ItemRow item={translated()} adapter="hacker_news" rank={1} />)

    const runs = Array.from(container.querySelectorAll<HTMLElement>('.item-translation span span'))
    expect(runs.find((run) => run.textContent?.includes('终端日志查看器'))?.style.fontFamily).toBe('var(--font-cjk)')
    expect(runs.find((run) => run.textContent?.includes('Rust'))?.style.fontFamily).toBe('var(--font-latin)')
  })

  it('Hackaday（RSS 日刊源）的译文同样紧跟标题', () => {
    const { container } = render(<ItemRow item={{ ...rss(), title_zh: '一部 3D 打印的旋转拨号电话' }} adapter="rss" rank={1} />)

    const translation = container.querySelector('.item-translation')
    expect(translation).toHaveTextContent('一部 3D 打印的旋转拨号电话')
    expect(container.querySelector('.item-heading')?.nextElementSibling).toBe(translation)
  })

  // GitHub Trending 的标题是仓库名，译的是简介：译文跟在英文简介后面、元数据之前
  it('GitHub Trending 的简介译文紧跟英文简介', () => {
    const { container } = render(
      <ItemRow item={{ ...gh(), summary: 'A tiny CLI tool', summary_zh: '一个用 Rust 写的命令行小工具' }} adapter="github_trending" rank={1} />,
    )

    const summary = screen.getByText('A tiny CLI tool')
    const translation = container.querySelector('.item-translation')
    expect(translation).toHaveTextContent('一个用 Rust 写的命令行小工具')
    expect(summary.nextElementSibling).toBe(translation)
    expect(translation?.nextElementSibling).toHaveClass('item-meta')
    expect(container.querySelectorAll('.item-translation')).toHaveLength(1)
  })

  it('没有译文就没有这一行', () => {
    const { container } = render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    expect(container.querySelector('.item-translation')).toBeNull()
  })

  it('周刊那一版不渲染译文', () => {
    const { container } = render(
      <ItemRow item={{ ...translated(), summary: '本周的一条。', summary_zh: '不该出现。' }} adapter="ruanyf_weekly" rank={1} variant="weekly" />,
    )

    expect(container.querySelector('.item-translation')).toBeNull()
    expect(screen.queryByText('不该出现。')).toBeNull()
  })
})

describe('ItemRow 周刊那一版（D19）', () => {
  it('元数据只剩发布时间，不出现 HN / GitHub 那些数字', () => {
    render(<ItemRow item={hn()} adapter="hacker_news" rank={1} variant="weekly" />)

    expect(screen.getByText('09-09 01:12')).toBeInTheDocument()
    expect(screen.queryByRole('img', { name: '得分' })).toBeNull()
    expect(screen.queryByRole('link', { name: /145 条评论/ })).toBeNull()
  })

  it('整期同一天发布时（没有 published_at）整行不渲染', () => {
    const { container } = render(
      <ItemRow item={item({ published_at: null })} adapter="ruanyf_weekly" rank={1} variant="weekly" />,
    )

    expect(container.querySelector('.item-body')?.textContent).toBe('Show HN: A terminal log viewer written in Rust')
  })

  it('没有独立正文的旧条目仍展示摘要，并使用周刊正文排版', () => {
    const { container } = render(<ItemRow item={item({ summary: '本周的一条。' })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)

    expect(container.querySelector('.item-content--weekly')).toHaveTextContent('本周的一条。')
  })

  it('有完整正文时优先展示全文，不回退到截断摘要', () => {
    const content = '这是完整正文，结尾必须保留。'
    const weeklyItem = item({ summary: '这是截断摘要…', content })

    const { container } = render(<ItemRow item={weeklyItem} adapter="ruanyf_weekly" rank={1} variant="weekly" />)

    expect(container.querySelector('.item-content--weekly')).toHaveTextContent(content)
    expect(screen.queryByText('这是截断摘要…')).toBeNull()
  })

  // 页面是 zh-CN：英文标题与摘要要标 lang="en"，读屏才会换英文语音；中文标题不标
  it('英文标题与摘要标 lang="en"', () => {
    render(<ItemRow item={item({ summary: 'A fast log viewer.' })} adapter="hacker_news" rank={1} />)

    expect(screen.getByRole('link', { name: 'Show HN: A terminal log viewer written in Rust' })).toHaveAttribute('lang', 'en')
    expect(screen.getByText('A fast log viewer.')).toHaveAttribute('lang', 'en')
  })

  it('中文标题不标 lang', () => {
    render(<ItemRow item={item({ title: '人生的容错率' })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)

    expect(screen.getByRole('link', { name: '人生的容错率' })).not.toHaveAttribute('lang')
  })

  // SummaryCleaner.content 一行一段：详情页一段一个 <p>，不压成一整块
  it('周刊正文按行分段', () => {
    const { container } = render(<ItemRow item={item({ content: '第一段。\n第二段 OpenClaw。\n第三段。' })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)

    const paragraphs = Array.from(container.querySelectorAll('.item-content--weekly > p')).map((p) => p.textContent)
    expect(paragraphs).toEqual(['第一段。', '第二段 OpenClaw。', '第三段。'])
  })

  it('使用独立展示尺寸为原图占位，未知或非法尺寸不伪造宽高', () => {
    render(
      <ItemRow
        item={item({
          title: '周刊配图',
          meta: { image_urls: ['https://cdn.example.com/known.png', 'https://cdn.example.com/unknown.png', 'https://cdn.example.com/invalid.png'] },
          image_dimensions: {
            'https://cdn.example.com/known.png': { width: 1200, height: 800 },
            'https://cdn.example.com/invalid.png': { width: 0, height: 800 },
          },
        })}
        adapter="ruanyf_weekly"
        rank={1}
        variant="weekly"
      />,
    )
    const images = screen.getAllByRole('img', { name: /周刊配图配图/ })
    expect(images[0]).toHaveAttribute('width', '1200')
    expect(images[0]).toHaveAttribute('height', '800')
    expect(images[1]).not.toHaveAttribute('width')
    expect(images[2]).not.toHaveAttribute('width')
  })

  it('配图在原文段落之间，图后的上图说明保持在图后', () => {
    const meta = { image_urls: ['https://cdn.example.com/earbuds.webp'], image_positions: [1] }
    const { container } = render(
      <ItemRow item={item({ title: '摄像头耳机', content: '无线耳机带有微型摄像头。\n上图中，小凸起就是摄像头。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />,
    )
    const paragraphs = [...container.querySelectorAll('.item-content--weekly > p')]
    const image = screen.getByRole('img', { name: '摄像头耳机配图' })

    expect(paragraphs.map((p) => p.textContent)).toEqual(['无线耳机带有微型摄像头。', '上图中，小凸起就是摄像头。'])
    expect(paragraphs[0].compareDocumentPosition(image) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
    expect(image.compareDocumentPosition(paragraphs[1]) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
  })

  it('仅强调经验证的正文段落，并保持图片与文字的先后顺序', () => {
    const { container } = render(
      <ItemRow item={item({ content: '介绍。\n（1）标题。\n说明。', meta: { image_urls: ['https://cdn.example.com/1.webp'], image_positions: [1], emphasis_positions: [1] } })} adapter="ruanyf_weekly" rank={1} variant="weekly" />,
    )
    const content = container.querySelector('.item-content--weekly')!
    expect([...content.children].map((node) => node.matches('.item-media') ? '图片' : node.textContent)).toEqual(['介绍。', '图片', '（1）标题。', '说明。'])
    expect(content.querySelectorAll('strong')).toHaveLength(1)
    expect(content.querySelector('strong')).toHaveTextContent('（1）标题。')
  })

  it.each([[0, 7], [-1], [1, 1], [1, 0], [0, undefined], Array(1), ['1'], [NaN], '1', null])('不可信的强调位置 %j 不会改变正文的展示', (positions) => {
    const meta = { emphasis_positions: positions } as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '正文。\n说明。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(container.querySelector('strong')).toBeNull()
    expect(container.querySelector('.item-content--weekly')).toHaveTextContent('正文。说明。')
  })

  it('只有摘要的记录不使用正文强调位置', () => {
    const { container } = render(<ItemRow item={item({ content: null, summary: '摘要。', meta: { emphasis_positions: [0] } })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(container.querySelector('strong')).toBeNull()
    expect(container.querySelector('.item-content--weekly')).toHaveTextContent('摘要。')
  })

  it('引用用语义区块呈现，去掉标记并保留分段和图文顺序', () => {
    const meta = { image_urls: ['https://cdn.example.com/1.webp'], image_positions: [1], quote_ranges: [[1, 4]] } as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '引言。\n> 第一段。\n>\n> 第二段。\n正文。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const content = container.querySelector('.item-content--weekly')!
    expect([...content.children].map((node) => node.matches('.item-media') ? '图片' : node.tagName)).toEqual(['P', '图片', 'BLOCKQUOTE', 'P'])
    expect([...content.querySelectorAll('blockquote p')].map((node) => node.textContent)).toEqual(['第一段。', '第二段。'])
  })

  it('正文中的来源链接保留原句、可键盘访问并支持引用段', () => {
    const meta = { quote_ranges: [[1, 2]], reference_links: [[0, 3, 5, 'https://example.com/a'], [1, 4, 6, 'https://example.com/b']] } as unknown as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '🙂 看站点。\n> 查看代码。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const content = container.querySelector('.item-content--weekly')!
    expect(content.textContent).toBe('🙂 看站点。查看代码。')
    const links = content.querySelectorAll('a')
    expect([...links].map((a) => [a.textContent, a.getAttribute('href')])).toEqual([['站点', 'https://example.com/a'], ['代码', 'https://example.com/b']])
    expect(links[1].closest('blockquote')).not.toBeNull()
    expect(links[0]).toHaveAttribute('target', '_blank')
    expect(links[0]).toHaveAttribute('rel', 'noopener noreferrer')
  })

  it('历史图文位置、引用与正文链接同时存在时各自保持原文顺序', () => {
    const meta = {
      image_urls: ['https://cdn.example.com/1.webp', 'https://cdn.example.com/2.webp', 'https://cdn.example.com/3.webp'],
      image_positions: [1, 4, 4], quote_ranges: [[1, 3]],
      reference_links: [[3, 2, 4, 'https://example.com/demo']],
    } as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '开场。\n> 引用一。\n> 引用二。\n查看演示。\n结尾。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const content = container.querySelector('.item-content--weekly')!
    expect([...content.children].map((node) => node.matches('.item-media') ? `图片${node.querySelectorAll('img').length}` : node.tagName)).toEqual(['P', '图片1', 'BLOCKQUOTE', 'P', '图片2', 'P'])
    expect(content.querySelector('blockquote')).toHaveTextContent('引用一。引用二。')
    expect(content.querySelector('.weekly-reference')).toHaveTextContent('演示')
  })

  it('短链接后的中文闭合标点与链接组成不换行的排版单元', () => {
    const meta = { reference_links: [[0, 2, 4, 'https://example.com/code']] } as unknown as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '（看代码），接下来。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const group = container.querySelector('.weekly-reference-group')!
    expect(group.textContent).toBe('代码），')
    expect(group.querySelector('a')).toHaveTextContent('代码')
    expect(container.querySelector('.item-content--weekly')).toHaveTextContent('（看代码），接下来。')
  })

  it('短链接前的括号不留在上一行', () => {
    const meta = { reference_links: [[0, 1, 3, 'https://example.com/code']] } as unknown as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '（代码）', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(container.querySelector('.weekly-reference-group')).toHaveTextContent('（代码）')
    expect(container.querySelector('.weekly-reference-group a')).toHaveTextContent('代码')
  })

  it('同段落重复的链接名带上不同上下文，便于读屏区分', () => {
    const meta = { reference_links: [[0, 1, 3, 'https://example.com/a'], [0, 4, 6, 'https://example.com/b']] } as unknown as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '甲代码乙代码', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const labels = [...container.querySelectorAll('.weekly-reference')].map((link) => link.getAttribute('aria-label'))
    expect(labels).toHaveLength(2)
    expect(labels[0]).not.toBe(labels[1])
  })

  it.each([
    [[0, 0, 2, 'javascript:alert(1)']], [[0, 0, 9, 'https://example.com/']],
    [[0, 1, 2, 'https://example.com/'], [0, 0, 2, 'https://example.com/']],
    [[0, 0, 2, 'https://user:pass@example.com/']],
  ])('不可信的正文链接 %j 退回纯文字', (...links) => {
    const meta = { reference_links: links } as unknown as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '正文', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(container.querySelector('.item-content--weekly a')).toBeNull()
    expect(container.querySelector('.item-content--weekly')).toHaveTextContent('正文')
  })

  it.each([{ ranges: [[0, 5]] }, { ranges: [[1, 1]] }, { ranges: [[1, 3], [2, 4]] }, { ranges: [[1, 3.5]] }, { ranges: [[1, '3']] }, { ranges: [[0, 3]] }, { ranges: [[1, 4], [0, 1]] }])('不可信的引用位置 $ranges 回退为原正文', ({ ranges }) => {
    const meta = { quote_ranges: ranges } as unknown as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '引言。\n> 第一段。\n>\n> 第二段。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(container.querySelector('blockquote')).toBeNull()
    expect(container.querySelector('.item-content--weekly')).toHaveTextContent('引言。> 第一段。>> 第二段。')
  })

  it('图片落在引用内部时整体回退，避免改变图文位置', () => {
    const meta = { image_urls: ['https://cdn.example.com/1.webp'], image_positions: [2], quote_ranges: [[1, 4]] } as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '引言。\n> 第一段。\n>\n> 第二段。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(container.querySelector('blockquote')).toBeNull()
    expect(container.querySelector('.item-content--weekly img')).toBeInTheDocument()
  })

  it('嵌套引用或强调位置冲突时保留原文', () => {
    const nested = render(<ItemRow item={item({ content: '> > 嵌套引用', meta: { quote_ranges: [[0, 1]] } })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(nested.container.querySelector('blockquote')).toBeNull()
    nested.unmount()
    const overlap = render(<ItemRow item={item({ content: '> 引用', meta: { quote_ranges: [[0, 1]], emphasis_positions: [0] } })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(overlap.container.querySelector('blockquote')).toBeNull()
    expect(overlap.container.querySelector('strong')).toHaveTextContent('> 引用')
  })

  it('同段落边界的配图同行，末尾图和全条目编号都保持原顺序', () => {
    const { container } = render(
      <ItemRow
        item={item({ title: '图文', content: '介绍。\n说明。', meta: { image_urls: ['https://cdn.example.com/1.webp', 'https://cdn.example.com/2.webp', 'https://cdn.example.com/3.webp'], image_positions: [0, 0, 2] } })}
        adapter="ruanyf_weekly" rank={1} variant="weekly"
      />,
    )
    const content = container.querySelector('.item-content--weekly')!
    expect([...content.children].map((node) => node.matches('.item-media') ? `图片${node.querySelectorAll('img').length}` : node.textContent)).toEqual(['图片2', '介绍。', '说明。', '图片1'])
    expect(content.children[0]).toHaveClass('item-media--multiple')
    expect(screen.getAllByRole('img').map((image) => image.getAttribute('alt'))).toEqual(['图文配图 1', '图文配图 2', '图文配图 3'])
  })

  it.each([undefined, null, {}, '1', [], [-1], [3], [1.5], ['1'], [null], [undefined], [NaN], [Infinity], Array(1), [0, 1]])('不可靠的图片位置 %j 完整回退到全文后配图', (positions) => {
    const meta = { image_urls: ['https://cdn.example.com/1.webp'], image_positions: positions } as ItemMeta
    const { container } = render(<ItemRow item={item({ content: '介绍。\n说明。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const content = container.querySelector('.item-content--weekly')!
    const media = container.querySelector('.item-media')!

    expect(content.querySelector('img')).toBeNull()
    expect(content.nextElementSibling).toBe(media)
    expect(content.textContent).toBe('介绍。说明。')
    expect(media.querySelector('img')).toHaveAttribute('src', 'https://cdn.example.com/1.webp')
  })

  it.each([
    { image_urls: ['https://cdn.example.com/1.webp', 'https://cdn.example.com/2.webp'], image_positions: [2, 0] },
    { image_urls: ['invalid', 'https://cdn.example.com/2.webp'], image_positions: [0, 1] },
    { image_urls: ['https://cdn.example.com/1.webp', 'https://cdn.example.com/1.webp'], image_positions: [0, 1] },
  ])('原始图片列表或位置无法完整对应时不部分穿插', (meta) => {
    const { container } = render(<ItemRow item={item({ content: '介绍。\n说明。', meta })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const content = container.querySelector('.item-content--weekly')!
    expect(content.querySelector('img')).toBeNull()
    expect(content.nextElementSibling).toHaveClass('item-media')
    expect(screen.getAllByRole('img')).toHaveLength(meta.image_urls.filter((url) => url.startsWith('https://')).length)
  })

  it('只有摘要的旧记录忽略新位置字段', () => {
    const { container } = render(<ItemRow item={item({ content: null, summary: '旧摘要。', meta: { image_urls: ['https://cdn.example.com/1.webp'], image_positions: [0] } })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(container.querySelector('.item-content--weekly')!.nextElementSibling).toHaveClass('item-media')
  })

  it('段间配图保留天然尺寸，失败后只收起对应图片并保留全文', () => {
    const { container } = render(
      <ItemRow
        item={item({ title: '图文', content: '介绍。\n说明。', meta: { image_urls: ['https://cdn.example.com/1.webp', 'https://cdn.example.com/2.webp'], image_positions: [0, 1] }, image_dimensions: { 'https://cdn.example.com/2.webp': { width: 1200, height: 800 } } })}
        adapter="ruanyf_weekly" rank={1} variant="weekly"
      />,
    )
    const second = screen.getByRole('img', { name: '图文配图 2' })
    expect(second).toHaveAttribute('width', '1200')
    expect(second).toHaveAttribute('height', '800')
    fireEvent.error(screen.getByRole('img', { name: '图文配图 1' }))
    expect(screen.getAllByRole('img')).toEqual([second])
    expect(container.querySelectorAll('.item-media')).toHaveLength(1)
    fireEvent.error(second)
    expect(container.querySelector('.item-media')).toBeNull()
    expect(container.querySelector('.item-content--weekly')).toHaveTextContent('介绍。说明。')
  })

  it('已知尺寸的配图加载时标示预留区域，完成后移除边界且不影响其他图片', () => {
    const urls = ['https://cdn.example.com/1.webp', 'https://cdn.example.com/2.webp']
    render(<ItemRow item={item({ title: '图文', meta: { image_urls: urls }, image_dimensions: { [urls[0]]: { width: 1200, height: 800 }, [urls[1]]: { width: 600, height: 400 } } })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const [first, second] = screen.getAllByRole('img', { name: /图文配图/ })
    expect(first.parentElement).toHaveClass('item-media-frame--loading')
    expect(second.parentElement).toHaveClass('item-media-frame--loading')
    fireEvent.load(first)
    expect(first.parentElement).not.toHaveClass('item-media-frame--loading')
    expect(second.parentElement).toHaveClass('item-media-frame--loading')
    fireEvent.error(second)
    expect(screen.getAllByRole('img', { name: /图文配图/ })).toEqual([first])
  })

  it('同一位置重新出现先前的图片时，按新图片的加载状态显示边界', () => {
    const urls = ['https://cdn.example.com/a.webp', 'https://cdn.example.com/b.webp']
    const dimensions = Object.fromEntries(urls.map((url) => [url, { width: 1200, height: 800 }]))
    const row = (url: string) => <ItemRow item={item({ title: '图文', meta: { image_urls: [url] }, image_dimensions: dimensions })} adapter="ruanyf_weekly" rank={1} variant="weekly" />
    const { rerender } = render(row(urls[0]))
    fireEvent.load(screen.getByRole('img', { name: '图文配图' }))
    rerender(row(urls[1]))
    rerender(row(urls[0]))
    expect(screen.getByRole('img', { name: '图文配图' }).parentElement).toHaveClass('item-media-frame--loading')
  })

  it('按原顺序展示条目对应的图片，并为外链图片保护来源页面', () => {
    const { container } = render(
      <ItemRow
        item={item({ title: '美国公路的奇特建筑', meta: { image_urls: ['https://cdn.example.com/one.webp', 'https://cdn.example.com/two.webp'] } })}
        adapter="ruanyf_weekly"
        rank={1}
        variant="weekly"
      />,
    )

    const images = screen.getAllByRole('img', { name: /美国公路的奇特建筑配图/ })
    expect(images.map((image) => image.getAttribute('src'))).toEqual([
      'https://cdn.example.com/one.webp',
      'https://cdn.example.com/two.webp',
    ])
    expect(images[0]).toHaveAttribute('loading', 'lazy')
    expect(images[0]).toHaveAttribute('decoding', 'async')
    expect(images[0]).toHaveAttribute('referrerpolicy', 'no-referrer')
    expect(container.querySelector('.item-media')).toHaveClass('item-media--multiple')
  })

  it('单图使用按内容收缩的媒体版式', () => {
    const { container } = render(
      <ItemRow
        item={item({ title: '封面', meta: { image_urls: ['https://cdn.example.com/cover.webp'] } })}
        adapter="ruanyf_weekly"
        rank={1}
        variant="weekly"
      />,
    )

    expect(container.querySelector('.item-media')).toHaveClass('item-media--single')
  })

  it('周刊配图提供独立的原图入口，失败后不残留失效入口', () => {
    const url = 'https://cdn.example.com/detail.webp'
    render(<ItemRow item={item({ title: '细节图', meta: { image_urls: [url] } })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    const link = screen.getByRole('link', { name: '查看细节图配图的原图（新标签页）' })
    expect(link).toHaveAttribute('href', url)
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', 'noopener noreferrer')
    fireEvent.error(screen.getByRole('img', { name: '细节图配图' }))
    expect(screen.queryByRole('link', { name: '查看细节图配图的原图（新标签页）' })).toBeNull()
  })

  it('图片加载失败时移除破图，全部失败后收起媒体区域', () => {
    const { container } = render(
      <ItemRow
        item={item({ title: '封面', meta: { image_urls: ['https://cdn.example.com/broken.webp'] } })}
        adapter="ruanyf_weekly"
        rank={1}
        variant="weekly"
      />,
    )

    fireEvent.error(screen.getByRole('img', { name: '封面配图' }))

    expect(container.querySelector('.item-media')).toBeNull()
  })

  it('日刊条目不渲染周刊图片区域', () => {
    const { container } = render(
      <ItemRow item={item({ meta: { image_urls: ['https://cdn.example.com/one.webp'] } })} adapter="hacker_news" rank={1} />,
    )

    expect(container.querySelector('.item-media')).toBeNull()
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

describe('锚点', () => {
  // 搜索结果的所在期链接落到 #item-<id>（设计 6.3）
  it('条目行的 id 是 item-<id>', () => {
    const { container } = render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    expect(container.querySelector('article')).toHaveAttribute('id', 'item-itm-hn-1')
  })
})

describe('ItemRow 阅读页不提供重生成入口', () => {
  it.each([true, false])('日刊展示已有推荐，管理员或读者都没有「重生成」（admin=%s）', (admin) => {
    setPageProps({ current_user: { display_name: 'Drew', avatar_url: null, email: 'd@example.com', admin }, flash: {}, errors: {} })
    render(<ItemRow item={item({ reason: '与你关注的终端工具相关。', interest_tag: 'AI' })} adapter="hacker_news" rank={1} />)

    expect(screen.getByText('与你关注的终端工具相关。').closest('.item-reason')).toBeInTheDocument()
    expect(screen.getByText('AI')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: '重生成' })).toBeNull()
  })

  it('周刊条目永远没有「重生成」', () => {
    setPageProps({ current_user: { display_name: 'Drew', avatar_url: null, email: null, admin: true }, flash: {}, errors: {} })
    render(<ItemRow item={item({ id: 'it-3' })} adapter="ruanyf_weekly" rank={1} variant="weekly" />)
    expect(screen.queryByRole('button', { name: '重生成' })).toBeNull()
  })
})

describe('ItemRow 书签（PRD 5.10）', () => {
  const TITLE = 'Show HN: A terminal log viewer written in Rust'

  it('日刊纯图标收藏跟随评论、位于时间前，可读操作名同步收藏状态', () => {
    const { container, unmount } = render(
      <FavoritesProvider favorites={[]}>
        <ItemRow item={hn()} adapter="hacker_news" rank={1} />
      </FavoritesProvider>,
    )
    const mark = screen.getByRole('button', { name: `收藏：${TITLE}` })
    expect(mark).toHaveClass('favorite-button', 'item-save')
    expect(mark.textContent).toBe('')
    expect(mark).not.toHaveAttribute('data-on')
    expect(mark.querySelector('.favorite-line')).toHaveAttribute('aria-hidden', 'true')
    expect(mark.querySelector('.favorite-ink')).toHaveAttribute('aria-hidden', 'true')
    expect(mark.closest('.item-meta')).not.toBeNull()
    expect(mark.previousElementSibling).toBe(screen.getByRole('link', { name: '145 条评论，在 Hacker News 打开' }))
    expect(mark.nextElementSibling).toHaveTextContent('5 小时前提交')
    expect(container.querySelectorAll('.favorite-button')).toHaveLength(1)
    unmount()

    render(
      <FavoritesProvider favorites={['hash-termlog']}>
        <ItemRow item={hn()} adapter="hacker_news" rank={1} />
      </FavoritesProvider>,
    )
    const savedMark = screen.getByRole('button', { name: `取消收藏：${TITLE}` })
    expect(savedMark).toHaveAttribute('data-on')
    expect(savedMark.textContent).toBe('')
  })

  it('周刊纯图标书签紧随标题，长文阅读前即可操作', () => {
    const { container } = render(
      <FavoritesProvider favorites={[]}>
        <ItemRow item={item({ title: '人生的容错率' })} adapter="ruanyf_weekly" rank={1} variant="weekly" heading="h4" />
      </FavoritesProvider>,
    )

    const mark = screen.getByRole('button', { name: '收藏：人生的容错率' })
    expect(mark).toHaveClass('item-mark')
    expect(mark.textContent).toBe('')
    expect(container.querySelector('.item-title')?.nextElementSibling).toBe(mark)
    expect(container.querySelector('.item-heading')?.contains(mark)).toBe(true)
  })

  it('日刊键盘依次到标题、评论和收藏；空格收藏保持焦点与同一按钮', async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue({ ok: true, status: 201, json: async () => ({ url_hash: 'hash-termlog' }) } as Response)
    try {
      render(<FavoritesProvider favorites={[]}><ItemRow item={hn()} adapter="hacker_news" rank={1} /></FavoritesProvider>)

      await user.tab()
      expect(screen.getByRole('link', { name: TITLE })).toHaveFocus()
      await user.tab()
      expect(screen.getByRole('link', { name: '145 条评论，在 Hacker News 打开' })).toHaveFocus()
      await user.tab()
      const mark = screen.getByRole('button', { name: `收藏：${TITLE}` })
      expect(mark).toHaveFocus()
      await user.keyboard(' ')

      expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toBe(mark)
      expect(mark).toHaveFocus()
      expect(mark).toHaveAttribute('data-on')
      expect(mark.textContent).toBe('')
      expect(fetchMock).toHaveBeenCalledTimes(1)
    } finally {
      fetchMock.mockRestore()
    }
  })

  it('没有 FavoritesProvider 时条目行里没有书签', () => {
    const { container } = render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)

    expect(container.querySelector('.favorite-button')).toBeNull()
  })
})

it('标题链接带域名（打印时印在标题后），去掉 www.', () => {
  render(<ItemRow item={item({ url: 'https://www.example.com/termlog' })} adapter="hacker_news" rank={1} />)

  expect(screen.getByRole('link', { name: 'Show HN: A terminal log viewer written in Rust' })).toHaveAttribute('data-host', 'example.com')
})
