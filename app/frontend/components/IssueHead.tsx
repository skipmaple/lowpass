import Icon from '@/components/Icon'
import PageHead from '@/components/PageHead'
import { Mixed } from '@/lib/typeset'
import type { DailyIssue } from '@/types/lowpass'

// 日刊期头：文楷 56 日期在左，右侧叠放 Maple 13 的发布时间与文楷 20 的星期，
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

export default function IssueHead({ issue, archiveHref, hrefFor }: IssueHeadProps) {
  return (
    <PageHead
      big={issue.date_label}
      /* 字号走 .issue-head-time（桌面 13、手机 12，画布 head_m 是 12）：行内样式盖不住 @media */
      top={issue.time_label ? <Mixed text={issue.time_label} className="issue-head-time" size="inherit" nowrap /> : null}
      bottom={issue.weekday}
      tag={issue.status ? <StatusTag text={issue.status} /> : null}
      nav={{
        prevHref: issue.prev_key ? hrefFor(issue.prev_key) : null,
        nextHref: issue.next_key ? hrefFor(issue.next_key) : null,
        archiveHref,
      }}
    />
  )
}
