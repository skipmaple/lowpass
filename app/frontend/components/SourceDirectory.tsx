import type * as React from 'react'

import { latinLang } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

const STATE_LINES: Record<SourceSummary['state'], string | null> = {
  ok: null,
  pending: null,
  failed: '抓取失败',
  empty: '本期未收录',
  no_backfill: '无法回填',
}

type SourceDirectoryProps = {
  sources: SourceSummary[]
  navigable: boolean
  activeId?: string
  onSelect?: (event: React.MouseEvent<HTMLAnchorElement>, id: string) => void
}

// 三主题共享原生来源锚点；没有正文时只显示事实，不制造无落点的导航。
export default function SourceDirectory({ sources, navigable, activeId, onSelect }: SourceDirectoryProps) {
  const entries = sources.map((source) => {
    const label = <>
      <span className="source-tab-name" lang={latinLang(source.name)}>{source.name}</span>
      {STATE_LINES[source.state] ? <span className="source-tab-state">{STATE_LINES[source.state]}</span> : null}
    </>
    return navigable ? (
      <a key={source.id} className="source-tab source-link" href={`#source-${source.id}`}
        aria-current={source.id === activeId ? 'location' : undefined}
        data-source-state={source.state} data-state={source.id === activeId ? 'active' : 'inactive'}
        onClick={(event) => onSelect?.(event, source.id)}>{label}</a>
    ) : <div key={source.id} className="source-tab" role="listitem" data-source-state={source.state}>{label}</div>
  })

  return <div className="source-tabs-frame">
    {navigable ? <nav id="source-directory" className="source-tabs" aria-label="本期来源" tabIndex={-1}>{entries}</nav>
      : <div className="source-tabs source-facts" role="list" aria-label="来源">{entries}</div>}
  </div>
}

export function openSourceDirectory() {
  document.getElementById('source-directory')?.focus({ preventScroll: true })
}
