import { Link, router, usePage } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import IssueHead from '@/components/IssueHead'
import IssueNotice from '@/components/IssueNotice'
import ItemRow from '@/components/ItemRow'
import Layout from '@/components/Layout'
import SourceState from '@/components/SourceState'
import SourceDirectory from '@/components/SourceDirectory'
import DailySourceSection from '@/components/DailySourceSection'
import { useScrollToHash } from '@/lib/anchors'
import { FavoritesProvider } from '@/lib/favorites'
import { DAILY_ARCHIVE, adminIssueBackfillHref, dailyHref, latestWeeklyHref } from '@/lib/paths'
import { useArrowTurns } from '@/lib/pageTurn'
import { usePolling } from '@/lib/polling'
import { Mixed } from '@/lib/typeset'
import type { DailyIssue, IssueState, Item, SharedProps, SourceSummary } from '@/types/lowpass'

// 日刊详情，也是首页（D20）。全部来源连续呈现，目录使用原生页内锚点。

export type DailyShowProps = {
  issue: DailyIssue
  missing: boolean
  sources: SourceSummary[]
  items_by_source: Record<string, Item[]>
  // 这一期里当前读者收藏过的链接（url_hash），书签对着它画（PRD 5.10）
  favorites: string[]
  active_source_id: string | null
  latest_weekly_key: string | null
  latest_daily_key?: string | null
  backfill_available?: boolean
}

// 期级状态：状态词挂在期头的小签上，事实句放列表区顶部（第十轮笔记、画布 pages_front3.py 的 message()）。
// 缺期、生成中、空刊的事实只在正文出现一次；已发布后的修订、延迟等状态保留期头小签。
// 两者都读服务端定稿的 issue.status，前端不另写一份文案。
const NOTICE_STATES: IssueState[] = ['generating', 'empty']

function bodyNotice(issue: DailyIssue, missing: boolean): string | null {
  return missing || (issue.state && NOTICE_STATES.includes(issue.state)) ? issue.status : null
}

function SourceBody({ source, items }: { source: SourceSummary; items: Item[] }) {
  return (
    <>
      <div className="issue-body">
        {source.state === 'ok' ? (
          items.map((item, index) => <ItemRow key={item.id} item={item} adapter={source.adapter} rank={item.rank ?? index + 1} heading="h3" />)
        ) : (
          <SourceState state={source.state} lastOkLabel={source.last_ok_label} />
        )}
      </div>

      {/* 栏尾外链，措辞按第八轮定的「来源名 完整榜单 ↗」；R-8.4 新标签页打开。
          画布 foot_link() 没有下划线——那是栏尾装置，不是正文里的原文链接。
          源的 home_url 算不出来（feed 地址不是 http）时整条不渲染。 */}
      <div className="source-actions">
        {source.home_url ? (
          <a className="source-foot" href={source.home_url} target="_blank" rel="noopener noreferrer">
            <Mixed text={`${source.name} 完整榜单`} font="latin" size="var(--fs-15)" color="var(--ink)" />
            <Icon name="arrow-up-right" size={13} />
          </a>
        ) : null}
        <a className="directory-return" href="#source-directory">
          <span aria-hidden="true">↑</span>
          <span>返回来源目录</span>
        </a>
      </div>
    </>
  )
}

function Sources({ sources, itemsBySource, notice, fallbackAnchor }: { sources: SourceSummary[]; itemsBySource: Record<string, Item[]>; notice: string | null; fallbackAnchor?: { sourceId: string; id: string } }) {
  return (
    <>
      {sources.length > 0 ? <SourceDirectory sources={sources} navigable={!notice} /> : null}
      {notice ? <IssueNotice text={notice} /> : sources.map((source, index) => (
        <DailySourceSection key={source.id} source={source} animate={index > 0} aliasId={fallbackAnchor?.sourceId === source.id ? fallbackAnchor.id : undefined}>
          <SourceBody source={source} items={itemsBySource[source.id] ?? []} />
        </DailySourceSection>
      ))}
    </>
  )
}

