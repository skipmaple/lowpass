import { router } from '@inertiajs/react'
import { useEffect, useRef, useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import Seg from '@/components/Seg'
import { searchHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { DatePresets, Publication, SearchFilters as Filters, SearchSourceOption } from '@/types/lowpass'

// 筛选栏（R-4.4、画布 filters()）：刊物分段、来源描边小签多选（含停用的源）、日期分段加自定义的两个日期框。
// 筛选全在地址里（AC-4.7）：分段是链接，小签与日期框改值后发一次 Inertia 访问；改筛选页码归 1。
// 日期预设的首尾由服务端按上海时区算好（date_presets），页面只拿它拼链接。

export type SearchFiltersProps = { q: string; filters: Filters; sourceOptions: SearchSourceOption[]; datePresets: DatePresets }

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

function SourceChips({ q, filters, sourceOptions }: Omit<SearchFiltersProps, 'datePresets'>) {
  return (
    <span className="chips" role="group" aria-label="来源">
      {sourceOptions.map((source) => {
        const on = filters.sources.includes(source.id)
        const sources = on ? filters.sources.filter((id) => id !== source.id) : [...filters.sources, source.id]
        return (
          <button
            key={source.id}
            type="button"
            className={on ? 'chip-outline chip-on' : 'chip-outline'}
            aria-pressed={on}
            onClick={() => router.get(hrefWith(q, filters, { sources }), {}, { preserveState: true })}
          >
            <Mixed text={source.name} font="latin" size="var(--fs-12)" color={on ? 'var(--paper)' : 'var(--ink2)'} nowrap />
          </button>
        )
      })}
    </span>
  )
}

function DateRange({ q, filters, datePresets }: Omit<SearchFiltersProps, 'sourceOptions'>) {
  const options = [
    { label: '近 7 天', href: hrefWith(q, filters, { range: '7d', from: datePresets['7d'].from, to: datePresets['7d'].to }), active: filters.range === '7d', preserveState: true },
    { label: '近 30 天', href: hrefWith(q, filters, { range: '30d', from: datePresets['30d'].from, to: datePresets['30d'].to }), active: filters.range === '30d', preserveState: true },
    { label: '全部', href: hrefWith(q, filters, { range: 'all', from: null, to: null }), active: filters.range === 'all', preserveState: true },
    { label: '自定义', href: hrefWith(q, filters, { range: 'custom' }), active: filters.range === 'custom', preserveState: true },
  ]

  function change(patch: Partial<Filters>) {
    router.get(hrefWith(q, filters, { range: 'custom', ...patch }), {}, { preserveState: true })
  }

  return (
    <div className="filter-row date-range">
      <Seg label="日期" options={options} />
      {filters.range === 'custom' ? (
        <div className="filter-row">
          <DateField label="起始日期" value={filters.from} onCommit={(from) => change({ from })} />
          <span className="date-sep">至</span>
          <DateField label="结束日期" value={filters.to} onCommit={(to) => change({ to })} />
        </div>
      ) : null}
    </div>
  )
}

// 日期框：本地草稿，停手、失焦或回车才提交。不能每改一次就访问、再按值换 key 重挂——那样键盘按一下
// 方向键或打一个数字，输入框就被换掉、焦点掉到 body；逐位打年份时还会先把 0002 这样的中间值发出去。
// 前进后退时页面组件不重挂，草稿跟着 props 走。
const COMMIT_DELAY_MS = 600

function DateField({ label, value, onCommit }: { label: string; value: string | null; onCommit: (value: string | null) => void }) {
  const [draft, setDraft] = useState(value ?? '')
  const timer = useRef<number | undefined>(undefined)

  useEffect(() => setDraft(value ?? ''), [value])
  useEffect(() => () => window.clearTimeout(timer.current), [])

  function commit(next: string) {
    window.clearTimeout(timer.current)
    if (next !== (value ?? '') && complete(next)) onCommit(next || null)
  }

  function edit(next: string) {
    setDraft(next)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => commit(next), COMMIT_DELAY_MS)
  }

  return (
    <input
      type="date"
      className="date-field"
      aria-label={label}
      value={draft}
      onChange={(event) => edit(event.target.value)}
      onBlur={() => commit(draft)}
      onKeyDown={(event) => { if (event.key === 'Enter') commit(draft) }}
    />
  )
}

// 逐位输入年份时日期框会先报出 0002、0020、0202：年份不满四位就还没打完，不提交
function complete(value: string): boolean {
  return value === '' || Number(value.slice(0, 4)) >= 1000
}

export default function SearchFilters({ q, filters, sourceOptions, datePresets }: SearchFiltersProps) {
  const [mobile, setMobile] = useState(() => typeof window !== 'undefined' && window.matchMedia?.('(max-width: 480px)').matches === true)
  const [open, setOpen] = useState(false)
  const toggleRef = useRef<HTMLButtonElement>(null)
  const contentRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const media = window.matchMedia?.('(max-width: 480px)')
    if (!media) return
    const change = (event: MediaQueryListEvent) => setMobile(event.matches)
    media.addEventListener('change', change)
    return () => media.removeEventListener('change', change)
  }, [])

  const summary = filterSummary(filters, sourceOptions)

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
            options={TYPES.map((type) => ({ label: type.label, href: hrefWith(q, filters, { type: type.value }), active: filters.type === type.value, preserveState: true }))}
          />
        </Group>
        <Group label="来源">
          <SourceChips q={q} filters={filters} sourceOptions={sourceOptions} />
        </Group>
        <Group label="日期">
          <DateRange q={q} filters={filters} datePresets={datePresets} />
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
