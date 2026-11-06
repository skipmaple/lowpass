import { Link, router, usePage } from '@inertiajs/react'
import { useEffect, useId, useRef, useState } from 'react'
import type * as React from 'react'

import FavoriteButton from '@/components/FavoriteButton'
import Icon from '@/components/Icon'
import IssueNotice from '@/components/IssueNotice'
import Layout from '@/components/Layout'
import LibraryRecord from '@/components/LibraryRecord'
import PageHead from '@/components/PageHead'
import Pager from '@/components/Pager'
import PendingLabel from '@/components/PendingLabel'
import { normalizeDateLabel } from '@/lib/displayDate'
import { FavoritesProvider, useFavorites } from '@/lib/favorites'
import { DAILY_LATEST, dailyHref, favoritesHref, latestWeeklyHref } from '@/lib/paths'
import { latinLang } from '@/lib/typeset'
import type { FavoriteEntry, FooterData, Publication } from '@/types/lowpass'

export type FavoritesIndexProps = FooterData & {
  entries: FavoriteEntry[]
  favorites: string[]
  page: number
  pages: number
  q?: string
  source?: string
  total?: number
  source_options?: { id: string; name: string }[]
}

const LABELS: Record<Publication, string> = { daily: '日刊', weekly: '周刊' }

function Row({ entry, rank }: { entry: FavoriteEntry; rank: number }) {
  const favorites = useFavorites()
  const kept = favorites?.has(entry.url_hash) ?? false
  const rowRef = useRef<HTMLElement>(null)
  const markRef = useRef<HTMLButtonElement>(null)
  const restoreRef = useRef<HTMLButtonElement>(null)
  const was = useRef(kept)
  const statusId = useId()
  const title = entry.title_zh || entry.title
  const summary = entry.summary_zh || entry.snippet
  const detail = entry.reason || entry.title_zh || (entry.summary_zh && entry.snippet)

  // 同一个书签控件在取消后提供恢复；两态沿用原来的焦点跟随限制（PRD 6.4）。
  // 只在读者还在这一行时跟（焦点在行里，或者随换掉的控件掉回了 body）：请求失败回滚时读者可能已经去了别处，不拽回来
  useEffect(() => {
    const active = document.activeElement
    const stayed = !active || active === document.body || rowRef.current?.contains(active)
    if (was.current !== kept && stayed) (kept ? markRef : restoreRef).current?.focus()
    was.current = kept
  }, [kept])

  return (
    <LibraryRecord
      ref={rowRef}
      id={`favorite-${entry.url_hash}`}
      rank={rank}
      title={title}
      href={entry.url}
      lang={latinLang(title)}
      meta={<>
        <span>{entry.source_name}</span><span>{LABELS[entry.publication]}</span>
        <span>{normalizeDateLabel(entry.where.label)}</span>
        {entry.saved_label ? <time>收藏于 {normalizeDateLabel(entry.saved_label)}</time> : null}
      </>}
      summary={summary ? <p className="search-snippet" lang={latinLang(summary)}>{summary}</p> : null}
      detailTitle={entry.reason ? '值得关注' : '原文线索'}
      detail={detail ? <>
        {entry.reason ? <p>{entry.reason}</p> : null}
        {entry.title_zh ? <p className="record-original-title" lang={latinLang(entry.title)}>{entry.title}</p> : null}
        {entry.summary_zh && entry.snippet ? <p className="record-original-summary" lang={latinLang(entry.snippet)}>{entry.snippet}</p> : null}
      </> : null}
      actions={<>
        <a className="search-original" href={entry.url} target="_blank" rel="noopener noreferrer" aria-describedby="new-tab-description">原文<Icon name="arrow-up-right" size={16} /></a>
        <Link className="record-issue-link" href={entry.where.href}>所在期 · {normalizeDateLabel(entry.where.label)}</Link>
        <span className={`favorite-controls search-mark${kept ? '' : ' favorite-removed'}`}>
          {!kept ? <span id={statusId}>已取消收藏</span> : null}
          <FavoriteButton ref={kept ? markRef : restoreRef} urlHash={entry.url_hash} title={title} undo={{ describedBy: statusId }} />
        </span>
      </>}
    />
  )
}

