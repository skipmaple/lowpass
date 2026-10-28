import { router, usePage } from '@inertiajs/react'
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import Seg from '@/components/Seg'
import { searchHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { DatePresets, Publication, SearchFilters as Filters, SearchSourceOption } from '@/types/lowpass'

// 筛选栏（R-4.4、画布 filters()）：刊物分段、来源描边小签多选（含停用的源）、日期分段加自定义的两个日期框。
// 筛选全在地址里（AC-4.7）：分段是链接，小签与日期框改值后发一次 Inertia 访问；改筛选页码归 1。
// 日期预设的首尾由服务端按上海时区算好（date_presets），页面只拿它拼链接。

export type SearchFiltersProps = { q: string; draft: FilterDraft; sourceOptions: SearchSourceOption[]; datePresets: DatePresets }

export function hasActiveFilters(filters: Filters): boolean {
  return filters.type !== null || filters.sources.length > 0 || filters.from !== null || filters.to !== null
}

// 当前筛选换掉几项之后的地址（页码归 1）
export function hrefWith(q: string, filters: Filters, patch: Partial<Filters>): string {
  const next = { ...filters, ...patch }
  return searchHref({ q, type: next.type, source: next.sources, from: next.from, to: next.to, range: next.range, sort: next.sort })
}

function Group({ label, children }: React.PropsWithChildren<{ label: string }>) {
  return (
    <div className="filter-group">
      <span className="filter-label">{label}</span>
      {children}
    </div>
  )
}

const TYPES: { label: string; value: Publication | null }[] = [
  { label: '全部', value: null },
  { label: '日刊', value: 'daily' },
  { label: '周刊', value: 'weekly' },
]

type DateEnd = 'from' | 'to'
type DateDrafts = Record<DateEnd, string>
type FilterPatch = Partial<Filters> | ((current: Filters) => Partial<Filters>)
type PendingFilterVisit = { href: string; filters: Filters; edits: Record<DateEnd, number> }

function dateValues(filters: Filters): DateDrafts {
  return { from: filters.from ?? '', to: filters.to ?? '' }
}

// props 是已确认条件；target 是读者接连提交的目标，不能在下一次响应前又从旧 props 拼地址。
// 日期的未提交文字另存：服务端归一化旧提交时，只接收尚未继续编辑的字段。
export function useFilterDraft(q: string, filters: Filters) {
  const { url } = usePage()
  const canonicalKey = JSON.stringify([url.split('#')[0], hrefWith('', filters, {})])
  const observedCanonical = useRef(canonicalKey)
  const canonical = useRef(filters)
  const target = useRef(filters)
  const [pending, setPending] = useState(filters)
  const dates = useRef(dateValues(filters))
  const [dateDrafts, setDateDrafts] = useState(dates.current)
  const edits = useRef({ from: 0, to: 0 })
  const request = useRef<PendingFilterVisit | null>(null)
  const [resetVersion, setResetVersion] = useState(0)

  useLayoutEffect(() => {
    if (observedCanonical.current !== canonicalKey) {
      observedCanonical.current = canonicalKey
      canonical.current = filters
      // 自己的响应由 onSuccess 确认，那里还持有提交时的编辑版本；外部导航直接回到 canonical。
      if (!request.current) {
        publish(filters)
        dates.current = dateValues(filters)
        setDateDrafts(dates.current)
        setResetVersion((version) => version + 1)
      }
    }
  }, [canonicalKey, filters])

  useEffect(() => () => { request.current = null }, [])

  function publish(filters: Filters) {
    target.current = filters
    setPending(filters)
  }

  function change(patch: FilterPatch) {
    const changes = typeof patch === 'function' ? patch(target.current) : patch
    const next = { ...target.current, ...changes }
    const href = hrefWith(q, next, {})
    if (request.current?.href === href) return

    publish(next)
    // 选择日期预设后立刻切回自定义，也要显示同一份目标；单框提交只改自己那一端。
    if ('from' in changes || 'to' in changes) {
      dates.current = { ...dates.current }
      for (const end of ['from', 'to'] as const) {
        if (end in changes) dates.current[end] = changes[end] ?? ''
      }
      setDateDrafts(dates.current)
    }
    const visit = { href, filters: next, edits: { ...edits.current } }
    // 先换身份：router.get 会同步取消前次请求，其 finish 不得解除这次访问的去重。
    request.current = visit
    router.get(href, {}, {
      preserveState: true,
      onSuccess: (page) => {
        if (request.current !== visit || page.component !== 'Search/Show') return
        const accepted = page.props.filters as Filters
        canonical.current = accepted
        publish(accepted)
        const acceptedDates = { ...dates.current }
        for (const end of ['from', 'to'] as const) {
          if (edits.current[end] === visit.edits[end] && dates.current[end] === (visit.filters[end] ?? '')) {
            acceptedDates[end] = accepted[end] ?? ''
          }
        }
        dates.current = acceptedDates
        setDateDrafts(acceptedDates)
      },
      // 失败保留目标和草稿；仅解除本次去重，下一次失焦或回车仍可重试。
      onFinish: () => { if (request.current === visit) request.current = null },
    })
  }

  function editDate(end: DateEnd, value: string) {
    edits.current[end] += 1
    dates.current = { ...dates.current, [end]: value }
    setDateDrafts(dates.current)
  }

  function commitDate(end: DateEnd, value: string | null) {
    if (value !== target.current[end] || value !== canonical.current[end]) {
      change({ range: 'custom', [end]: value })
    }
  }

  return { filters: pending, dates: dateDrafts, resetVersion, change, editDate, commitDate }
}

export type FilterDraft = ReturnType<typeof useFilterDraft>

function SourceChips({ draft, sourceOptions }: { draft: FilterDraft; sourceOptions: SearchSourceOption[] }) {
  const { filters } = draft

  function toggle(id: string) {
    draft.change((current) => ({ sources: current.sources.includes(id) ? current.sources.filter((source) => source !== id) : [...current.sources, id] }))
  }

  return (
    <span className="chips" role="group" aria-label="来源">
      {sourceOptions.map((source) => {
        const on = filters.sources.includes(source.id)
        return (
          <button
            key={source.id}
            type="button"
            className={on ? 'chip-outline chip-on' : 'chip-outline'}
            aria-pressed={on}
            onClick={() => toggle(source.id)}
          >
            <Mixed text={source.name} font="latin" size="var(--fs-12)" color={on ? 'var(--paper)' : 'var(--ink2)'} />
          </button>
        )
      })}
    </span>
  )
}

function DateRange({ q, draft, datePresets }: { q: string; draft: FilterDraft; datePresets: DatePresets }) {
  const { filters } = draft
  function option(label: string, patch: Partial<Filters>) {
    return { label, href: hrefWith(q, filters, patch), active: filters.range === patch.range, preserveState: true, onBefore: () => { draft.change(patch); return false } }
  }
  const options = [
    option('近 7 天', { range: '7d', from: datePresets['7d'].from, to: datePresets['7d'].to }),
    option('近 30 天', { range: '30d', from: datePresets['30d'].from, to: datePresets['30d'].to }),
    option('全部', { range: 'all', from: null, to: null }),
    option('自定义', { range: 'custom' }),
  ]

  return (
    <div className="filter-row date-range">
      <Seg label="日期" options={options} />
      {filters.range === 'custom' ? (
        <div className="filter-row">
          <DateField label="起始日期" value={draft.dates.from} resetVersion={draft.resetVersion} onEdit={(value) => draft.editDate('from', value)} onCommit={(value) => draft.commitDate('from', value)} />
          <span className="date-sep">至</span>
          <DateField label="结束日期" value={draft.dates.to} resetVersion={draft.resetVersion} onEdit={(value) => draft.editDate('to', value)} onCommit={(value) => draft.commitDate('to', value)} />
        </div>
      ) : null}
    </div>
  )
}

// 日期框：本地草稿，停手、失焦或回车才提交。不能每改一次就访问、再按值换 key 重挂——那样键盘按一下
// 方向键或打一个数字，输入框就被换掉、焦点掉到 body；逐位打年份时还会先把 0002 这样的中间值发出去。
// 外部导航恢复 canonical 草稿并撤销计时器；正常提交保留同一输入节点与焦点。
const COMMIT_DELAY_MS = 600

function DateField({ label, value, resetVersion, onEdit, onCommit }: { label: string; value: string; resetVersion: number; onEdit: (value: string) => void; onCommit: (value: string | null) => void }) {
  const timer = useRef<number | undefined>(undefined)
  const commitLatest = useRef(onCommit)
  commitLatest.current = onCommit

  useEffect(() => { window.clearTimeout(timer.current) }, [resetVersion])
  useEffect(() => () => window.clearTimeout(timer.current), [])

  function commit(next: string) {
    window.clearTimeout(timer.current)
    if (complete(next)) commitLatest.current(next || null)
  }

  function edit(next: string) {
    onEdit(next)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => commit(next), COMMIT_DELAY_MS)
  }

  return (
    <input
      type="date"
      className="date-field"
      aria-label={label}
      value={value}
      onChange={(event) => edit(event.target.value)}
      onBlur={() => commit(value)}
      onKeyDown={(event) => { if (event.key === 'Enter') commit(value) }}
    />
  )
}

