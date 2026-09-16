// 站内地址只在这里拼一次（config/routes.rb 的 daily_issues / weekly_issues 两条资源路由，
// 加根路由 D20：`/` 就是最新一期日刊）。
export const DAILY_LATEST = '/'
export const DAILY_ARCHIVE = '/daily'
export const WEEKLY_ARCHIVE = '/weekly'

export const dailyHref = (periodKey: string) => `${DAILY_ARCHIVE}/${periodKey}`
export const weeklyHref = (periodKey: string) => `${WEEKLY_ARCHIVE}/${periodKey}`

export const monthHref = (month: string) => `${DAILY_ARCHIVE}?month=${month}`
export const yearHref = (year: string) => `${WEEKLY_ARCHIVE}?year=${year}`

// 页脚的「最新周刊」：一期周刊都还没有时落到归档（R51）
export const latestWeeklyHref = (periodKey: string | null) => (periodKey ? weeklyHref(periodKey) : WEEKLY_ARCHIVE)

// P1 搜索（config/routes.rb 的 resource :search 与 namespace :search 下的 clicks）
export const SEARCH = '/search'
export const SEARCH_CLICKS = '/search/clicks'

// R-4.5 的地址参数：只写非空的键，来源用逗号连接；page 为 1、sort 为 relevance、range 为 all 是默认值，不写进地址
export type SearchParams = {
  q?: string
  type?: string | null
  source?: string[]
  from?: string | null
  to?: string | null
  range?: string | null
  page?: number
  sort?: string | null
}

export function searchHref(params: SearchParams = {}): string {
  const query = new URLSearchParams()
  if (params.q) query.set('q', params.q)
  if (params.type) query.set('type', params.type)
  if (params.source && params.source.length > 0) query.set('source', params.source.join(','))
  if (params.from) query.set('from', params.from)
  if (params.to) query.set('to', params.to)
  if (params.range && params.range !== 'all') query.set('range', params.range)
  if (params.page && params.page > 1) query.set('page', String(params.page))
  if (params.sort && params.sort !== 'relevance') query.set('sort', params.sort)
  const text = query.toString()
  return text ? `${SEARCH}?${text}` : SEARCH
}

// P2-① 登录（config/routes.rb 的 login / session / settings，OmniAuth 的 /auth/:provider 与回调）
export const LOGIN = '/login'
export const SESSION = '/session'
export const SETTINGS = '/settings'
export const ADMIN_JOBS = '/admin/jobs'
export const authHref = (provider: string) => `/auth/${provider}`
export const authCallbackHref = (provider: string) => `/auth/${provider}/callback`

// P2-② 管理后台（config/routes.rb 的 namespace :admin）
export const ADMIN_ROOT = '/admin'
export const ADMIN_SOURCES = '/admin/sources'
export const ADMIN_SOURCES_NEW = '/admin/sources/new'
export const adminSourceHref = (id: string) => `${ADMIN_SOURCES}/${id}`
export const adminSourceEditHref = (id: string) => `${ADMIN_SOURCES}/${id}/edit`
export const adminSourceEnablementHref = (id: string) => `${ADMIN_SOURCES}/${id}/enablement`
export const adminSourceRunsHref = (id: string, status?: string) => `${ADMIN_SOURCES}/${id}/runs${status && status !== 'all' ? `?status=${status}` : ''}`
export const ADMIN_TEST_FETCH = '/admin/test_fetches'
export const ADMIN_ISSUES = '/admin/issues'
export function adminIssuesHref(params: { kind?: string | null; month?: string | null }): string {
  const query = new URLSearchParams()
  if (params.kind && params.kind !== 'all') query.set('kind', params.kind)
  if (params.month) query.set('month', params.month)
  const text = query.toString()
  return text ? `${ADMIN_ISSUES}?${text}` : ADMIN_ISSUES
}
export const adminIssueRefetchHref = (periodKey: string) => `${ADMIN_ISSUES}/${periodKey}/refetch`
export const adminIssueBackfillHref = (periodKey: string) => `${ADMIN_ISSUES}/${periodKey}/backfill`
export const ADMIN_TODAY_ISSUE = '/admin/today_issue'
export const ADMIN_USERS = '/admin/users'
export const ADMIN_SETTINGS = '/admin/settings'
export const ADMIN_TEST_ALERT = '/admin/test_alert'

// ④ 推荐理由：兴趣画像 CRUD（namespace :admin 的 interest_areas）、整期重生成理由端点
export const ADMIN_INTEREST_AREAS = '/admin/interest_areas'
export const adminInterestAreaHref = (id: string) => `${ADMIN_INTEREST_AREAS}/${id}`
export const adminIssueReasonsHref = (periodKey: string) => `${ADMIN_ISSUES}/${periodKey}/reasons`
