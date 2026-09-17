import { render, screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import Show, { type WeeklyShowProps } from '@/pages/Weekly/Show'
import { item, weeklyGroup, weeklyIssue, weeklySection } from '../support/props'

// 周刊详情（PRD 5.2、R-2.5 到 R-2.7）：每个源一节——反白横带、板块锚点目录、按板块分节的条目。
// 阮一峰按原文板块分节，RSS 周刊源没有板块。

function show(overrides: Partial<WeeklyShowProps> = {}) {
  const props: WeeklyShowProps = {
    issue: weeklyIssue(),
    sections: [weeklySection()],
    daily_time: '06:00',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }

  return render(<Show {...props} />)
}

describe('周刊期头', () => {
  it('周次是 h1，年份与日期范围在右侧', () => {
    render(<Show issue={weeklyIssue()} sections={[]} daily_time="06:00" latest_weekly_key="2026-W36" />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('第 36 周')
    expect(screen.getByText('2026')).toBeInTheDocument()
    expect(screen.getByText('8月31日 至 9月6日')).toBeInTheDocument()
  })

  it('前后期按周期键拼地址，归档指向 /weekly', () => {
    show({ issue: weeklyIssue({ next_key: '2026-W37' }) })

    for (const link of screen.getAllByRole('link', { name: '前一期' })) {
      expect(link).toHaveAttribute('href', '/weekly/2026-W35')
    }
    for (const link of screen.getAllByRole('link', { name: '后一期' })) {
      expect(link).toHaveAttribute('href', '/weekly/2026-W37')
    }
    for (const link of screen.getAllByRole('link', { name: '归档' })) {
      expect(link).toHaveAttribute('href', '/weekly')
    }
  })

  // R-2.7 那一周没有期：期头照常，正文只有服务端定稿的那一句
  it('那一周没有期时正文只有「本周无内容」', () => {
    const { container } = render(
      <Show
        issue={weeklyIssue({ state: null, status: '本周无内容', published_at: null })}
        sections={[]}
        daily_time="06:00"
        latest_weekly_key="2026-W36"
      />,
    )

    expect(container.querySelector('.state-line')).toHaveTextContent('本周无内容')
    expect(container.querySelector('.source-band')).toBeNull()
  })
})

describe('源节头（反白横带）', () => {
  it('源名是 h2，右端是该源自己的期号与主题', () => {
    const { container } = show()

    expect(screen.getByRole('heading', { level: 2 })).toHaveTextContent('阮一峰科技爱好者周刊')
    expect(container.querySelector('.source-band-issue')).toHaveTextContent('第 366 期 · 人生的容错率')
  })

  it('有期号写「原文」，链到那一期的 Markdown，新标签页打开', () => {
    show()

    const original = screen.getByRole('link', { name: '原文' })
    expect(original).toHaveAttribute('href', 'https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md')
    expect(original).toHaveAttribute('target', '_blank')
    expect(original.getAttribute('rel')).toContain('noopener')
  })

  // RSS 周刊源没有期号，回到的是源站，措辞跟着换
  it('没有期号写「来源」', () => {
    show({
      sections: [
        weeklySection({
          source: { id: 'src-feed', name: 'Some Weekly', adapter: 'rss', home_url: 'https://example.com/' },
          issue_no: null,
          issue_title: null,
          issue_label: null,
          original_url: 'https://example.com/',
        }),
      ],
    })

    expect(screen.getByRole('link', { name: '来源' })).toHaveAttribute('href', 'https://example.com/')
    expect(screen.queryByRole('link', { name: '原文' })).toBeNull()
  })

  it('feed 地址算不出落点时整条外链收掉', () => {
    show({ sections: [weeklySection({ original_url: null })] })

    expect(screen.queryByRole('link', { name: '原文' })).toBeNull()
    expect(screen.queryByRole('link', { name: '来源' })).toBeNull()
  })
})

describe('板块与锚点', () => {
  const sections = [
    weeklySection({
      groups: [
        weeklyGroup({ name: '科技动态', anchor: 'src-ruanyf-1', items: [item({ id: 'a', title: '一条科技动态' })] }),
        weeklyGroup({ name: '文章', anchor: 'src-ruanyf-2', items: [item({ id: 'b', title: '一篇文章' })] }),
      ],
    }),
  ]

  it('每个板块一个锚点小块，指向自己的落点', () => {
    const { container } = show({ sections })

    const anchors = within(container.querySelector('.anchors') as HTMLElement).getAllByRole('link')
    expect(anchors.map((a) => [a.textContent, a.getAttribute('href')])).toEqual([
      ['科技动态', '#src-ruanyf-1'],
      ['文章', '#src-ruanyf-2'],
    ])
  })

  it('板块名是 h3，落点 id 与锚点对得上', () => {
    const { container } = show({ sections })

    const heads = screen.getAllByRole('heading', { level: 3 })
    expect(heads.map((h) => h.textContent)).toEqual(['科技动态', '文章'])
    expect(container.querySelector('#src-ruanyf-1')).toContainElement(heads[0])
  })

  it('板块下的条目降到 h4', () => {
    show({ sections })

    expect(screen.getByRole('heading', { level: 4, name: '一条科技动态' })).toBeInTheDocument()
  })

  // R-2.6 RSS 周刊源没有板块：直接接条目，也就没有锚点目录，条目回到 h3
  it('没有板块的源不排锚点目录，条目是 h3', () => {
    const { container } = show({
      sections: [
        weeklySection({
          source: { id: 'src-feed', name: 'Some Weekly', adapter: 'rss', home_url: 'https://example.com/' },
          groups: [weeklyGroup({ name: null, anchor: 'src-feed-1', items: [item({ id: 'c', title: '一条 RSS 周刊' })] })],
        }),
      ],
    })

    expect(container.querySelector('.anchors')).toBeNull()
    expect(screen.getByRole('heading', { level: 3, name: '一条 RSS 周刊' })).toBeInTheDocument()
  })
})

describe('降级（R-2.3）', () => {
  const degraded = weeklySection({
    degraded: true,
    groups: [weeklyGroup({ name: null, anchor: 'src-ruanyf-1', items: [item({ id: 'stub', title: '第 366 期' })] })],
  })

  it('整节只剩附录 B 那句加一条原文链接', () => {
    const { container } = show({ sections: [degraded] })

    expect(container.querySelector('.state-line')).toHaveTextContent('本期解析失败，已保留原文链接')

    const original = container.querySelector('.source-foot')
    expect(original).toHaveTextContent('第 366 期')
    expect(original).toHaveAttribute('href', 'https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md')
    expect(original).toHaveAttribute('target', '_blank')
  })

  it('降级时不排板块，也不排条目', () => {
    const { container } = show({ sections: [degraded] })

    expect(container.querySelector('.anchors')).toBeNull()
    expect(container.querySelectorAll('.item-row')).toHaveLength(0)
  })

  // 源节头照常在：读者得知道这是哪个源哪一期出的问题
  it('降级时源节头还在', () => {
    const { container } = show({ sections: [degraded] })

    expect(container.querySelector('.source-band')).toHaveTextContent('阮一峰科技爱好者周刊')
  })
})

describe('板块与锚点', () => {
  const sections = [
    weeklySection({
      groups: [
        weeklyGroup({ name: '科技动态', anchor: 'src-ruanyf-1', items: [item({ id: 'a', title: '一条科技动态' })] }),
        weeklyGroup({ name: '文章', anchor: 'src-ruanyf-2', items: [item({ id: 'b', title: '一篇文章' })] }),
      ],
    }),
  ]

  it('每个板块一个锚点小块，指向自己的落点', () => {
    const { container } = show({ sections })

    const anchors = within(container.querySelector('.anchors') as HTMLElement).getAllByRole('link')
    expect(anchors.map((a) => [a.textContent, a.getAttribute('href')])).toEqual([
      ['科技动态', '#src-ruanyf-1'],
      ['文章', '#src-ruanyf-2'],
    ])
  })

  it('板块名是 h3，落点 id 与锚点对得上', () => {
    const { container } = show({ sections })

    const heads = screen.getAllByRole('heading', { level: 3 })
    expect(heads.map((h) => h.textContent)).toEqual(['科技动态', '文章'])
    expect(container.querySelector('#src-ruanyf-1')).toContainElement(heads[0])
  })

  it('板块下的条目降到 h4', () => {
    show({ sections })

    expect(screen.getByRole('heading', { level: 4, name: '一条科技动态' })).toBeInTheDocument()
  })

  // R-2.6 RSS 周刊源没有板块：直接接条目，也就没有锚点目录，条目回到 h3
  it('没有板块的源不排锚点目录，条目是 h3', () => {
    const { container } = show({
      sections: [
        weeklySection({
          source: { id: 'src-feed', name: 'Some Weekly', adapter: 'rss', home_url: 'https://example.com/' },
          groups: [weeklyGroup({ name: null, anchor: 'src-feed-1', items: [item({ id: 'c', title: '一条 RSS 周刊' })] })],
        }),
      ],
    })

    expect(container.querySelector('.anchors')).toBeNull()
    expect(screen.getByRole('heading', { level: 3, name: '一条 RSS 周刊' })).toBeInTheDocument()
  })

  // 中文锚点：DOM id 与目录 href 都是百分号编码的形式，跟地址栏里的 location.hash 原样相等
  it('中文板块的落点与目录用编码后的锚点', () => {
    const { container } = show({
      sections: [weeklySection({ groups: [weeklyGroup({ name: '文章', anchor: 'issue-366-文章', items: [item({ id: 'b', title: '一篇文章' })] })] })],
    })

    const encoded = encodeURIComponent('issue-366-文章')
    expect(within(container.querySelector('.anchors') as HTMLElement).getByRole('link', { name: '文章' })).toHaveAttribute('href', `#${encoded}`)
    expect(document.getElementById(encoded)).toContainElement(screen.getByRole('heading', { level: 3, name: '文章' }))
  })

  // RSS 源没有板块：搜索结果的所在期落到这一节的头上（Item#anchor 给的是 source-<源 id>）
  it('没有板块的节把锚点挂在源节头上', () => {
    show({
      sections: [
        weeklySection({
          source: { id: 'src-feed', name: '命令行周报', adapter: 'rss', home_url: 'https://w.example/' },
          issue_no: null,
          issue_title: null,
          issue_label: null,
          groups: [weeklyGroup({ name: null, anchor: 'source-src-feed', items: [item({ id: 'c', title: '一条 RSS 周刊' })] })],
        }),
      ],
    })

    const band = document.getElementById('source-src-feed')
    expect(band).toHaveClass('source-band')
    expect(band).toHaveTextContent('命令行周报')
  })

  it('降级的节也把锚点挂在源节头上', () => {
    show({
      sections: [weeklySection({ degraded: true, groups: [weeklyGroup({ name: null, anchor: 'source-src-ruanyf', items: [item({ id: 'stub', title: '第 366 期' })] })] })],
    })

    expect(document.getElementById('source-src-ruanyf')).toHaveClass('source-band')
  })

  it('有板块的节的源节头没有锚点', () => {
    show()

    expect(document.querySelector('.source-band')).not.toHaveAttribute('id')
  })
})

describe('按 hash 定位', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    Element.prototype.scrollIntoView = vi.fn()
  })

  afterEach(() => {
    vi.useRealTimers()
    window.history.replaceState({}, '', '/weekly/2026-W36')
  })

  // 周刊锚点带中文，地址里是百分号编码；id 也是编码过的，原样就找得到。滚动排在 setTimeout 里（见 lib/anchors.ts）
  it('挂载后把板块滚进视口，id 与 hash 原样相等', () => {
    window.history.replaceState({}, '', '/weekly/2026-W36#' + encodeURIComponent('issue-366-文章'))
    const scroll = vi.mocked(Element.prototype.scrollIntoView)

    show({
      sections: [weeklySection({ groups: [weeklyGroup({ name: '文章', anchor: 'issue-366-文章', items: [item({ id: 'b', title: '一篇文章' })] })] })],
    })
    expect(scroll).not.toHaveBeenCalled()

    vi.runAllTimers()

    expect(scroll).toHaveBeenCalledTimes(1)
    expect(scroll.mock.contexts[0]).toBe(document.getElementById(encodeURIComponent('issue-366-文章')))
  })
})

it('单条板块与标题重复时只保留一个标题，保留两种深链与返回目录', () => {
 const group = weeklyGroup({ name: '言论', anchor: 'issue-366-quotes', items: [item({ id: 'quote', title: '言论', published_at: null })] })
 const { container } = show({ sections: [weeklySection({ groups: [group] })] })
 expect(screen.getAllByRole('heading', { name: '言论' })).toHaveLength(1)
 expect(screen.getByRole('heading', { name: '言论', level: 3 })).toBeInTheDocument()
 expect(container.querySelector('#issue-366-quotes')).not.toBeNull()
 expect(container.querySelector('#item-quote')).not.toBeNull()
 const back = screen.getByRole('link', { name: '返回板块目录' })
 expect(document.getElementById(back.getAttribute('href')!.slice(1))).toHaveAttribute('aria-label', '板块')
})
