import { router } from '@inertiajs/react'
import { useLayoutEffect, useRef, type PropsWithChildren } from 'react'

import { SourceMark } from '@/components/Illustration'
import { Mixed } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

export default function DailySourceSection({ source, children, animate, aliasId, ordinal = 1 }: PropsWithChildren<{ source: SourceSummary; animate: boolean; aliasId?: string; ordinal?: number }>) {
  const sectionRef = useRef<HTMLElement>(null)
  const headingId = `source-heading-${source.id}`

  useLayoutEffect(() => {
    const section = sectionRef.current
    if (!animate || !section) return
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)')
    let disabled = reduced?.matches === true
    let scrollFrame = 0
    const hash = window.location.hash.slice(1)
    let locatingItem = !window.history.state?.documentScrollPosition && hash.startsWith('item-') && section.contains(document.getElementById(hash))

    function measure() {
      if (disabled) {
        clear()
      } else {
        // 外层不位移，标题、细线与正文在内部作为同一纸面接入。
        const top = section!.getBoundingClientRect().top
        const height = window.innerHeight
        // 浏览器按变换后的条目坐标定位；深链先完整展开，避免落定时又向上偏移一段。
        // 栏目到达阅读区后恢复常规进度，上滑仍可自然回退。
        if (locatingItem && top <= height * 0.65) locatingItem = false
        const content = section!.querySelector<HTMLElement>('.daily-source-content')!
        // 短栏与异常事实直接完整展示，不能为过渡裁掉已在视口里的正文或焦点。
        const canOpen = source.state === 'ok' && content.offsetHeight >= height * 0.75
        const position = Math.max(0, Math.min(1, (height * 0.95 - top) / (height * 0.3)))
        // 空间曲线让起止速度平顺；首条进入主要阅读区前已落定，不按时间追赶。
        const progress = canOpen && !locatingItem ? position * position * (3 - 2 * position) : 1
        section!.dataset.scrollSource = ''
        section!.toggleAttribute('data-source-opening', progress < 1)
        section!.style.setProperty('--source-progress', String(progress))
      }
    }
    function scroll() {
      if (scrollFrame) return
      scrollFrame = requestAnimationFrame(() => { scrollFrame = 0; measure() })
    }
    function clear() {
      delete section!.dataset.scrollSource
      delete section!.dataset.sourceOpening
      section!.style.removeProperty('--source-progress')
    }
    function reduce(event: MediaQueryListEvent) {
      disabled = event.matches
      measure()
    }
    // 首次定位、刷新与历史恢复也直接采用当前位置，不启动时间动画。
    measure()
    window.addEventListener('scroll', scroll, { passive: true })
    window.addEventListener('resize', scroll)
    reduced?.addEventListener?.('change', reduce)
    // Inertia 在 navigate 前排入恢复位置的 RAF；在它之后测量，不假设一定产生 scroll 事件。
    const stopNavigate = router.on('navigate', scroll)
    return () => {
      cancelAnimationFrame(scrollFrame)
      window.removeEventListener('scroll', scroll)
      window.removeEventListener('resize', scroll)
      reduced?.removeEventListener?.('change', reduce)
      stopNavigate()
      clear()
    }
  }, [animate, source.id, source.state])

  return (
    <section ref={sectionRef} id={`source-${source.id}`} className="daily-source print-source" data-adapter={source.adapter} aria-labelledby={headingId} tabIndex={-1}>
      <div className="daily-source-sheet">
        <header className="daily-source-head">
          {aliasId ? <span id={aliasId} className="daily-source-anchor" aria-hidden="true" /> : null}
          <div className="daily-source-heading">
            <span className="daily-source-number" aria-hidden="true">{String(ordinal).padStart(2, '0')}</span>
            <h2 id={headingId} className="print-source-name">
              <Mixed text={source.name} font="latin" size="inherit" color="inherit" weight={600} lineHeight={1.2} />
            </h2>
          </div>
          <SourceMark adapter={source.adapter} hole="var(--paper)" className="daily-source-icon" />
          <span className="daily-source-rule" aria-hidden="true" />
        </header>
        <div className="daily-source-content">{children}</div>
      </div>
    </section>
  )
}
