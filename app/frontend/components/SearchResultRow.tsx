import { Link } from '@inertiajs/react'

import Chip from '@/components/Chip'
import HitText from '@/components/HitText'
import Icon from '@/components/Icon'
import { reportClick } from '@/lib/search'
import { Mixed } from '@/lib/typeset'
import type { SearchResult } from '@/types/lowpass'

// 结果行（R-4.6、画布 search_row()）：眉行「刊物反白签 · 来源名 · 所在期 · 日期」，标题与摘要片段带命中下划线，
// 底行「所在期 · …」与「原文 ↗」。点标题或原文先上报一次 search_click（9.1）再由浏览器打开（R-8.4 新标签页）；
// 所在期是站内直链，不计。

const LABELS: Record<SearchResult['publication'], string> = { daily: '日刊', weekly: '周刊' }
const DOT = <span className="search-dot">·</span>

export default function SearchResultRow({ result, q }: { result: SearchResult; q: string }) {
  const report = () => reportClick({ item_id: result.item_id, rank: result.rank, q })

  return (
    <article className="search-row">
      <div className="search-eyebrow">
        <Chip text={LABELS[result.publication]} />
        <Mixed text={result.source_name} font="latin" weight={500} size="var(--fs-13)" color="var(--ink2)" nowrap />
        {DOT}
        <Mixed text={result.where.label} size="var(--fs-13)" color="var(--ink2)" nowrap />
        {/* 日刊的所在期就是那一天，日期与它相同就不写第二遍；周刊的所在期是「第 36 周 · 工具」，日期另有信息 */}
        {result.published_label !== result.where.label ? (
          <>
            {DOT}
            <Mixed text={result.published_label} size="var(--fs-13)" color="var(--ink2)" nowrap />
          </>
        ) : null}
      </div>

      <h2 className="search-title">
        <a className="t" href={result.url} target="_blank" rel="noopener noreferrer" onClick={report}>
          <HitText runs={result.title_runs} size="var(--fs-20)" color="var(--ink)" />
        </a>
      </h2>

      {result.snippet_runs ? (
        <p className="search-snippet">
          <HitText runs={result.snippet_runs} size="var(--fs-15)" color="var(--ink2)" />
        </p>
      ) : null}

      <div className="search-links">
        <Link className="t" href={result.where.href}>
          <Mixed text={`所在期 · ${result.where.label}`} size="var(--fs-13)" color="var(--ink)" nowrap />
        </Link>
        <a className="search-original" href={result.url} target="_blank" rel="noopener noreferrer" onClick={report}>
          <span>原文</span>
          <Icon name="arrow-up-right" size={12} />
        </a>
      </div>
    </article>
  )
}
