import { Head, Link, router, usePage } from '@inertiajs/react'
import { useEffect, useRef, useState } from 'react'
import type * as React from 'react'

import { Ctrl } from '@/components/Ctrl'
import Icon from '@/components/Icon'
import Layout from '@/components/Layout'
import SearchFilters, { hasActiveFilters } from '@/components/SearchFilters'
import SearchResultRow from '@/components/SearchResultRow'
import Seg from '@/components/Seg'
import { dailyHref, latestWeeklyHref, searchHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { DatePresets, FooterData, SearchFilters as Filters, SearchResult, SearchSourceOption, SearchState } from '@/types/lowpass'

// 搜索页（PRD 5.4、6.2，设计 6.2）：期头是查询词与反白「搜索」按钮，筛选栏三组，正文按服务端的 state 选择状态
// （加载中另有可见状态提示）。筛选、排序、翻页全是地址（AC-4.7）；文案是附录 B 原句，这里只负责选。
// 画布：docs/design/src/pages_site.py 的 search()、search_states()。

export type SearchShowProps = FooterData & {
  q: string
  truncated: boolean
  filters: Filters
  source_options: SearchSourceOption[]
  date_presets: DatePresets
  state: SearchState
  results: SearchResult[]
  total: number
  page: number
  pages: number
  latest_daily_key: string | null
  latest_daily_label: string | null
}

// 结果与错误来自附录 B，输入约束明确说明哪些关键词会执行。
const COPY = {
  placeholder: '搜标题、摘要或来源。拼写不准也可以。',
  empty: (q: string) => `没有找到「${q}」相关内容。试试更短的关键词，或放宽筛选。`,
  limited: '操作过于频繁，请等待 1 分钟后重试。',
  unsupported: '请输入至少 2 个字母的关键词，或中文、C、C++、C#。纯符号不会执行搜索。',
  unavailable: '搜索暂不可用，请稍后重试。',
  truncated: '已截断到 100 字',
}

// 当前查询与筛选的地址（改排序与翻页用；page 不传就是第 1 页）
function hrefOf(q: string, filters: Filters, page = 1) {
  return searchHref({ q, type: filters.type, source: filters.sources, from: filters.from, to: filters.to, range: filters.range, sort: filters.sort, page })
}

// 期头（画布 search_head()）：搜索图标、文楷 32 的查询词输入框、反白「搜索」按钮；回车与按钮都提交——
// 由 Inertia 访问 /search（GET），筛选原样带上、页码归 1。草稿由页面持有，让期头和筛选始终使用同一个值。
function SearchHead({ draft, setDraft, filters, truncated, inputRef, loading, unsupported }: { draft: string; setDraft: (value: string) => void; filters: Filters; truncated: boolean; inputRef: React.RefObject<HTMLInputElement | null>; loading: boolean; unsupported: boolean }) {
  function submit(event: React.FormEvent) {
    event.preventDefault()
    if (!loading) router.get(hrefOf(draft.trim(), filters))
  }

  function clear() {
    setDraft('')
    inputRef.current?.focus()
  }

  return (
    <form className="search-head" role="search" onSubmit={submit}>
      <div className="search-field">
        <Icon name="search" size={24} />
        <label className="sr-only" htmlFor="search-query">搜索</label>
        <input
          ref={inputRef}
          id="search-query"
          type="search"
          className="search-input"
          name="q"
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder={COPY.placeholder}
          aria-invalid={unsupported || undefined}
          aria-describedby={unsupported ? 'search-status' : undefined}
          autoComplete="off"
          autoFocus
        />
        <button type="button" className="search-clear" aria-label="清除搜索词" disabled={draft.length === 0} onClick={clear}>
          <Icon name="x" size={18} />
        </button>
      </div>
      <button type="submit" className="btn-primary" disabled={loading}>
        搜索
      </button>
      {truncated ? <span className="search-note">{COPY.truncated}</span> : null}
    </form>
  )
}

// 结果计数（PRD 6.2 明确要求的计数）与排序分段（F-17）同一行
function CountLine({ total, q, filters }: { total: number; q: string; filters: Filters }) {
  const options = [
    { label: '相关度', href: hrefOf(q, { ...filters, sort: 'relevance' }), active: filters.sort === 'relevance' },
    { label: '时间', href: hrefOf(q, { ...filters, sort: 'date' }), active: filters.sort === 'date' },
  ]

  return (
    <div className="search-count">
      <span aria-hidden="true"><Mixed text={`${total} 条结果`} size="var(--fs-13)" color="var(--ink2)" /></span>
      <Seg label="排序" options={options} />
    </div>
  )
}

// R-4.7 分页「上一页 · n / m · 下一页」（画布 pager()）
function Pager({ q, committedQuery, filters, page, pages }: { q: string; committedQuery: string; filters: Filters; page: number; pages: number }) {
  const pageFor = (target: number) => q === committedQuery ? target : 1

  return (
    <nav className="search-pager" aria-label="分页">
      <Ctrl href={page > 1 ? hrefOf(q, filters, pageFor(page - 1)) : null} label="上一页" icon="chevron-left" side="left" />
      <span className="search-page">
        {page} / {pages}
      </span>
      <Ctrl href={page < pages ? hrefOf(q, filters, pageFor(page + 1)) : null} label="下一页" icon="chevron-right" side="right" />
    </nav>
  )
}

function statusText({ state, q, total }: SearchShowProps) {
  switch (state) {
    case 'results': return `${total} 条结果`
    case 'empty': return COPY.empty(q)
    case 'limited': return COPY.limited
    case 'unavailable': return COPY.unavailable
    case 'unsupported': return COPY.unsupported
    case 'initial': return ''
  }
}

function Body(props: SearchShowProps & { navigationQuery: string; onModifyQuery: () => void; loading: boolean }) {
  const { state, q, filters, results, total, page, pages, latest_daily_key, latest_daily_label } = props

  switch (state) {
    case 'initial':
      // 画布 search_states() 的 initial：只有一个入口，指向最新一期日刊
      return latest_daily_key ? (
        <div className="search-entry">
          <Link className="t" href={dailyHref(latest_daily_key)}>
            <Mixed text={`最新日刊 · ${latest_daily_label ?? latest_daily_key}`} size="var(--fs-15)" color="var(--ink)" />
          </Link>
        </div>
      ) : null
    case 'empty':
      return (
        <div className="search-notice-action">
          {hasActiveFilters(filters) ? (
            <Ctrl href={searchHref({ q: props.navigationQuery })} label="清除筛选" icon="x" side="left" />
          ) : (
            <button type="button" className="ctrl" onClick={props.onModifyQuery}>修改关键词</button>
          )}
        </div>
      )
    case 'unsupported':
      return <div className="search-notice-action"><button type="button" className="ctrl" onClick={props.onModifyQuery}>修改关键词</button></div>
    case 'limited':
    case 'unavailable':
      return (
        <div className="search-notice-action">
          <button type="button" className="ctrl" disabled={props.loading} onClick={() => router.get(hrefOf(props.navigationQuery, filters, props.navigationQuery === q ? page : 1))}>重试</button>
        </div>
      )
    case 'results':
      return (
        <>
          <CountLine total={total} q={props.navigationQuery} filters={filters} />
          <div className="search-results">
            {results.map((result) => (
              <SearchResultRow key={result.item_id} result={result} q={q} />
            ))}
          </div>
          {pages > 1 ? <Pager q={props.navigationQuery} committedQuery={q} filters={filters} page={page} pages={pages} /> : null}
        </>
      )
  }
}

export default function Show(props: SearchShowProps) {
  const { url: navigationUrl } = usePage<SearchShowProps>()
  const [draft, setDraft] = useState(props.q)
  const [loading, setLoading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => setDraft(props.q), [navigationUrl, props.q])
  useEffect(() => {
    const removeStart = router.on('start', () => setLoading(true))
    const removeFinish = router.on('finish', () => setLoading(false))
    return () => {
      removeStart()
      removeFinish()
    }
  }, [])

  function modifyQuery() {
    inputRef.current?.focus()
    inputRef.current?.select()
  }

  const liveText = loading ? '正在搜索…' : statusText(props)
  const notice = !['initial', 'results'].includes(props.state)
  const unsupported = props.state === 'unsupported' && draft === props.q && !loading
  const navigationQuery = draft.trim()

  return (
    <>
      <Head title={props.q ? `搜索 · ${props.q}` : '搜索'} />
      {/* PRD 6.4 标题层级：这一页的 h1 是页名「搜索」（PRD 6.2），只给读屏器，视觉上期头本身就是标题；结果标题是 h2 */}
      <h1 className="sr-only">搜索</h1>
      <SearchHead draft={draft} setDraft={setDraft} filters={props.filters} truncated={props.truncated} inputRef={inputRef} loading={loading} unsupported={unsupported} />
      <SearchFilters q={navigationQuery} filters={props.filters} sourceOptions={props.source_options} datePresets={props.date_presets} />
      <div id="search-status" className={loading ? 'search-loading' : notice ? 'search-notice state-line' : 'sr-only'} role="status" aria-live="polite" aria-atomic="true">{liveText}</div>
      <Body {...props} navigationQuery={navigationQuery} onModifyQuery={modifyQuery} loading={loading} />
    </>
  )
}

// 持久布局（application.tsx）：页脚要的字段从 props 来，跟 Daily/Show 同一种写法
function SearchLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<SearchShowProps>().props

  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}

Show.layout = (page: React.ReactNode) => <SearchLayout>{page}</SearchLayout>