// 逐位输入年份时日期框会先报出 0002、0020、0202：年份不满四位就还没打完，不提交
function complete(value: string): boolean {
  return value === '' || Number(value.slice(0, 4)) >= 1000
}

export default function SearchFilters({ q, draft, sourceOptions, datePresets }: SearchFiltersProps) {
  const [mobile, setMobile] = useState(() => typeof window !== 'undefined' && window.matchMedia?.('(max-width: 480px)').matches === true)
  const [open, setOpen] = useState(false)
  const toggleRef = useRef<HTMLButtonElement>(null)
  const contentRef = useRef<HTMLDivElement>(null)
  const renderedMobile = useRef(mobile)
  const pendingFocus = useRef<Element | null>(null)

  useEffect(() => {
    const media = window.matchMedia?.('(max-width: 480px)')
    if (!media) return
    const change = (event: MediaQueryListEvent) => {
      const active = document.activeElement
      const hidesContent = event.matches && !open && contentRef.current?.contains(active)
      const removesToggle = !event.matches && active === toggleRef.current
      pendingFocus.current = event.matches !== renderedMobile.current && (hidesContent || removesToggle) ? active : null
      setMobile(event.matches)
    }
    media.addEventListener('change', change)
    return () => media.removeEventListener('change', change)
  }, [open])

  // 新按钮挂上或旧按钮卸下后再交接；仍可见的控件与读者新移走的焦点不动。
  useLayoutEffect(() => {
    renderedMobile.current = mobile
    const from = pendingFocus.current
    pendingFocus.current = null
    if (from && (document.activeElement === from || document.activeElement === document.body)) {
      const target = mobile ? toggleRef.current : contentRef.current?.querySelector<HTMLElement>('a[href], button:not([disabled]), input:not([disabled])')
      target?.focus()
    }
  }, [mobile])

  const summary = filterSummary(draft.filters, sourceOptions)

  function toggle() {
    if (open && contentRef.current?.contains(document.activeElement)) toggleRef.current?.focus()
    setOpen((value) => !value)
  }

  return (
    <div className="filters-shell">
      {mobile ? (
        <button ref={toggleRef} type="button" className="filter-toggle" aria-expanded={open} aria-controls="search-advanced-filters" onClick={toggle}>
          <Mixed text={summary} size="var(--fs-15)" color="var(--ink)" />
          <span className="filter-toggle-icon" data-open={open || undefined}><Icon name="chevron-right" size={18} /></span>
        </button>
      ) : null}
      <div ref={contentRef} id="search-advanced-filters" className="filters" hidden={mobile && !open}>
        <Group label="刊物">
          <Seg
            label="刊物"
            options={TYPES.map((type) => ({ label: type.label, href: hrefWith(q, draft.filters, { type: type.value }), active: draft.filters.type === type.value, preserveState: true, onBefore: () => { draft.change({ type: type.value }); return false } }))}
          />
        </Group>
        <Group label="来源">
          <SourceChips draft={draft} sourceOptions={sourceOptions} />
        </Group>
        <Group label="日期">
          <DateRange q={q} draft={draft} datePresets={datePresets} />
        </Group>
      </div>
    </div>
  )
}

function filterSummary(filters: Filters, sourceOptions: SearchSourceOption[]): string {
  const parts: string[] = []
  if (filters.type) parts.push(filters.type === 'daily' ? '日刊' : '周刊')
  for (const id of filters.sources) parts.push(sourceOptions.find((source) => source.id === id)?.name ?? id)
  if (filters.range === '7d') parts.push('近 7 天')
  if (filters.range === '30d') parts.push('近 30 天')
  if (filters.range === 'custom' && (filters.from || filters.to)) parts.push('自定义日期')
  return `筛选：${parts.length > 0 ? parts.join(' · ') : '全部'}`
}
