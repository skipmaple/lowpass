import { describe, expect, it } from 'vitest'

import {
  DAILY_ARCHIVE,
  DAILY_LATEST,
  SEARCH,
  SEARCH_CLICKS,
  WEEKLY_ARCHIVE,
  dailyHref,
  latestWeeklyHref,
  monthHref,
  searchHref,
  weeklyHref,
  yearHref,
} from '@/lib/paths'

// 站内地址只在 lib/paths.ts 拼一次，对着 config/routes.rb 的 daily_issues / weekly_issues
// 两条资源路由加根路由（D20）。这里逐条钉住拼出来的形状。

describe('paths', () => {
  it('把三个入口钉在路由上', () => {
    expect(DAILY_LATEST).toBe('/')
    expect(DAILY_ARCHIVE).toBe('/daily')
    expect(WEEKLY_ARCHIVE).toBe('/weekly')
  })

  it('日刊与周刊详情用周期键做最后一段', () => {
    expect(dailyHref('2026-09-08')).toBe('/daily/2026-09-08')
    expect(weeklyHref('2026-W36')).toBe('/weekly/2026-W36')
  })

  it('翻月与翻年是归档页的查询串', () => {
    expect(monthHref('2026-09')).toBe('/daily?month=2026-09')
    expect(yearHref('2026')).toBe('/weekly?year=2026')
  })

  it('有最新一期时「最新周刊」指向那一期', () => {
    expect(latestWeeklyHref('2026-W36')).toBe('/weekly/2026-W36')
  })

  // R51：一期周刊都还没有时页脚那条链接落到归档，不能拼出 /weekly/null
  it('一期周刊都没有时落到归档', () => {
    expect(latestWeeklyHref(null)).toBe('/weekly')
  })

  it('搜索入口与点击端点', () => {
    expect(SEARCH).toBe('/search')
    expect(SEARCH_CLICKS).toBe('/search/clicks')
  })

  // R-4.5：只写非空的键，默认值不进地址；来源逗号连接，中文与空格按 URLSearchParams 编码
  it('searchHref 只写非空的参数', () => {
    expect(searchHref()).toBe('/search')
    expect(searchHref({ q: 'kuber rust', type: 'daily', source: ['a', 'b'], page: 2, sort: 'date' })).toBe(
      '/search?q=kuber+rust&type=daily&source=a%2Cb&page=2&sort=date',
    )
    expect(searchHref({ q: '终端', from: '2026-09-01', to: null, range: '7d' })).toBe('/search?q=%E7%BB%88%E7%AB%AF&from=2026-09-01&range=7d')
    expect(searchHref({ q: 'x', page: 1, sort: 'relevance', range: 'all', source: [] })).toBe('/search?q=x')
  })
})
