import { usePage } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import IssueHead from '@/components/IssueHead'
import IssueNotice from '@/components/IssueNotice'
import ItemRow from '@/components/ItemRow'
import Layout from '@/components/Layout'
import SourceState from '@/components/SourceState'
import SourceTabs from '@/components/SourceTabs'
import { DAILY_ARCHIVE, dailyHref, latestWeeklyHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { DailyIssue, IssueState, Item, SourceSummary } from '@/types/lowpass'

// 日刊详情，也是首页（D20）。期头带状态，来源索引条一次只显示一个来源，
// 条目单栏十条一致。切来源不回服务端：整期条目已经在 props 里。

export type DailyShowProps = {
  issue: DailyIssue
  missing: boolean
  sources: SourceSummary[]
  items_by_source: Record<string, Item[]>
  active_source_id: string | null
  latest_weekly_key: string | null
}

// 期级状态：状态词挂在期头的小签上，事实句放列表区顶部（第十轮笔记、画布 pages_front3.py 的 message()）。
// 缺期、生成中、空刊这三种状态下期头那句就是要说的事实句（附录 B 同一句话两处用），
// 所以直接读服务端定稿的 issue.status，前端不另写一份文案。
const NOTICE_STATES: IssueState[] = ['generating', 'empty']

function bodyNotice(issue: DailyIssue, missing: boolean): string | null {
  return missing || (issue.state && NOTICE_STATES.includes(issue.state)) ? issue.status : null
}

// 深链 ?source=<id>：切换时只改地址栏，不发请求。带上现有的 history.state，
// 免得把 Inertia 存在那里的页面快照抹掉（前进后退还要用）。
function rememberSource(sourceId: string) {
  const url = new URL(window.location.href)
  url.searchParams.set('source', sourceId)
  window.history.replaceState(window.history.state, '', url.toString())
}

function SourceBody({ source, items }: { source: SourceSummary; items: Item[] }) {
  return (
    <>
      <div className="issue-body">
        {source.state === 'ok' ? (
          items.map((item, index) => <ItemRow key={item.id} item={item} adapter={source.adapter} rank={item.rank ?? index + 1} />)
        ) : (
          <SourceState state={source.state} lastOkLabel={source.last_ok_label} />
        )}
      </div>

      {/* 栏尾外链，措辞按第八轮定的「来源名 完整榜单 ↗」；R-8.4 新标签页打开。
          画布 foot_link() 没有下划线——那是栏尾装置，不是正文里的原文链接。
          源的 home_url 算不出来（feed 地址不是 http）时整条不渲染。 */}
      {source.home_url ? (
        <a className="source-foot" href={source.home_url} target="_blank" rel="noopener noreferrer">
          <Mixed text={`${source.name} 完整榜单`} font="latin" size="var(--fs-15)" color="var(--ink)" />
          <Icon name="arrow-up-right" size={13} />
        </a>
      ) : null}
    </>
  )
}

export type SourcesProps = {
  sources: SourceSummary[]
  itemsBySource: Record<string, Item[]>
  activeSourceId: string | null
  notice: string | null
}

// 当前来源是本地状态，种子来自服务端（?source= 深链也走这条）。
// 调用方用 key={period_key} 拿住它：换一期就换一个实例，不会有一帧还停在上一期的来源上。
function Sources({ sources, itemsBySource, activeSourceId, notice }: SourcesProps) {
  const [activeId, setActiveId] = useState(activeSourceId)

  function selectSource(id: string) {
    setActiveId(id)
    rememberSource(id)
  }

  const active = sources.find((source) => source.id === activeId)
  if (!active) return notice ? <IssueNotice text={notice} /> : null

  return (
    <SourceTabs sources={sources} activeId={active.id} onSelect={selectSource}>
      {(source) => (notice ? <IssueNotice text={notice} /> : <SourceBody source={source} items={itemsBySource[source.id] ?? []} />)}
    </SourceTabs>
  )
}

export default function Show({ issue, missing, sources, items_by_source, active_source_id }: DailyShowProps) {
  const notice = bodyNotice(issue, missing)

  return (
    <>
      <IssueHead issue={issue} archiveHref={DAILY_ARCHIVE} hrefFor={dailyHref} />

      {/* R-1.6 缺期没有来源索引条，列表区只有「本期未生成」那一句 */}
      {missing ? (
        <IssueNotice text={notice ?? ''} />
      ) : (
        <Sources
          key={issue.period_key}
          sources={sources}
          itemsBySource={items_by_source}
          activeSourceId={active_source_id}
          notice={notice}
        />
      )}
    </>
  )
}

// Layout 是 application.tsx 里的持久布局，页脚要的下一期时间与前后期地址从 props 来，
// 所以套一层用 usePage 取 props 的小组件，再按 Home.tsx 那种写法交给 Inertia。
function DailyLayout({ children }: React.PropsWithChildren) {
  const { issue, latest_weekly_key } = usePage<DailyShowProps>().props

  return (
    <Layout
      masthead={{ active: 'daily' }}
      footer={{
        nextAt: issue.daily_time,
        latestWeeklyHref: latestWeeklyHref(latest_weekly_key),
        prevHref: issue.prev_key && dailyHref(issue.prev_key),
        nextHref: issue.next_key && dailyHref(issue.next_key),
      }}
    >
      {children}
    </Layout>
  )
}

Show.layout = (page: React.ReactNode) => <DailyLayout>{page}</DailyLayout>
