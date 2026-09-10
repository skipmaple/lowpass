import { Link } from '@inertiajs/react'

import Icon, { type IconName } from '@/components/Icon'
import { Mixed } from '@/lib/typeset'
import type { DailyIssue } from '@/types/lowpass'

// 期头：文楷 56 日期在左，右侧叠放 Maple 13 的发布时间与文楷 20 的星期，
// 状态标签是 1px 描边的小签（时钟图标 + 文楷 12），右端 40px 描边的前一期 / 归档 / 后一期。
// 手机版收成 40px 日期与三个 44px 方形图标按钮——尺寸都在 tokens.css 的 @media 里，
// 行内样式盖不住 @media，所以凡是要随断点变的值都走类名。
// 画布：docs/design/src/pages_front2.py 的 issue_head()、pages_front3.py 的 head_m()。

export type IssueHeadProps = {
  issue: DailyIssue
  archiveHref: string
  hrefFor: (periodKey: string) => string
}

// 40px 描边按钮。没有目标（最新一期的「后一期」）时退成 35% 墨线的不可点态。
function Ctrl({ href, label, icon, side }: { href: string | null; label: string; icon?: IconName; side?: 'left' | 'right' }) {
  const off = href === null
  const color = off ? 'var(--ink2)' : 'var(--ink)'
  const style = {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 6,
    height: 40,
    padding: '0 14px',
    border: `1px solid ${off ? 'var(--rule)' : 'var(--ink)'}`,
    fontFamily: 'var(--font-cjk)',
    fontSize: 'var(--fs-15)',
    color,
    whiteSpace: 'nowrap',
  } as const
  const body = (
    <>
      {icon && side === 'left' ? <Icon name={icon} color={color} /> : null}
      <span>{label}</span>
      {icon && side === 'right' ? <Icon name={icon} color={color} /> : null}
    </>
  )

  if (off) {
    return (
      <span style={style} role="link" aria-disabled="true">
        {body}
      </span>
    )
  }
  return (
    <Link href={href} style={style}>
      {body}
    </Link>
  )
}

function Square({ href, label, icon }: { href: string | null; label: string; icon: IconName }) {
  const off = href === null
  const color = off ? 'var(--ink2)' : 'var(--ink)'
  const style = {
    width: 44,
    height: 44,
    flex: 'none',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    border: `1px solid ${off ? 'var(--rule)' : 'var(--ink)'}`,
  } as const

  if (off) {
    return (
      <span style={style} role="link" aria-disabled="true" aria-label={label}>
        <Icon name={icon} size={18} color={color} />
      </span>
    )
  }
  return (
    <Link href={href} style={style} aria-label={label}>
      <Icon name={icon} size={18} color={color} />
    </Link>
  )
}

export default function IssueHead({ issue, archiveHref, hrefFor }: IssueHeadProps) {
  const prevHref = issue.prev_key ? hrefFor(issue.prev_key) : null
  const nextHref = issue.next_key ? hrefFor(issue.next_key) : null

  return (
    <>
      <header className="issue-head">
        <div className="issue-head-main">
          <div className="issue-head-title">
            <h1 className="issue-head-date">{issue.date_label}</h1>
            <div className="issue-head-stack">
              {/* 字号走 .issue-head-time（桌面 13、手机 12，画布 head_m 是 12）：行内样式盖不住 @media */}
              {issue.time_label ? <Mixed text={issue.time_label} className="issue-head-time" size="inherit" nowrap /> : null}
              <span className="issue-head-weekday">{issue.weekday}</span>
            </div>
          </div>
          {/* 状态标签：1px 描边小签，时钟图标 + 文楷 12，文案来自附录 B */}
          {issue.status ? (
            <div className="issue-head-tag">
              <span
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 6,
                  border: '1px solid var(--ink)',
                  padding: '3px 8px',
                }}
              >
                <Icon name="clock" size={13} />
                <Mixed text={issue.status} size="var(--fs-12)" color="var(--ink)" nowrap />
              </span>
            </div>
          ) : null}
        </div>

        <nav className="issue-nav" aria-label="期导航">
          <Ctrl href={prevHref} label="前一期" icon="chevron-left" side="left" />
          <Ctrl href={archiveHref} label="归档" />
          <Ctrl href={nextHref} label="后一期" icon="chevron-right" side="right" />
        </nav>
      </header>

      {/* 手机上三个 44px 方形图标按钮另起一行排在期头底线下面：
          375px 宽里期头那一行装不下 40px 日期加三个按钮。画布 page(compact=True) 的 controls 行就是这么排的。 */}
      <nav className="issue-nav-mobile" aria-label="期导航">
        <Square href={prevHref} label="前一期" icon="chevron-left" />
        <Square href={archiveHref} label="归档" icon="archive" />
        <Square href={nextHref} label="后一期" icon="chevron-right" />
      </nav>
    </>
  )
}