// 「生成中，约 1 分钟后刷新」要说到做到：生成中每 10 秒部分重载这一期，定稿（发布或空刊）了就停。
// 只重载期与各栏，保持阅读位置。条目出来了书签才有东西可画，所以 favorites 一起重载。
const GENERATING_RELOAD = ['issue', 'missing', 'sources', 'items_by_source', 'favorites']
const GENERATING_POLL_MS = 10_000

export default function Show({ issue, missing, sources, items_by_source, favorites, latest_daily_key, backfill_available }: DailyShowProps) {
  // 兼容旧的来源深链；普通打开不因服务端的默认 active_source_id 而跳过期头。
  const { url } = usePage()
  const requestedSource = new URL(url, 'https://lowpass.invalid').searchParams.get('source')
  const sourceAnchor = sources.some((source) => source.id === requestedSource) ? `source-${requestedSource}` : undefined
  // 重抓后旧条目已消失：在来源栏首给旧 hash 留一个落点，浏览器与 Inertia 都能直接定位，避免归零竞态。
  const hash = typeof window === 'undefined' ? '' : window.location.hash.slice(1)
  const missingItem = hash.startsWith('item-') && !Object.values(items_by_source).some((items) => items.some((item) => `item-${item.id}` === hash))
  const fallbackAnchor = requestedSource && sourceAnchor && missingItem ? { sourceId: requestedSource, id: hash } : undefined
  useScrollToHash(issue.period_key, sourceAnchor)
  usePolling(issue.state === 'generating', GENERATING_RELOAD, GENERATING_POLL_MS)
  useArrowTurns(issue.prev_key ? dailyHref(issue.prev_key) : null, issue.next_key ? dailyHref(issue.next_key) : null)
  const notice = bodyNotice(issue, missing)
  const [backfilling, setBackfilling] = useState(false)
  const [backfillResult, setBackfillResult] = useState<string | null>(null)
  function backfill() {
    setBackfilling(true)
    setBackfillResult(null)
    router.post(adminIssueBackfillHref(issue.period_key), {}, {
      preserveScroll: true,
      onSuccess: (page) => {
        const flash = page.props.flash as SharedProps['flash'] | undefined
        setBackfillResult(flash?.alert || flash?.notice || '请求已结束，请刷新查看本期状态')
      },
      onNetworkError: () => { setBackfillResult('网络连接失败，请刷新确认本期状态后重试'); return false },
      onHttpException: () => { setBackfillResult('服务暂时无法处理请求，请刷新确认本期状态'); return false },
      onError: () => setBackfillResult('补生成请求失败，请重试'),
      onFinish: () => setBackfilling(false),
    })
  }

  return (
    <FavoritesProvider favorites={favorites}>
      <IssueHead issue={issue} archiveHref={DAILY_ARCHIVE} hrefFor={dailyHref} />

      {/* 没有记录时不展示来源目录；今日未到生成时间则说明计划时间。 */}
      {missing ? (
        <IssueNotice text={notice ?? ''}>
          <Link className="ctrl" href={latest_daily_key ? dailyHref(latest_daily_key) : DAILY_ARCHIVE}>{latest_daily_key ? '阅读最新日刊' : '查看日刊归档'}</Link>
          {backfill_available ? <button className="link-button" type="button" disabled={backfilling} onClick={backfill}>{backfilling ? '正在补生成…' : '补生成本期'}</button> : null}
          {backfillResult ? <p className="operation-feedback" role="status">{backfillResult}</p> : null}
        </IssueNotice>
      ) : (
        <Sources
          key={issue.period_key}
          sources={sources}
          itemsBySource={items_by_source}
          notice={notice}
          fallbackAnchor={fallbackAnchor}
        />
      )}
    </FavoritesProvider>
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
