import ReadingDirectory from '@/components/ReadingDirectory'
import { Mixed } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

const STATE_LINES: Record<SourceSummary['state'], string | null> = {
  ok: null,
  pending: null,
  failed: '抓取失败',
  empty: '本期无新内容',
  no_backfill: '无法回填',
}

export default function SourceDirectory({ sources, navigable }: { sources: SourceSummary[]; navigable: boolean }) {
  const entries = sources.map((source) => {
    const label = (
      <>
        <Mixed text={source.name} font="latin" size="inherit" color="inherit" weight={500} />
        {STATE_LINES[source.state] ? <span className="source-link-state">{STATE_LINES[source.state]}</span> : null}
      </>
    )

    // 期级事实替代正文时仍保留来源状态，但不暴露没有落点的链接。
    return navigable ? (
      <a key={source.id} className="source-link" href={`#source-${source.id}`}>{label}</a>
    ) : (
      <div key={source.id} className="source-link" role="listitem">{label}</div>
    )
  })

  if (!navigable) return <div className="source-facts" role="list" aria-label="来源">{entries}</div>

  return (
    <ReadingDirectory id="source-directory" label="来源目录" className="source-directory source-tabs-frame">
      {/* 保留原生 hash 历史；选源后不收起，避免目录高度变化推移落点。 */}
      <nav id="source-directory" className="source-links" aria-label="来源" tabIndex={-1}>{entries}</nav>
    </ReadingDirectory>
  )
}

export function openSourceDirectory() {
  const nav = document.getElementById('source-directory')
  const details = nav?.closest('details')
  if (details) details.open = true
  nav?.focus({ preventScroll: true })
}
