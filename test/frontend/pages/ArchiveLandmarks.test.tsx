import { render, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'

import DailyIndex from '@/pages/Daily/Index'
import WeeklyIndex from '@/pages/Weekly/Index'
import { setPageProps } from '../support/inertia'

afterEach(() => setPageProps({}))

describe('归档页的导航地标', () => {
  it.each(['日刊', '周刊'])('%s归档可按用途区分站点导航与页面导航', (kind) => {
    if (kind === '日刊') {
      const props = { month_label: '2026 年 9 月', prev_month: { key: '2026-08', label: '8 月' }, next_month: null, days: [], daily_time: '06:00', latest_weekly_key: '2026-W36' }
      setPageProps(props)
      render(DailyIndex.layout(<DailyIndex {...props} />))
    } else {
      const props = { year_label: '2026 年', prev_year: { key: '2025', label: '2025 年' }, next_year: null, weeks: [], daily_time: '06:00', latest_weekly_key: '2026-W36' }
      setPageProps(props)
      render(WeeklyIndex.layout(<WeeklyIndex {...props} />))
    }
    const previous = kind === '日刊' ? '8 月' : '2025 年'
    const href = kind === '日刊' ? '/daily?month=2026-08' : '/weekly?year=2025'

    const primary = screen.getByRole('navigation', { name: '主导航' })
    const archive = screen.getByRole('navigation', { name: '页面导航' })
    expect(screen.getAllByRole('navigation')).toHaveLength(2)
    expect(within(primary).getByRole('link', { name: '日刊' })).toHaveAttribute('href', '/')
    expect(within(primary).getByRole('link', { name: '周刊' })).toHaveAttribute('href', '/weekly/2026-W36')
    expect(within(archive).getByRole('link', { name: previous })).toHaveAttribute('href', href)
    expect(within(archive).queryByRole('link', { name: '日刊' })).toBeNull()
    expect(within(primary).queryByRole('link', { name: previous })).toBeNull()
    expect(screen.getAllByRole('main')).toHaveLength(1)
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1)
  })
})
