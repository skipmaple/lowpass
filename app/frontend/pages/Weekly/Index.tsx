import { Link, usePage } from '@inertiajs/react'
import type * as React from 'react'

import { Ctrl } from '@/components/Ctrl'
import Layout from '@/components/Layout'
import Mark from '@/components/Mark'
import PageHead from '@/components/PageHead'
import { latestWeeklyHref, weeklyHref, yearHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { ArchiveNav, ArchiveWeek, FooterData } from '@/types/lowpass'

// 周刊归档（PRD 6.2、R-2.7）：一页一年，每周一行——周次、日期范围、各源期号与主题、条数。
// 没有期的那一周照样列出来，标「本周无内容」（附录 B）。
// 画布：docs/design/src/pages_site.py 的 archive_weekly()、mark()。

export type WeeklyIndexProps = FooterData & {
  year_label: string
  prev_year: ArchiveNav
  next_year: ArchiveNav
  weeks: ArchiveWeek[]
}

function Row({ week }: { week: ArchiveWeek }) {
  const published = week.state === 'published'

  return (
    <Link className="archive-row" href={weeklyHref(week.period_key)}>
      <span className="archive-mark">
        {/* 归档里的「没有」是本周无内容，不是空刊（日刊归档才用空刊那个词，见 Mark 的默认名） */}
        <Mark state={week.state} label={week.state === 'empty' ? '无内容' : undefined} />
      </span>
      <span className="archive-key">{week.week_label}</span>
      <span className="archive-sub">{week.range_label}</span>
      <span className="archive-label">
        {week.summary ? (
          <Mixed text={week.summary} font="latin" size="var(--fs-15)" color={published ? 'var(--ink)' : 'var(--ink2)'} />
        ) : null}
      </span>
      <span className="archive-meta">{week.count ? <Mixed text={`${week.count} 条`} /> : null}</span>
    </Link>
  )
}

export default function Index({ year_label, prev_year, next_year, weeks }: WeeklyIndexProps) {
  return (
    <>
      <PageHead
        big={year_label}
        controls={
          <>
            {prev_year ? <Ctrl href={yearHref(prev_year.key)} label={prev_year.label} icon="chevron-left" side="left" /> : null}
            {next_year ? <Ctrl href={yearHref(next_year.key)} label={next_year.label} icon="chevron-right" side="right" /> : null}
          </>
        }
      />

      <div className="archive-list archive-weekly">
        {weeks.map((week) => (
          <Row key={week.period_key} week={week} />
        ))}
      </div>
    </>
  )
}

function ArchiveLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<WeeklyIndexProps>().props

  return (
    <Layout masthead={{ active: 'weekly' }} footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>
      {children}
    </Layout>
  )
}

Index.layout = (page: React.ReactNode) => <ArchiveLayout>{page}</ArchiveLayout>
