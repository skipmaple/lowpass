import { router } from '@inertiajs/react'
import type * as React from 'react'

import Seg from '@/components/Seg'
import { searchHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { DatePresets, Publication, SearchFilters as Filters, SearchSourceOption } from '@/types/lowpass'

// 筛选栏（R-4.4、画布 filters()）：刊物分段、来源描边小签多选（含停用的源）、日期分段加自定义的两个日期框。
// 筛选全在地址里（AC-4.7）：分段是链接，小签与日期框改值后发一次 Inertia 访问；改筛选页码归 1。
// 日期预设的首尾由服务端按上海时区算好（date_presets），页面只拿它拼链接。

export type SearchFiltersProps = { q: string; filters: Filters; sourceOptions: SearchSourceOption[]; datePresets: DatePresets }

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
            onClick={() => router.get(hrefWith(q, filters, { sources }))}
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
    { label: '近 7 天', href: hrefWith(q, filters, { range: '7d', from: datePresets['7d'].from, to: datePresets['7d'].to }), active: filters.range === '7d' },
    { label: '近 30 天', href: hrefWith(q, filters, { range: '30d', from: datePresets['30d'].from, to: datePresets['30d'].to }), active: filters.range === '30d' },
    { label: '全部', href: hrefWith(q, filters, { range: 'all', from: null, to: null }), active: filters.range === 'all' },
    { label: '自定义', href: hrefWith(q, filters, { range: 'custom' }), active: filters.range === 'custom' },
  ]

  function change(patch: Partial<Filters>) {
    router.get(hrefWith(q, filters, { range: 'custom', ...patch }))
  }

  return (
    <span className="filter-row">
      <Seg label="日期" options={options} />
      {filters.range === 'custom' ? (
        <span className="filter-row">
          <input type="date" className="date-field" aria-label="起始日期" defaultValue={filters.from ?? ''} onChange={(e) => change({ from: e.target.value || null })} />
          <span className="date-sep">至</span>
          <input type="date" className="date-field" aria-label="结束日期" defaultValue={filters.to ?? ''} onChange={(e) => change({ to: e.target.value || null })} />
        </span>
      ) : null}
    </span>
  )
}

export default function SearchFilters({ q, filters, sourceOptions, datePresets }: SearchFiltersProps) {
  return (
    <div className="filters">
      <Group label="刊物">
        <Seg
          label="刊物"
          options={TYPES.map((type) => ({ label: type.label, href: hrefWith(q, filters, { type: type.value }), active: filters.type === type.value }))}
        />
      </Group>
      <Group label="来源">
        <SourceChips q={q} filters={filters} sourceOptions={sourceOptions} />
      </Group>
      <Group label="日期">
        <DateRange q={q} filters={filters} datePresets={datePresets} />
      </Group>
    </div>
  )
}