function List({ entries, page, pages, latest_daily_key, q = '', source = '' }: FavoritesIndexProps) {
  const favorites = useFavorites()
  const shown = entries.filter((entry) => favorites?.has(entry.url_hash) || favorites?.removed(entry.url_hash))

  if (shown.length === 0 && pages <= 1) {
    if (q || source) {
      return <IssueNotice text={q ? `收藏中没有找到「${q}」。` : '这个来源还没有收藏。'} />
    }
    return (
      <IssueNotice text="还没有收藏。">
        <Link className="ctrl" href={latest_daily_key ? dailyHref(latest_daily_key) : DAILY_LATEST}>阅读最新日刊</Link>
      </IssueNotice>
    )
  }

  return (
    <>
      <div className="search-results">{shown.map((entry, index) => <Row key={entry.url_hash} entry={entry} rank={(page - 1) * 20 + index + 1} />)}</div>
      {pages > 1 ? <Pager prevHref={page > 1 ? favoritesHref(page - 1, { q, source }) : null} nextHref={page < pages ? favoritesHref(page + 1, { q, source }) : null} page={page} pages={pages} /> : null}
    </>
  )
}

function CollectionCount({ entries, total, filtered, loading }: { entries: FavoriteEntry[]; total: number; filtered: boolean; loading: boolean }) {
  const favorites = useFavorites()
  const removed = entries.filter((entry) => !favorites?.has(entry.url_hash)).length
  const count = Math.max(0, total - removed)
  return <p className="collection-count" role="status">{loading ? '正在搜索收藏…' : `${count} 条${filtered ? '符合条件的' : ''}收藏`}</p>
}

export default function Index(props: FavoritesIndexProps) {
  const { q = '', source = '', source_options = [] } = props
  const { url } = usePage()
  const [draft, setDraft] = useState(q)
  const [loading, setLoading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  useEffect(() => setDraft(q), [q, url])

  function search(selectedSource = source) {
    router.get(favoritesHref(1, { q: draft.trim(), source: selectedSource }), {}, {
      preserveState: true,
      onStart: () => setLoading(true),
      onFinish: () => setLoading(false),
    })
  }

  return (
    <FavoritesProvider favorites={props.favorites}>
      <section className="library-page collection-page">
        <PageHead big="收藏" />
        <div className="library-workspace">
          <form role="search" aria-label="搜索收藏" className="collection-search" onSubmit={(event) => { event.preventDefault(); if (!loading) search() }}>
            <label htmlFor="collection-query">搜索收藏</label>
            <div className="collection-search-field">
              <input ref={inputRef} id="collection-query" type="search" value={draft} maxLength={100} onChange={(event) => setDraft(event.target.value)} placeholder="标题、用途或项目名" autoComplete="off" />
              <button type="submit" className="btn-primary" disabled={loading} aria-busy={loading}><PendingLabel idle="搜索" pending="搜索中…" busy={loading} /><Icon name="search" size={18} /></button>
            </div>
            {source_options.length > 1 ? (
              <label className="collection-source-filter">来源<select aria-label="收藏来源" value={source} onChange={(event) => search(event.target.value)}><option value="">全部来源</option>{source_options.map((option) => <option key={option.id} value={option.id}>{option.name}</option>)}</select></label>
            ) : null}
            {q || source ? <Link className="collection-reset" href={favoritesHref()}>清除筛选</Link> : null}
          </form>
          {props.total !== undefined ? <CollectionCount entries={props.entries} total={props.total} filtered={Boolean(q || source)} loading={loading} /> : null}
          <List {...props} />
        </div>
      </section>
    </FavoritesProvider>
  )
}

function FavoritesLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<FavoritesIndexProps>().props
  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}
Index.layout = (page: React.ReactNode) => <FavoritesLayout>{page}</FavoritesLayout>
