import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Index, { type DailyIndexProps } from '@/pages/Daily/Index'
import { archiveDay } from '../support/props'

// 日刊归档（PRD 6.2）：一页一个月，每天一行，缺期那天也列出来（R-1.6）。

function index(overrides: Partial<DailyIndexProps> = {}) {
  const props: DailyIndexProps = {
    month_label: '2026 年 9 月',
    prev_month: { key: '2026-08', label: '8 月' },
    next_month: null,
    days: [archiveDay()],
    daily_time: '06:00',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }

  return render(<Index {...props} />)
}

function rows(container: HTMLElement) {
  return Array.from(container.querySelectorAll('.archive-row')) as HTMLElement[]
}

describe('日刊归档', () => {
  it('月份是 h1', () => {
    index()

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('2026 年 9 月')
  })

  it('一天一行，整行点进那一期', () => {
    const { container } = index({
      days: [archiveDay(), archiveDay({ period_key: '2026-09-07', date_label: '9月7日', weekday: '星期一' })],
    })

    expect(rows(container).map((row) => row.getAttribute('href'))).toEqual(['/daily/2026-09-08', '/daily/2026-09-07'])
  })

  it('已发布：实心记号、发布时间、各源结果', () => {
    const { container } = index()

    const row = rows(container)[0]
    expect(within(row).getByRole('img', { name: '已发布' })).toBeInTheDocument()
    expect(row).toHaveTextContent('9月8日')
    expect(row).toHaveTextContent('星期二')
    expect(row.querySelector('.archive-label')).toHaveTextContent('06:12 发布')
    expect(row.querySelector('.archive-meta')).toHaveTextContent('HN 10 · GH 10 · HAD 8')
  })

  // 归档一行只放得下一句：空刊那句太长，交给状态记号说
  it('空刊只有描边记号，不写发布信息', () => {
    const { container } = index({
      days: [archiveDay({ state: 'empty', published_label: null, source_marks: 'HN 0 · GH 0 · HAD 0' })],
    })

    const row = rows(container)[0]
    expect(within(row).getByRole('img', { name: '空刊' })).toBeInTheDocument()
    expect(row.querySelector('.archive-label')?.textContent).toBe('')
  })

  it('缺期是叉加「缺期」，那一格没有各源结果', () => {
    const { container } = index({
      days: [archiveDay({ state: 'missing', published_label: '缺期', source_marks: null })],
    })

    const row = rows(container)[0]
    expect(within(row).getByRole('img', { name: '缺期' })).toBeInTheDocument()
    expect(row.querySelector('.archive-label')).toHaveTextContent('缺期')
    expect(row.querySelector('.archive-meta')?.textContent).toBe('')
  })

  it('生成中是时钟加那一句', () => {
    const { container } = index({
      days: [archiveDay({ state: 'generating', published_label: '生成中，约 1 分钟后刷新', source_marks: 'HN 生成中' })],
    })

    const row = rows(container)[0]
    expect(within(row).getByRole('img', { name: '生成中' })).toBeInTheDocument()
    expect(row.querySelector('.archive-label')).toHaveTextContent('生成中，约 1 分钟后刷新')
  })

  // 发布了的那天用正文墨色，其余压到次级墨色
  it('只有已发布那行的发布信息是正文墨色', () => {
    const { container } = index({
      days: [archiveDay(), archiveDay({ period_key: '2026-09-07', state: 'missing', published_label: '缺期' })],
    })

    const colorOf = (row: HTMLElement) =>
      (row.querySelector('.archive-label span span') as HTMLElement | null)?.style.color

    expect(colorOf(rows(container)[0])).toBe('var(--ink)')
    expect(colorOf(rows(container)[1])).toBe('var(--ink2)')
  })
})

describe('日刊归档的翻月', () => {
  it('有上一个月就有按钮，指向那个月的归档', () => {
    index()

    expect(screen.getByRole('link', { name: '8 月' })).toHaveAttribute('href', '/daily?month=2026-08')
  })

  // 上线前的月份与未来的月份都没有这一页，按钮就到此为止（服务端给 null）
  it('越界的方向不摆按钮', () => {
    const { container } = index({ prev_month: null, next_month: null })

    expect(container.querySelector('.page-nav')?.textContent).toBe('')
  })

  it('跨年的按钮带上年份', () => {
    index({ prev_month: { key: '2025-12', label: '2025 年 12 月' }, next_month: { key: '2026-10', label: '10 月' } })

    expect(screen.getByRole('link', { name: '2025 年 12 月' })).toHaveAttribute('href', '/daily?month=2025-12')
    expect(screen.getByRole('link', { name: '10 月' })).toHaveAttribute('href', '/daily?month=2026-10')
  })
})
