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
