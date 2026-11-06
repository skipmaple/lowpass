import { useEffect, useRef, useState } from 'react'
import type * as React from 'react'

import DailySourceSection from '@/components/DailySourceSection'
import SourceDirectory from '@/components/SourceDirectory'
import type { SourceSummary } from '@/types/lowpass'

export type SourceTabsProps = {
  sources: SourceSummary[]
  activeId?: string
  onSelect?: (id: string) => void
  fallbackAnchor?: { sourceId: string; id: string }
  children: (source: SourceSummary) => React.ReactNode
}

export const sourceSectionId = (id: string) => `source-${id}`

// 目录是页内导航，不是互相隐藏的 tabs：全部来源组成同一期连续阅读。
// 滚动只更新可见标记；主动选来源保留浏览器原生 hash 历史。
export default function SourceTabs({ sources, activeId = sources[0]?.id, onSelect, fallbackAnchor, children }: SourceTabsProps) {
  const [visibleId, setVisibleId] = useState(activeId)
  const sections = useRef<HTMLDivElement>(null)
  const explicitSource = useRef<string | null>(null)

  useEffect(() => setVisibleId(activeId), [activeId])

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
      const id = window.location.hash.slice(1)
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
    if (window.location.hash) hashChanged()
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
    explicitSource.current = id
    setVisibleId(id)
    onSelect?.(id)
  }

  return (
    <div className="source-collection">
      <SourceDirectory sources={sources} navigable activeId={visibleId} onSelect={select} />
      <div className="source-sections" ref={sections}>
        {sources.map((source, index) => (
          <DailySourceSection key={source.id} source={source} animate={index > 0} first={index === 0} aliasId={fallbackAnchor?.sourceId === source.id ? fallbackAnchor.id : undefined}>
            {children(source)}
          </DailySourceSection>
        ))}
      </div>
    </div>
  )
}
