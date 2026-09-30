import { Link, usePage } from '@inertiajs/react'
import { useEffect, useId, useRef } from 'react'
import type * as React from 'react'

import Chip from '@/components/Chip'
import FavoriteButton from '@/components/FavoriteButton'
import Icon from '@/components/Icon'
import IssueNotice from '@/components/IssueNotice'
import { Translation } from '@/components/ItemRow'
import Layout from '@/components/Layout'
import PageHead from '@/components/PageHead'
import Pager from '@/components/Pager'
import { FavoritesProvider, useFavorites } from '@/lib/favorites'
import { DAILY_LATEST, dailyHref, favoritesHref, latestWeeklyHref } from '@/lib/paths'
import { Mixed, latinLang } from '@/lib/typeset'
import type { FavoriteEntry, FooterData, Publication } from '@/types/lowpass'

// 收藏页（PRD 5.10、R-10.6）：按收藏时间倒序，每页 20 条。行沿用搜索结果行的装置（眉行、标题、片段、底行两个链接），
// 标题不带命中下划线，译文照日刊页的位置（D25），底行右端是书签。不显示总数、不分组、不筛选（D28）。
// 取消后那一行原地留下「已取消收藏」与「恢复」，离开或刷新页面才消失（R-10.7）。文案是附录 B 原句。

export type FavoritesIndexProps = FooterData & {
  entries: FavoriteEntry[]
  favorites: string[]
  page: number
  pages: number
}

const LABELS: Record<Publication, string> = { daily: '日刊', weekly: '周刊' }
const DOT = <span className="search-dot">·</span>

// 只画在收藏里的、这一次停留里取消过的（List 已经筛过）：不在收藏里的就是取消过、等着「恢复」的那一行
function Row({ entry }: { entry: FavoriteEntry }) {
  const favorites = useFavorites()
  const kept = favorites?.has(entry.url_hash) ?? false
  const rowRef = useRef<HTMLElement>(null)
  const markRef = useRef<HTMLButtonElement>(null)
  const restoreRef = useRef<HTMLButtonElement>(null)
  const was = useRef(kept)
  const statusId = useId()

  // 取消与恢复会把读者刚按的那个控件换掉：焦点跟到换上来的那个，不掉回 body（PRD 6.4）。
  // 只在读者还在这一行时跟（焦点在行里，或者随换掉的控件掉回了 body）：请求失败回滚时读者可能已经去了别处，不拽回来
  useEffect(() => {
    const active = document.activeElement
    const stayed = !active || active === document.body || rowRef.current?.contains(active)
    if (was.current !== kept && stayed) (kept ? markRef : restoreRef).current?.focus()
    was.current = kept
  }, [kept])

  return (
    <article ref={rowRef} className="search-row">
      <div className="search-eyebrow">
        <Chip text={LABELS[entry.publication]} />
        <Mixed text={entry.source_name} font="latin" weight={500} size="var(--fs-13)" color="var(--ink2)" />
        {DOT}
        <Mixed text={entry.where.label} size="var(--fs-13)" color="var(--ink2)" />
      </div>

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

      <div className="search-links">
        <Link className="t" href={entry.where.href}>
          <Mixed text={`所在期 · ${entry.where.label}`} size="var(--fs-13)" color="var(--ink)" />
        </Link>
        <a className="search-original" href={entry.url} target="_blank" rel="noopener noreferrer">
          <span>原文</span>
          <Icon name="arrow-up-right" size={12} />
        </a>
        {kept ? (
          <FavoriteButton ref={markRef} className="search-mark" urlHash={entry.url_hash} title={entry.title} />
        ) : (
          <span className="favorite-removed search-mark">
            <span id={statusId}>已取消收藏</span>
            <button ref={restoreRef} type="button" className="link-button" aria-describedby={statusId} onClick={() => favorites?.restore(entry.url_hash)}>
              恢复
            </button>
          </span>
        )}
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
    <>
      <div className="search-results">
        {shown.map((entry) => (
          <Row key={entry.url_hash} entry={entry} />
        ))}
      </div>
      {pages > 1 ? (
        <Pager prevHref={page > 1 ? favoritesHref(page - 1) : null} nextHref={page < pages ? favoritesHref(page + 1) : null} page={page} pages={pages} />
      ) : null}
    </>
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
