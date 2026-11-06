import { Link } from '@inertiajs/react'
import { Ctrl } from '@/components/Ctrl'
import { DAILY_ARCHIVE, dailyHref } from '@/lib/paths'
import type { DailyIssue } from '@/types/lowpass'

export default function IssueDate({ issue }: { issue: DailyIssue }) {
  const [, month, day] = issue.period_key.split('-')
  const label = month && day ? `${month}/${day}` : issue.date_label
  return (
    <div className="issue-calendar">
      <div className="calendar-meta"><span>{issue.year}</span><span>{issue.weekday}</span></div>
      <Link className="calendar-date" href={DAILY_ARCHIVE} title={issue.time_label ?? undefined} aria-label={`${issue.year}/${label}，查看日刊归档`}>
        <span className="calendar-month">{month || label}</span>{day ? <><span className="calendar-slash">/</span><span className="calendar-day">{day}</span></> : null}
      </Link>
      <nav className="period-controls" aria-label="期导航">
        <Ctrl href={issue.prev_key ? dailyHref(issue.prev_key) : null} label="上一期" icon="chevron-left" side="left" turn="back" />
        <Ctrl href={issue.next_key ? dailyHref(issue.next_key) : null} label="下一期" icon="chevron-right" side="right" turn="forward" />
      </nav>
    </div>
  )
}
