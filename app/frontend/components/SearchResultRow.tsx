import { Link } from '@inertiajs/react'

import FavoriteButton from '@/components/FavoriteButton'
import HitText from '@/components/HitText'
import { Translation } from '@/components/ItemRow'
import { reportClick } from '@/lib/search'
import { markSearchResult, searchResultId } from '@/lib/searchFocus'
import { Mixed, latinLang } from '@/lib/typeset'
import type { HitRun, SearchResult } from '@/types/lowpass'

// 结果行（R-4.6）：先读标题、译文与命中片段，再看来源和所属刊期。
// 标题是唯一原文入口，点击上报一次 search_click（9.1）；所在期直链与书签组成同一操作组。

const LABELS: Record<SearchResult['publication'], string> = { daily: '日刊', weekly: '周刊' }
const runText = (runs: HitRun[]) => runs.map((run) => run.text).join('')

export default function SearchResultRow({ result, q }: { result: SearchResult; q: string }) {
  const report = () => reportClick({ item_id: result.item_id, rank: result.rank, q })

  return (
    <article className="search-row">
      <h2 className="search-title">
        <a className="t" href={result.url} target="_blank" rel="noopener noreferrer" onClick={report} lang={latinLang(runText(result.title_runs))}>
          <HitText runs={result.title_runs} size="var(--fs-20)" color="var(--ink)" />
        </a>
      </h2>
      {result.publication === 'daily' && result.title_zh ? <Translation text={result.title_zh} /> : null}

      {result.snippet_runs ? (
        <p className="search-snippet" lang={latinLang(runText(result.snippet_runs))}>
          <HitText runs={result.snippet_runs} size="var(--fs-15)" color="var(--ink2)" />
        </p>
      ) : null}
      {result.publication === 'daily' && result.snippet_runs && result.summary_zh ? <Translation text={result.summary_zh} /> : null}

      <div className="result-meta">
        <div className="result-context">
          <span>{LABELS[result.publication]}</span>
          <Mixed text={result.source_name} font="latin" size="var(--fs-13)" color="var(--ink2)" />
          {result.published_label !== result.where.label ? (
            <Mixed text={result.published_label} size="var(--fs-13)" color="var(--ink2)" />
          ) : null}
        </div>
        <div className="search-links">
          <Link id={searchResultId(result.item_id)} className="t" href={result.where.href} onBefore={() => markSearchResult(result.item_id)}>
            <Mixed text={`所在期 · ${result.where.label}`} size="var(--fs-13)" color="var(--ink)" />
          </Link>
          <FavoriteButton className="search-mark" itemId={result.item_id} urlHash={result.url_hash} title={runText(result.title_runs)} />
        </div>
      </div>
    </article>
  )
}
