import { describe, expect, it } from 'vitest'

import {
  ADMIN_INTEREST_AREAS,
  ADMIN_JOBS,
  ADMIN_SETTINGS,
  ADMIN_SOURCES,
  ADMIN_TEST_ALERT,
  ADMIN_TEST_FETCH,
  ADMIN_TODAY_ISSUE,
  DAILY_ARCHIVE,
  DAILY_LATEST,
  LOGIN,
  SEARCH,
  SEARCH_CLICKS,
  SESSION,
  SETTINGS,
  WEEKLY_ARCHIVE,
  adminInterestAreaHref,
  adminIssueBackfillHref,
  adminIssueReasonsHref,
  adminIssueRefetchHref,
  adminIssuesHref,
  adminSourceEditHref,
  adminSourceEnablementHref,
  adminSourceRunsHref,
  authCallbackHref,
  authHref,
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

describe('登录相关地址', () => {
  it('固定路径与 OmniAuth 发起地址', () => {
    expect(LOGIN).toBe('/login')
    expect(SESSION).toBe('/session')
    expect(SETTINGS).toBe('/settings')
    expect(ADMIN_JOBS).toBe('/admin/jobs')
    expect(authHref('google_oauth2')).toBe('/auth/google_oauth2')
    expect(authCallbackHref('developer')).toBe('/auth/developer/callback')
  })
})

describe('后台地址', () => {
  it('列表、表单、记录、期与操作', () => {
    expect(ADMIN_SOURCES).toBe('/admin/sources')
    expect(adminSourceEditHref('s1')).toBe('/admin/sources/s1/edit')
    expect(adminSourceRunsHref('s1')).toBe('/admin/sources/s1/runs')
    expect(adminSourceRunsHref('s1', 'failed')).toBe('/admin/sources/s1/runs?status=failed')
    expect(adminSourceEnablementHref('s1')).toBe('/admin/sources/s1/enablement')
    expect(ADMIN_TEST_FETCH).toBe('/admin/test_fetches')
    expect(adminIssuesHref({})).toBe('/admin/issues')
    expect(adminIssuesHref({ kind: 'daily', month: '2026-08' })).toBe('/admin/issues?kind=daily&month=2026-08')
    expect(adminIssueRefetchHref('2026-09-08')).toBe('/admin/issues/2026-09-08/refetch')
    expect(adminIssueBackfillHref('2026-09-03')).toBe('/admin/issues/2026-09-03/backfill')
    expect(ADMIN_TODAY_ISSUE).toBe('/admin/today_issue')
    expect(ADMIN_SETTINGS).toBe('/admin/settings')
    expect(ADMIN_TEST_ALERT).toBe('/admin/test_alert')
  })

  // ④ 推荐理由：兴趣画像 CRUD、整期重生成理由端点
  it('兴趣画像与推荐理由', () => {
    expect(ADMIN_INTEREST_AREAS).toBe('/admin/interest_areas')
    expect(adminInterestAreaHref('x')).toBe('/admin/interest_areas/x')
    expect(adminIssueReasonsHref('2026-09-08')).toBe('/admin/issues/2026-09-08/reasons')
  })
})
