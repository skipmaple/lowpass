import { Link } from '@inertiajs/react'

import FavoriteButton from '@/components/FavoriteButton'
import HitText from '@/components/HitText'
import Icon from '@/components/Icon'
import LibraryRecord from '@/components/LibraryRecord'
import { normalizeDateLabel } from '@/lib/displayDate'
import { reportClick } from '@/lib/search'
import { markSearchResult, searchResultId } from '@/lib/searchFocus'
import { latinLang } from '@/lib/typeset'
import type { HitRun, SearchResult } from '@/types/lowpass'

const LABELS: Record<SearchResult['publication'], string> = { daily: '日刊', weekly: '周刊' }
const runText = (runs: HitRun[]) => runs.map((run) => run.text).join('')

export default function SearchResultRow({ result, q }: { result: SearchResult; q: string }) {
  const report = () => reportClick({ item_id: result.item_id, rank: result.rank, q })
  const translatedTitleRuns = result.publication === 'daily' ? result.title_zh_runs ?? (result.title_zh ? [{ text: result.title_zh, hit: false }] : null) : null
  const translatedSummaryRuns = result.publication === 'daily' && result.snippet_runs ? result.summary_zh_runs ?? (result.summary_zh ? [{ text: result.summary_zh, hit: false }] : null) : null
  const titleRuns = translatedTitleRuns?.length ? translatedTitleRuns : result.title_runs
  const summaryRuns = translatedSummaryRuns?.length ? translatedSummaryRuns : result.snippet_runs
  const translated = titleRuns !== result.title_runs
  const originalSummary = translatedSummaryRuns?.length && result.snippet_runs
  const titleMatchInOriginal = translated && result.title_runs.some((run) => run.hit) && !titleRuns.some((run) => run.hit)
  const summaryMatchInOriginal = originalSummary && originalSummary.some((run) => run.hit) && !summaryRuns?.some((run) => run.hit)
  const detail = result.reason || (translated && !titleMatchInOriginal) || (originalSummary && !summaryMatchInOriginal)

  return (
    <LibraryRecord
      id={`result-${result.item_id}`}
      rank={result.rank}
      title={<HitText runs={titleRuns} size="inherit" color="inherit" />}
      href={result.url}
      lang={latinLang(runText(titleRuns))}
      onOpen={report}
      meta={<>
        <span>{result.source_name}</span><span>{LABELS[result.publication]}</span>
        <span>{normalizeDateLabel(result.where.label)}</span>
        {result.published_label !== result.where.label ? <span>{normalizeDateLabel(result.published_label)}</span> : null}
      </>}
      summary={summaryRuns || titleMatchInOriginal || summaryMatchInOriginal ? <>
        {summaryRuns ? <p className="search-snippet" lang={latinLang(runText(summaryRuns))}><HitText runs={summaryRuns} size="inherit" color="inherit" /></p> : null}
        {titleMatchInOriginal ? <p className="record-original-title search-match-context" lang={latinLang(runText(result.title_runs))}><HitText runs={result.title_runs} size="inherit" color="inherit" /></p> : null}
        {summaryMatchInOriginal && originalSummary ? <p className="record-original-summary search-match-context" lang={latinLang(runText(originalSummary))}><HitText runs={originalSummary} size="inherit" color="inherit" /></p> : null}
      </> : null}
      detailTitle={result.reason ? '值得关注' : '原文线索'}
      detail={detail ? <>
        {result.reason ? <p>{result.reason}</p> : null}
        {translated && !titleMatchInOriginal ? <p className="record-original-title" lang={latinLang(runText(result.title_runs))}><HitText runs={result.title_runs} size="inherit" color="inherit" /></p> : null}
        {originalSummary && !summaryMatchInOriginal ? <p className="record-original-summary" lang={latinLang(runText(originalSummary))}><HitText runs={originalSummary} size="inherit" color="inherit" /></p> : null}
      </> : null}
      actions={<>
        <a className="search-original" href={result.url} target="_blank" rel="noopener noreferrer" aria-describedby="new-tab-description" onClick={report}>原文<Icon name="arrow-up-right" size={16} /></a>
        <Link id={searchResultId(result.item_id)} className="record-issue-link" href={result.where.href} onBefore={() => markSearchResult(result.item_id)}>所在期 · {normalizeDateLabel(result.where.label)}</Link>
        <FavoriteButton className="search-mark" itemId={result.item_id} urlHash={result.url_hash} title={runText(titleRuns)} />
      </>}
    />
  )
}
