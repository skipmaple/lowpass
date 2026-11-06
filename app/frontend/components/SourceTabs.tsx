import { useEffect, useRef, useState } from 'react'
import type * as React from 'react'

import { latinLang } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

const STATE_LINES: Record<SourceSummary['state'], string | null> = {
  ok: null,
  pending: '正在收录',
  failed: '抓取失败',
  empty: '本期未收录',
  no_backfill: '无法回填',
}

export type SourceTabsProps = {
  sources: SourceSummary[]
  activeId: string
  onSelect: (id: string) => void
  children: (source: SourceSummary) => React.ReactNode
}

export const sourceSectionId = (id: string) => `source-${id}`

// 目录是页内导航，不是互相隐藏的 tabs：全部来源组成同一期连续阅读。
// 滚动只更新可见标记；只有主动选来源才写入 Inertia 的历史状态。
export default function SourceTabs({ sources, activeId, onSelect, children }: SourceTabsProps) {
  const [visibleId, setVisibleId] = useState(activeId)
  const sections = useRef<HTMLDivElement>(null)
  const initialSource = useRef(activeId)
  const positioned = useRef(false)
  const explicitSource = useRef<string | null>(null)

  useEffect(() => setVisibleId(activeId), [activeId])

  useEffect(() => {
    if (positioned.current) return
    positioned.current = true
    const firstId = sources[0]?.id
    const initial = initialSource.current
    if (initial && initial !== firstId && !window.location.hash) {
      const frame = requestAnimationFrame(() => document.getElementById(sourceSectionId(initial))?.scrollIntoView?.({ block: 'start' }))
      return () => cancelAnimationFrame(frame)
    }
  }, [sources])

  useEffect(() => {
    let frame = 0
    function update() {
      frame = 0
      if (explicitSource.current) return
      const nodes = sections.current?.querySelectorAll<HTMLElement>('[data-source-id]')
      if (!nodes?.length) return
      // 目录进入视线时归属前一节，越过顶部阅读线后交给下一节。
      let next = nodes[0].dataset.sourceId!
      for (const node of nodes) {
        if (node.getBoundingClientRect().top <= 150) next = node.dataset.sourceId!
        else break
      }
      const last = nodes[nodes.length - 1]
      if (window.scrollY > 0 && last.getBoundingClientRect().bottom <= window.innerHeight + 1) next = last.dataset.sourceId!
      setVisibleId(next)
    }
    function schedule() {
      if (!frame) frame = requestAnimationFrame(update)
    }
    function hashChanged() {
      const id = decodeURIComponent(window.location.hash.slice(1))
      const section = document.getElementById(id)?.closest<HTMLElement>('[data-source-id]')
      if (section?.dataset.sourceId) {
        explicitSource.current = section.dataset.sourceId
        setVisibleId(section.dataset.sourceId)
      } else {
        explicitSource.current = null
        schedule()
      }
    }
    // 空来源靠近页尾时无法滚到阅读线。主动导航的标记一直保留到读者自己继续滚动，
    // 避免 smooth scroll 或浏览器的底部钳制立即把它切回上一来源。
    function resumeTracking() {
      explicitSource.current = null
      schedule()
    }
    function keyScroll(event: KeyboardEvent) {
      if ((event.target as HTMLElement)?.closest?.('input,textarea,select,[contenteditable]')) return
      if (['ArrowDown', 'ArrowUp', 'PageDown', 'PageUp', 'Home', 'End', ' '].includes(event.key)) resumeTracking()
    }
    window.addEventListener('scroll', schedule, { passive: true })
    window.addEventListener('hashchange', hashChanged)
    window.addEventListener('wheel', resumeTracking, { passive: true })
    window.addEventListener('touchmove', resumeTracking, { passive: true })
    window.addEventListener('keydown', keyScroll)
    return () => {
      cancelAnimationFrame(frame)
      window.removeEventListener('scroll', schedule)
      window.removeEventListener('hashchange', hashChanged)
      window.removeEventListener('wheel', resumeTracking)
      window.removeEventListener('touchmove', resumeTracking)
      window.removeEventListener('keydown', keyScroll)
    }
  }, [sources])

  function select(event: React.MouseEvent<HTMLAnchorElement>, id: string) {
    // 让修改键、复制链接和新标签页保留原生链接行为。
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    explicitSource.current = id
    setVisibleId(id)
    onSelect(id)
    document.getElementById(sourceSectionId(id))?.scrollIntoView?.({
      block: 'start',
      behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth',
    })
  }

  return (
    <div className="source-collection">
      <div className="source-tabs-frame">
        <nav id="source-directory" className="source-tabs" aria-label="本期来源" tabIndex={-1}>
          {sources.map((source) => (
            <a
              key={source.id}
              className="source-tab"
              href={`#${sourceSectionId(source.id)}`}
              aria-current={source.id === visibleId ? 'location' : undefined}
              data-source-state={source.state}
              data-state={source.id === visibleId ? 'active' : 'inactive'}
              onClick={(event) => select(event, source.id)}
            >
              <span className="source-tab-name" lang={latinLang(source.name)}>{source.name}</span>
              {STATE_LINES[source.state] ? <span className="source-tab-state">{STATE_LINES[source.state]}</span> : null}
            </a>
          ))}
        </nav>
      </div>
      <div className="source-sections" ref={sections}>
        {sources.map((source, index) => (
          <section
            key={source.id}
            id={sourceSectionId(source.id)}
            data-source-id={source.id}
            data-source-state={source.state}
            className={`source-section${index === 0 ? ' source-section--first' : ''}`}
            aria-labelledby={`source-heading-${source.id}`}
          >
            <div className="source-section-head">
              <h2 id={`source-heading-${source.id}`} lang={latinLang(source.name)}>{source.name}</h2>
            </div>
            {children(source)}
          </section>
        ))}
      </div>
    </div>
  )
}
