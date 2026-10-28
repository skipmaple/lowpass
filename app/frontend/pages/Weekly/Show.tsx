import { usePage } from '@inertiajs/react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import IssueNotice from '@/components/IssueNotice'
import ItemRow from '@/components/ItemRow'
import Layout from '@/components/Layout'
import PageHead from '@/components/PageHead'
import ReadingDirectory from '@/components/ReadingDirectory'
import { useScrollToHash } from '@/lib/anchors'
import { FavoritesProvider } from '@/lib/favorites'
import { useArrowTurns } from '@/lib/pageTurn'
import { WEEKLY_ARCHIVE, latestWeeklyHref, weeklyHref } from '@/lib/paths'
import { Mixed, latinLang } from '@/lib/typeset'
import type { FooterData, WeeklyGroup, WeeklyIssue, WeeklySection } from '@/types/lowpass'

// 周刊详情（PRD 5.2、R-2.5 到 R-2.7）：期头「第 36 周 · 2026 · 8月31日 至 9月6日」，
// 每个源一节——本期主题、来源与期号、原文外链、板块目录和完整条目。
// 阮一峰按原文板块分节，RSS 周刊源没有板块、每条带发布时间（R-2.6）。
// D19：周刊条目不加推荐理由，也就没有兴趣标签。
// 画布：docs/design/src/pages_site.py 的 weekly()、source_band()、anchors()、rss_section()、degraded_section()。

// 板块的 DOM id 是锚点的百分号编码形式：location.hash 里的中文一律是编码过的，Inertia 与 lib/anchors.ts 都拿
// hash 原样找元素，id 也得是编码过的（源 id 与拉丁 slug 编码后不变；服务端 weekly_issue_path(anchor:) 编码规则相同）
const anchorId = (anchor: string) => encodeURIComponent(anchor)

export type WeeklyShowProps = FooterData & {
  issue: WeeklyIssue
  sections: WeeklySection[]
  // 这一期里当前读者收藏过的链接（url_hash），书签对着它画（PRD 5.10）
  favorites: string[]
}

function SourceMeta({ section }: { section: WeeklySection }) {
  return (
    <div className="source-band-meta">
      {section.issue_title ? <span className="source-band-source" lang={latinLang(section.source.name)}><Mixed text={section.source.name} font="latin" size="inherit" color="inherit" /></span> : null}
      {section.issue_no ? <span className="source-band-issue">第 {section.issue_no} 期</span> : null}
      {/* R-2.5 源节头带原文链接；R-8.4 新标签页打开。feed 地址算不出落点时整条收掉 */}
      {section.original_url ? (
        <a className="source-band-link" href={section.original_url} target="_blank" rel="noopener noreferrer">
          <span>{section.issue_no ? '原文' : '来源'}</span>
          <Icon name="arrow-up-right" size={13} color="currentColor" />
        </a>
      ) : null}
    </div>
  )
}

// 本期主题负责辨识内容；来源、期号和原文入口紧随其后，不再抢占标题层级。
function SourceBand({ section, id }: { section: WeeklySection; id?: string }) {
  const title = section.issue_title || section.source.name

  return (
    <header className="source-band" id={id}>
      <h2 className="source-band-title" lang={latinLang(title)}>
        <Mixed text={title} font="latin" weight={600} size="inherit" color="inherit" lineHeight="inherit" />
      </h2>
      <SourceMeta section={section} />
    </header>
  )
}

// 所有宽度先进入正文；需要跳读时展开原生目录，不因窗口变化重置读者选择。
function Anchors({ groups, id }: { groups: WeeklyGroup[]; id: string }) {
  return (
    <ReadingDirectory id={id} label="板块目录" className="weekly-directory">
      <nav id={id} tabIndex={-1} className="anchors" aria-label="板块">
        {groups.map((group) => (
          <a className="anchor-chip" key={group.anchor} href={`#${anchorId(group.anchor)}`}>
            {group.name}
          </a>
        ))}
      </nav>
    </ReadingDirectory>
  )
}

function openDirectory(id: string) {
  const nav = document.getElementById(id)
  const details = nav?.closest('details')
  if (details) details.open = true
  nav?.focus({ preventScroll: true })
}

function Items({ group, section, heading, intro }: { group: WeeklyGroup; section: WeeklySection; heading: 'h2' | 'h3' | 'h4'; intro?: React.ReactNode }) {
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
          intro={intro}
        />
      ))}
    </>
  )
}

