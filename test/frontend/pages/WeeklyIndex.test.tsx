import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Index, { type WeeklyIndexProps } from '@/pages/Weekly/Index'
import { archiveWeek } from '../support/props'

// 周刊归档（PRD 6.2、R-2.7）：一页一年，每周一行，没有期的那一周照样列出来。

function index(overrides: Partial<WeeklyIndexProps> = {}) {
  const props: WeeklyIndexProps = {
    year_label: '2026 年',
    prev_year: { key: '2025', label: '2025 年' },
    next_year: null,
    weeks: [archiveWeek()],
    daily_time: '06:00',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }

  return render(<Index {...props} />)
}

function rows(container: HTMLElement) {
  return Array.from(container.querySelectorAll('.archive-row')) as HTMLElement[]
}

describe('周刊归档', () => {
  it('年份是 h1', () => {
    index()

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('2026 年')
  })

  it('一周一行，整行点进那一期', () => {
    const { container } = index({
      weeks: [archiveWeek(), archiveWeek({ period_key: '2026-W35', week_label: '第 35 周' })],
    })

    expect(rows(container).map((row) => row.getAttribute('href'))).toEqual(['/weekly/2026-W36', '/weekly/2026-W35'])
  })

  it('已发布：实心记号、周次、日期范围、各源期号与条数', () => {
    const { container } = index()

    const row = rows(container)[0]
    expect(within(row).getByRole('img', { name: '已发布' })).toBeInTheDocument()
    expect(row).toHaveTextContent('第 36 周')
    expect(row).toHaveTextContent('8月31日 至 9月6日')
    expect(row.querySelector('.archive-label')).toHaveTextContent('阮一峰科技爱好者周刊 第 366 期 · 人生的容错率')
    expect(row.querySelector('.archive-meta')).toHaveTextContent('42 条')
  })

  // 周维度的「没有」只有一种：记号跟空刊长得一样，但读屏念的是「无内容」
  it('没有期的那一周标「本周无内容」，记号念「无内容」', () => {
    const { container } = index({
      weeks: [archiveWeek({ state: 'empty', summary: '本周无内容', count: null })],
    })

    const row = rows(container)[0]
    expect(within(row).getByRole('img', { name: '无内容' })).toBeInTheDocument()
    expect(within(row).queryByRole('img', { name: '空刊' })).toBeNull()
    expect(row.querySelector('.archive-label')).toHaveTextContent('本周无内容')
    expect(row.querySelector('.archive-meta')?.textContent).toBe('')
  })

  it('只有已发布那行的摘要是正文墨色', () => {
    const { container } = index({
      weeks: [archiveWeek(), archiveWeek({ period_key: '2026-W35', state: 'empty', summary: '本周无内容', count: null })],
    })

    const colorOf = (row: HTMLElement) =>
      (row.querySelector('.archive-label span span') as HTMLElement | null)?.style.color

    expect(colorOf(rows(container)[0])).toBe('var(--ink)')
    expect(colorOf(rows(container)[1])).toBe('var(--ink2)')
  })
})

describe('周刊归档的翻年', () => {
  it('有上一年就有按钮，指向那一年的归档', () => {
    index()

    expect(screen.getByRole('link', { name: '2025 年' })).toHaveAttribute('href', '/weekly?year=2025')
  })

  it('越界的方向不摆按钮', () => {
    const { container } = index({ prev_year: null, next_year: null })

    expect(container.querySelector('.page-nav')?.textContent).toBe('')
  })
})
