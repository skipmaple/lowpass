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
  const entries = sources.map((source, index) => {
    const label = (
      <>
        <span className="source-tab-number" aria-hidden="true">{String(index + 1).padStart(2, '0')}</span>
        <span className="source-tab-body">
          <span className="source-tab-name"><Mixed text={source.name} font="latin" size="inherit" color="inherit" weight={600} lineHeight={1.2} /></span>
          {STATE_LINES[source.state] ? <span className="source-tab-state">{STATE_LINES[source.state]}</span> : null}
        </span>
      </>
    )

    // 期级事实替代正文时仍保留来源状态，但不暴露没有落点的链接。
    return navigable ? (
      <a key={source.id} className="source-tab" data-adapter={source.adapter} data-state="inactive" href={`#source-${source.id}`}>{label}</a>
    ) : (
      <div key={source.id} className="source-tab" data-adapter={source.adapter} role="listitem">{label}</div>
    )
  })

  return (
    <div className="source-tabs-frame">
      {navigable ? (
        // 原生 hash 导航建立独立历史，Inertia 的 popstate 负责同步 URL。
        <nav id="source-directory" className="source-tabs" aria-label="来源" tabIndex={-1}>{entries}</nav>
      ) : (
        <div id="source-directory" className="source-tabs" role="list" aria-label="来源">{entries}</div>
      )}
    </div>
  )
}
