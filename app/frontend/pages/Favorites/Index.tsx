import { Link, usePage } from '@inertiajs/react'
import { useEffect, useId, useRef } from 'react'
import type * as React from 'react'

import FavoriteButton from '@/components/FavoriteButton'
import IssueNotice from '@/components/IssueNotice'
import { Translation } from '@/components/ItemRow'
import Layout from '@/components/Layout'
import PageHead from '@/components/PageHead'
import Pager from '@/components/Pager'
import { FavoritesProvider, useFavorites } from '@/lib/favorites'
import { DAILY_LATEST, dailyHref, favoritesHref, latestWeeklyHref } from '@/lib/paths'
import { Mixed, latinLang } from '@/lib/typeset'
import type { FavoriteEntry, FooterData, Publication } from '@/types/lowpass'

// 收藏页（PRD 5.10、R-10.6）：按收藏时间倒序，每页 20 条。先读标题、译文与片段，来源及所在期跟在正文后面。
// 标题是唯一原文入口，所在期与书签组成紧凑操作组；译文照日刊页的位置（D25）。不显示总数、不分组、不筛选（D28）。
// 取消后那一行原地留下「已取消收藏」与「恢复」，离开或刷新页面才消失（R-10.7）。文案是附录 B 原句。

export type FavoritesIndexProps = FooterData & {
  entries: FavoriteEntry[]
  favorites: string[]
  page: number
  pages: number
}

const LABELS: Record<Publication, string> = { daily: '日刊', weekly: '周刊' }

// 只画在收藏里的、这一次停留里取消过的（List 已经筛过）：不在收藏里的就是取消过、等着「恢复」的那一行
function Row({ entry }: { entry: FavoriteEntry }) {
  const favorites = useFavorites()
  const kept = favorites?.has(entry.url_hash) ?? false
  const rowRef = useRef<HTMLElement>(null)
  const markRef = useRef<HTMLButtonElement>(null)
  const restoreRef = useRef<HTMLButtonElement>(null)
  const was = useRef(kept)
  const statusId = useId()

  // 同一个书签控件在取消后提供恢复；两态沿用原来的焦点跟随限制（PRD 6.4）。
  // 只在读者还在这一行时跟（焦点在行里，或者随换掉的控件掉回了 body）：请求失败回滚时读者可能已经去了别处，不拽回来
  useEffect(() => {
    const active = document.activeElement
    const stayed = !active || active === document.body || rowRef.current?.contains(active)
    if (was.current !== kept && stayed) (kept ? markRef : restoreRef).current?.focus()
    was.current = kept
  }, [kept])

  return (
    <article ref={rowRef} className="search-row">
      <h2 className="search-title">
        <a className="t" href={entry.url} target="_blank" rel="noopener noreferrer" lang={latinLang(entry.title)}>
          <Mixed text={entry.title} font="latin" size="var(--fs-20)" color={kept ? 'var(--ink)' : 'var(--ink2)'} />
        </a>
      </h2>
      {entry.title_zh ? <Translation text={entry.title_zh} /> : null}

      {entry.snippet ? (
        <p className="search-snippet" lang={latinLang(entry.snippet)}>
          <Mixed text={entry.snippet} font="latin" size="var(--fs-15)" color="var(--ink2)" />
        </p>
      ) : null}
      {entry.summary_zh ? <Translation text={entry.summary_zh} /> : null}

      <div className="result-meta">
        <div className="result-context">
          <span>{LABELS[entry.publication]}</span>
          <Mixed text={entry.source_name} font="latin" size="var(--fs-13)" color="var(--ink2)" />
        </div>
        <div className="search-links">
          <Link className="t" href={entry.where.href}>
            <Mixed text={`所在期 · ${entry.where.label}`} size="var(--fs-13)" color="var(--ink)" />
          </Link>
          <span className={`favorite-controls search-mark${kept ? '' : ' favorite-removed'}`}>
            {!kept ? <span id={statusId}>已取消收藏</span> : null}
            <FavoriteButton ref={kept ? markRef : restoreRef} urlHash={entry.url_hash} title={entry.title} undo={{ describedBy: statusId }} />
          </span>
        </div>
      </div>
    </article>
  )
}

// 列表放在 FavoritesProvider 里面：哪几行画出来要看收藏状态
function List({ entries, page, pages, latest_daily_key }: Pick<FavoritesIndexProps, 'entries' | 'page' | 'pages' | 'latest_daily_key'>) {
  const favorites = useFavorites()
  // 既不在收藏里、这一次停留里也没取消过的行不画：历史恢复出来的旧列表里已经不在的那几条（R-10.7 离开后不再出现），
  // 或者取消时服务端说本来就没有（204）
  const shown = entries.filter((entry) => favorites?.has(entry.url_hash) || favorites?.removed(entry.url_hash))

  // 一行都不剩就是空态（AC-10.10），不是一页空白；别的页上还有收藏时不这么说，只留分页
  if (shown.length === 0 && pages <= 1) {
    return (
      <IssueNotice text="还没有收藏。">
        <Link className="ctrl" href={latest_daily_key ? dailyHref(latest_daily_key) : DAILY_LATEST}>
          阅读最新日刊
        </Link>
      </IssueNotice>
    )
  }

  return (
    <div className="results-reading">
      <div className="search-results">
        {shown.map((entry) => (
          <Row key={entry.url_hash} entry={entry} />
        ))}
      </div>
      {pages > 1 ? (
        <Pager prevHref={page > 1 ? favoritesHref(page - 1) : null} nextHref={page < pages ? favoritesHref(page + 1) : null} page={page} pages={pages} />
      ) : null}
    </div>
  )
}

export default function Index({ entries, favorites, page, pages, latest_daily_key }: FavoritesIndexProps) {
  return (
    <FavoritesProvider favorites={favorites}>
      <PageHead big="收藏" />
      <List entries={entries} page={page} pages={pages} latest_daily_key={latest_daily_key} />
    </FavoritesProvider>
  )
}

// 持久布局（application.tsx）：页脚要的字段从 props 来，跟 Search/Show 同一种写法
function FavoritesLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<FavoritesIndexProps>().props

  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}

Index.layout = (page: React.ReactNode) => <FavoritesLayout>{page}</FavoritesLayout>
