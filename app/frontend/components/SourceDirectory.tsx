import { SourceMark } from '@/components/Illustration'
import { Mixed } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

const STATE_LINES: Record<SourceSummary['state'], string | null> = {
  ok: null,
  pending: null,
  failed: '抓取失败',
  empty: '本期无新内容',
  no_backfill: '无法回填',
}

export default function SourceDirectory({ sources }: { sources: SourceSummary[] }) {
  return (
    <div className="source-tabs-frame">
      <nav id="source-directory" className="source-tabs" aria-label="来源" tabIndex={-1}>
        {/* 原生 hash 导航建立独立历史，Inertia 的 popstate 负责同步 URL；router.push 会把纯 hash 变化替换掉。 */}
        {sources.map((source) => (
          <a key={source.id} className="source-tab" data-state="inactive" href={`#source-${source.id}`}>
            <SourceMark adapter={source.adapter} hole="var(--paper)" className="source-tab-icon" />
            <span className="source-tab-body">
              <span className="source-tab-name"><Mixed text={source.name} font="latin" size="inherit" color="inherit" weight={600} lineHeight={1.2} /></span>
              {STATE_LINES[source.state] ? <span className="source-tab-state">{STATE_LINES[source.state]}</span> : null}
            </span>
          </a>
        ))}
      </nav>
    </div>
  )
}