function Group({ group, section, directory, aliasId, intro }: { group: WeeklyGroup; section: WeeklySection; directory: string; aliasId?: string; intro?: React.ReactNode }) {
  // RSS 周刊源没有板块：直接接条目，列表区顶上一条 1px 墨线
  if (!group.name) {
    return (
      <div className="issue-body">
        <Items group={group} section={section} heading="h3" />
      </div>
    )
  }

  return (
    <section id={anchorId(group.anchor)}>
      {aliasId ? <span id={aliasId} className="weekly-anchor-alias" aria-hidden="true" /> : null}
      {intro ? (
        <Items group={group} section={section} heading="h2" intro={intro} />
      ) : group.items.length === 1 && group.items[0].title === group.name ? (
        <Items group={group} section={section} heading="h3" />
      ) : (
        <>
          <h3 className="weekly-section-head">{group.name}</h3>
          <Items group={group} section={section} heading="h4" />
        </>
      )}
      <a className="directory-return" href={`#${directory}`} onClick={() => openDirectory(directory)}>
        <span aria-hidden="true">↑</span>
        <span>返回板块目录</span>
      </a>
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
          <Mixed className="source-original-title" text={stub.title} font="latin" size="var(--fs-15)" color="var(--ink)" />
          <Icon name="arrow-up-right" size={13} />
        </a>
      ) : null}
    </IssueNotice>
  )
}

function Section({ section, fallback }: { section: WeeklySection; fallback?: { anchor: string; aliasId?: string } }) {
  const directory = `directory-${section.source.id}-${section.issue_no ?? 0}`
  const named = section.groups.filter((group) => group.name)
  // RSS 周刊源与降级 stub 没有板块，旧链接及失效条目的回退落在源节头。
  const head = section.groups.find((group) => !group.name)
  const first = section.groups[0]
  // 只合并确实承担本期主题的第一条；封面、近似标题、多条板块与降级保持原结构。
  const lead = !section.degraded && section.issue_title && first?.items.length === 1
    && first.name === section.issue_title && first.items[0].title === section.issue_title ? first : undefined

  return (
    <div className="weekly-reading">
      {fallback?.aliasId && (section.degraded || !section.groups.some((group) => group.name && group.anchor === fallback.anchor)) ? <span id={fallback.aliasId} className="weekly-anchor-alias" aria-hidden="true" /> : null}
      {lead ? (head ? <span id={anchorId(head.anchor)} className="weekly-anchor-alias" aria-hidden="true" /> : null) : <SourceBand section={section} id={head ? anchorId(head.anchor) : undefined} />}
      {section.degraded ? (
        <Degraded section={section} />
      ) : (
        <>
          {!lead && named.length > 0 ? <Anchors groups={named} id={directory} /> : null}
          {section.groups.map((group) => (
            <Group
              key={group.anchor} group={group} section={section} directory={directory}
              aliasId={fallback?.anchor === group.anchor ? fallback.aliasId : undefined}
              intro={group === lead ? <><SourceMeta section={section} /><Anchors groups={named} id={directory} /></> : undefined}
            />
          ))}
        </>
      )}
    </div>
  )
}

export default function Show({ issue, sections, favorites }: WeeklyShowProps) {
  const { url } = usePage()
  const requestedSection = new URL(url, 'https://lowpass.invalid').searchParams.get('section')
  const hash = typeof window === 'undefined' ? '' : window.location.hash.slice(1)
  const itemHash = /^item-[a-z0-9]{25}$/.test(hash)
  const fallback = itemHash ? sections.flatMap((section) => section.groups.map((group) => ({ section, group }))).find(({ group }) => group.anchor === requestedSection) : undefined
  const missingItem = itemHash && !sections.some((section) => !section.degraded && section.groups.some((group) => group.items.some((item) => `item-${item.id}` === hash)))
  useScrollToHash(issue.period_key, fallback ? anchorId(fallback.group.anchor) : undefined, true)
  useArrowTurns(issue.prev_key ? weeklyHref(issue.prev_key) : null, issue.next_key ? weeklyHref(issue.next_key) : null)
  return (
    <FavoritesProvider favorites={favorites}>
      <PageHead
        big={issue.week_label}
        title={`周刊 · ${issue.year} · ${issue.week_label}`}
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
        sections.map((section) => <Section key={`${section.source.id}-${section.issue_no ?? 0}`} section={section} fallback={fallback?.section === section ? { anchor: fallback.group.anchor, aliasId: missingItem ? hash : undefined } : undefined} />)
      )}
    </FavoritesProvider>
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
