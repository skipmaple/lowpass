import { Link, usePage } from '@inertiajs/react'
import type * as React from 'react'

import { Ctrl } from '@/components/Ctrl'
import Layout from '@/components/Layout'
import Mark from '@/components/Mark'
import PageHead from '@/components/PageHead'
import { dailyHref, latestWeeklyHref, monthHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { ArchiveDay, ArchiveNav, FooterData } from '@/types/lowpass'

// 日刊归档（PRD 6.2）：一页一个月，默认当月，每天一行——状态记号、日期、星期、发布信息、各源结果。
// 缺期那天也列出来，点进去看到的是「本期未生成」（R-1.6）。上线前的日期不显示，所以最早一期
// 之前的月份一行都没有，翻月的按钮也就到此为止。
// 画布：docs/design/src/pages_site.py 的 archive_daily()、mark()。

export type DailyIndexProps = FooterData & {
  month_label: string
  prev_month: ArchiveNav
  next_month: ArchiveNav
  days: ArchiveDay[]
}

function Row({ day }: { day: ArchiveDay }) {
  return (
    <Link className="archive-row" href={dailyHref(day.period_key)}>
      <span className="archive-mark">
        <Mark state={day.state} />
      </span>
      <span className="archive-key">{day.date_label}</span>
      <span className="archive-sub">{day.weekday}</span>
      <span className="archive-label">
        {day.published_label ? (
          <Mixed text={day.published_label} color={day.state === 'published' ? 'var(--ink)' : 'var(--ink2)'} />
        ) : null}
      </span>
      <span className="archive-meta">{day.source_marks ? <Mixed text={day.source_marks} /> : null}</span>
    </Link>
  )
}

export default function Index({ month_label, prev_month, next_month, days }: DailyIndexProps) {
  return (
    <>
      <PageHead
        big={month_label}
        controls={
          <>
            {prev_month ? <Ctrl href={monthHref(prev_month.key)} label={prev_month.label} icon="chevron-left" side="left" /> : null}
            {next_month ? <Ctrl href={monthHref(next_month.key)} label={next_month.label} icon="chevron-right" side="right" /> : null}
          </>
        }
      />

      <div className="archive-list archive-daily">
        {days.map((day) => (
          <Row key={day.period_key} day={day} />
        ))}
      </div>
    </>
  )
}

function ArchiveLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<DailyIndexProps>().props

  return (
    <Layout masthead={{ active: 'daily' }} footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>
      {children}
    </Layout>
  )
}

Index.layout = (page: React.ReactNode) => <ArchiveLayout>{page}</ArchiveLayout>
