import Icon from '@/components/Icon'
import { Head } from '@inertiajs/react'
import IssueDate from '@/components/IssueDate'
import { Mixed } from '@/lib/typeset'
import type { DailyIssue } from '@/types/lowpass'

// 日刊期头：文楷 56 日期在左，右侧用两层区分日期属性与发布时间，
// 状态标签是 1px 描边的小签（时钟图标 + 文楷 12），右端 40px 描边的前一期 / 归档 / 后一期。
// 装置本身在 PageHead 里，这里只把一期的 props 摆到位。
// 画布：docs/design/src/pages_front2.py 的 issue_head()、pages_front3.py 的 head_m()。

export type IssueHeadProps = {
  issue: DailyIssue
  archiveHref: string
  hrefFor: (periodKey: string) => string
}

// 状态标签：1px 描边小签，时钟图标 + 文楷 12，文案来自附录 B
export function StatusTag({ text }: { text: string }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, border: '1px solid var(--ink)', padding: '3px 8px' }}>
      <Icon name="clock" size={13} />
      <Mixed text={text} size="var(--fs-12)" color="var(--ink)" nowrap />
    </span>
  )
}

export default function IssueHead({ issue }: IssueHeadProps) {
  return (
    <header className="issue-head">
      <Head title={`日刊 · ${issue.period_key.replace(/-/g, '/')}`} />
      <h1 className="visually-hidden">{issue.period_key.replace(/-/g, '/')} 日刊</h1>
      <div className="issue-head-calendar-panel"><IssueDate issue={issue} /></div>
      {issue.status && issue.state === 'published' ? <div className="issue-head-status"><StatusTag text={issue.status} /></div> : null}
    </header>
  )
}
