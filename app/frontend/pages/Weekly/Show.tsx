import { usePage } from '@inertiajs/react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import IssueNotice from '@/components/IssueNotice'
import ItemRow from '@/components/ItemRow'
import Layout from '@/components/Layout'
import PageHead from '@/components/PageHead'
import { WEEKLY_ARCHIVE, latestWeeklyHref, weeklyHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { FooterData, WeeklyGroup, WeeklyIssue, WeeklySection } from '@/types/lowpass'

// 周刊详情（PRD 5.2、R-2.5 到 R-2.7）：期头「第 36 周 · 2026 · 8月31日 至 9月6日」，
// 每个源一节——反白横带（源名、该源自己的期号与主题、原文外链）、板块锚点目录、按板块分节的条目。
// 阮一峰按原文板块分节，RSS 周刊源没有板块、每条带发布时间（R-2.6）。
// D19：周刊条目不加推荐理由，也就没有兴趣标签。
// 画布：docs/design/src/pages_site.py 的 weekly()、source_band()、anchors()、rss_section()、degraded_section()。

export type WeeklyShowProps = FooterData & {
  issue: WeeklyIssue
  sections: WeeklySection[]
}

// 反白横带：书本图标 + 源名 32（拉丁走 Newsreader 600，中文走文楷），右端期号与原文外链
function SourceBand({ section }: { section: WeeklySection }) {
  return (
    <div className="source-band">
      <div className="source-band-name">
        <Icon name="book-open" size={28} color="var(--paper)" />
        <h2 className="source-band-title">
          <Mixed text={section.source.name} font="latin" weight={600} size="inherit" color="var(--paper)" nowrap />
        </h2>
      </div>

      <div className="source-band-meta">
        {section.issue_label ? (
          <span className="source-band-issue">
            <Mixed text={section.issue_label} font="latin" size="var(--fs-15)" color="var(--paper)" />
          </span>
        ) : null}
        {/* R-2.5 源节头带原文链接；R-8.4 新标签页打开。feed 地址算不出落点时整条收掉 */}
        {section.original_url ? (
          <a className="source-band-link" href={section.original_url} target="_blank" rel="noopener noreferrer">
            <span>{section.issue_no ? '原文' : '来源'}</span>
            <Icon name="arrow-up-right" size={13} color="var(--paper)" />
          </a>
        ) : null}
      </div>
    </div>
  )
}

// 板块锚点目录：1px 描边的锚点小块，横向排一行，窄屏可横向滚动
function Anchors({ groups }: { groups: WeeklyGroup[] }) {
  return (
    <nav className="anchors" aria-label="板块">
      {groups.map((group) => (
        <a className="anchor-chip" key={group.anchor} href={`#${group.anchor}`}>
          {group.name}
        </a>
      ))}
    </nav>
  )
}

function Items({ group, section, heading }: { group: WeeklyGroup; section: WeeklySection; heading: 'h3' | 'h4' }) {
  return (
    <>
      {group.items.map((item, index) => (
        <ItemRow
          key={item.id}
          item={item}
          adapter={section.source.adapter}
          rank={item.rank ?? index + 1}
          variant="weekly"
          heading={heading}
        />
      ))}
    </>
  )
}

function Group({ group, section }: { group: WeeklyGroup; section: WeeklySection }) {
  // RSS 周刊源没有板块：直接接条目，列表区顶上一条 1px 墨线
  if (!group.name) {
    return (
      <div className="issue-body">
        <Items group={group} section={section} heading="h3" />
      </div>
    )
  }

  return (
    <section id={group.anchor}>
      <h3 className="weekly-section-head">{group.name}</h3>
      <Items group={group} section={section} heading="h4" />
    </section>
  )
}

// R-2.3 降级：整期只剩一条指向原文的条目，加附录 B 那句
function Degraded({ section }: { section: WeeklySection }) {
  const stub = section.groups[0]?.items[0]

  return (
    <IssueNotice text="本期解析失败，已保留原文链接">
      {stub ? (
        <a className="source-foot" href={section.original_url ?? stub.url} target="_blank" rel="noopener noreferrer">
          <Mixed text={stub.title} font="latin" size="var(--fs-15)" color="var(--ink)" />
          <Icon name="arrow-up-right" size={13} />
        </a>
      ) : null}
    </IssueNotice>
  )
}

function Section({ section }: { section: WeeklySection }) {
  const named = section.groups.filter((group) => group.name)

  return (
    <>
      <SourceBand section={section} />
      {section.degraded ? (
        <Degraded section={section} />
      ) : (
        <>
          {named.length > 0 ? <Anchors groups={named} /> : null}
          {section.groups.map((group) => (
            <Group key={group.anchor} group={group} section={section} />
          ))}
        </>
      )}
    </>
  )
}

export default function Show({ issue, sections }: WeeklyShowProps) {
  return (
    <>
      <PageHead
        big={issue.week_label}
        top={<span className="issue-head-year">{issue.year}</span>}
        bottom={issue.range_label}
        nav={{
          prevHref: issue.prev_key ? weeklyHref(issue.prev_key) : null,
          nextHref: issue.next_key ? weeklyHref(issue.next_key) : null,
          archiveHref: WEEKLY_ARCHIVE,
        }}
      />

      {/* R-2.7 那一周没有期：期头照常，正文只有「本周无内容」 */}
      {sections.length === 0 ? (
        <IssueNotice text={issue.status ?? ''} />
      ) : (
        sections.map((section) => <Section key={`${section.source.id}-${section.issue_no ?? 0}`} section={section} />)
      )}
    </>
  )
}

function WeeklyLayout({ children }: React.PropsWithChildren) {
  const { issue, daily_time, latest_weekly_key } = usePage<WeeklyShowProps>().props

  return (
    <Layout
      masthead={{ active: 'weekly' }}
      footer={{
        nextAt: daily_time,
        latestWeeklyHref: latestWeeklyHref(latest_weekly_key),
        prevHref: issue.prev_key && weeklyHref(issue.prev_key),
        nextHref: issue.next_key && weeklyHref(issue.next_key),
      }}
    >
      {children}
    </Layout>
  )
}

Show.layout = (page: React.ReactNode) => <WeeklyLayout>{page}</WeeklyLayout>
