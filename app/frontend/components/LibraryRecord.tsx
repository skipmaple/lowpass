import { forwardRef, useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'

export type LibraryRecordProps = {
  id: string
  rank: number
  title: React.ReactNode
  href: string
  lang?: string
  onOpen?: () => void
  meta: React.ReactNode
  summary?: React.ReactNode
  detail?: React.ReactNode
  detailTitle?: string
  actions: React.ReactNode
}

// One record and one set of controls; CSS changes the editorial composition.
// B pairs its identity with original context, A uses a margin index, C keeps a quiet list.
const LibraryRecord = forwardRef<HTMLElement, LibraryRecordProps>(function LibraryRecord({ id, rank, title, href, lang, onOpen, meta, summary, detail, detailTitle = '原文线索', actions }, ref) {
  const [expanded, setExpanded] = useState(() => typeof document !== 'undefined' && document.documentElement.dataset.theme === 'duet' && window.matchMedia?.('(min-width: 961px)').matches === true)

  return (
    <article ref={ref} id={id} className="search-row library-record" data-has-detail={Boolean(detail)} data-reading-anchor>
      <div className="record-copy">
        <h2 className="search-title record-title"><a className="t" href={href} target="_blank" rel="noopener noreferrer" aria-describedby="new-tab-description" onClick={onOpen} lang={lang}>{title}</a></h2>
        <div className="search-eyebrow record-meta">{meta}</div>
        {summary ? <div className="record-purpose">{summary}</div> : null}
      </div>
      <div className="record-rail" aria-hidden="true"><span>{String(rank).padStart(2, '0')}</span></div>
      {detail ? (
        <details className="record-detail" open={expanded} onToggle={(event) => setExpanded(event.currentTarget.open)}>
          <summary>{detailTitle}<Icon name="chevron-right" size={16} /></summary>
          <div className="record-detail-content">{detail}</div>
        </details>
      ) : null}
      <div className="search-links record-actions">{actions}</div>
    </article>
  )
})

export default LibraryRecord
