import { usePage } from '@inertiajs/react'
import { useEffect, useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import IssueHead from '@/components/IssueHead'
import ItemRow from '@/components/ItemRow'
import Layout from '@/components/Layout'
import SourceState from '@/components/SourceState'
import SourceTabs from '@/components/SourceTabs'
import { Mixed } from '@/lib/typeset'
import type { DailyIssue, Item, SourceSummary } from '@/types/lowpass'

// 日刊详情，也是首页（D20）。期头带状态，来源索引条一次只显示一个来源，
// 条目单栏十条一致。切来源不回服务端：整期条目已经在 props 里。

export type DailyShowProps = {
  issue: DailyIssue
  missing: boolean
  sources: SourceSummary[]
  items_by_source: Record<string, Item[]>
  active_source_id: string | null
}

const dailyHref = (periodKey: string) => `/daily/${periodKey}`
const ARCHIVE_HREF = '/daily'

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

      {/* 栏尾外链，措辞按第八轮定的「来源名 完整榜单 ↗」；R-8.4 新标签页打开 */}
      <a className="t source-foot" href={source.home_url} target="_blank" rel="noopener noreferrer">
        <Mixed text={`${source.name} 完整榜单`} font="latin" size="var(--fs-15)" color="var(--ink)" />
        <Icon name="arrow-up-right" size={13} />
      </a>
    </>
  )
}

export default function Show({ issue, missing, sources, items_by_source, active_source_id }: DailyShowProps) {
  const [activeId, setActiveId] = useState(active_source_id)

  // 切到别的一期时，当前来源以服务端给的为准（?source= 深链也走这条）
  useEffect(() => {
    setActiveId(active_source_id)
  }, [active_source_id, issue.period_key])

  function selectSource(id: string) {
    setActiveId(id)
    rememberSource(id)
  }

  const active = sources.find((source) => source.id === activeId)

  return (
    <>
      <IssueHead issue={issue} archiveHref={ARCHIVE_HREF} hrefFor={dailyHref} />

      {/* R-1.6 缺期只有期头那句「本期未生成」，没有来源索引条 */}
      {missing || !active ? null : (
        <SourceTabs sources={sources} activeId={active.id} onSelect={selectSource}>
          <SourceBody source={active} items={items_by_source[active.id] ?? []} />
        </SourceTabs>
      )}
    </>
  )
}

// Layout 是 application.tsx 里的持久布局，页脚要的下一期时间与前后期地址从 props 来，
// 所以套一层用 usePage 取 props 的小组件，再按 Home.tsx 那种写法交给 Inertia。
function DailyLayout({ children }: React.PropsWithChildren) {
  const { issue } = usePage<DailyShowProps>().props

  return (
    <Layout
      masthead={{ active: 'daily' }}
      footer={{
        nextAt: issue.daily_time,
        latestWeeklyHref: '/weekly',
        prevHref: issue.prev_key && dailyHref(issue.prev_key),
        nextHref: issue.next_key && dailyHref(issue.next_key),
      }}
    >
      {children}
    </Layout>
  )
}

Show.layout = (page: React.ReactNode) => <DailyLayout>{page}</DailyLayout>
