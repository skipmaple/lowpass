import { router } from '@inertiajs/react'
import { SourceMark } from '@/components/Illustration'
import { focusMain } from '@/lib/navigationFocus'
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
      <nav id="source-directory" className="source-tabs" aria-label="来源">
        {sources.map((source) => (
          <a key={source.id} className="source-tab" data-state="inactive" href={`#source-${source.id}`} onClick={(event) => {
            if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
            event.preventDefault()
            // 同步 Inertia 历史里的 URL；后续收藏写回页面 props 不会把 hash 覆盖掉。
            router.push({ url: event.currentTarget.href, preserveState: true, preserveScroll: false, onSuccess: () => focusMain(`#source-${source.id}`) })
          }}>
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
