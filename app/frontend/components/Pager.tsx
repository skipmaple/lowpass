import { Ctrl } from '@/components/Ctrl'

// 分页「上一页 · n / m · 下一页」（R-4.7、R-10.6，画布 pager()）：搜索页与收藏页共用，地址由调用方给；
// 没有上一页或下一页时那一头退成不可点态。
export type PagerProps = { prevHref: string | null; nextHref: string | null; page: number; pages: number }

export default function Pager({ prevHref, nextHref, page, pages }: PagerProps) {
  return (
    <nav className="search-pager" aria-label="分页">
      <Ctrl href={prevHref} label="上一页" icon="chevron-left" side="left" />
      <span className="search-page">
        {page} / {pages}
      </span>
      <Ctrl href={nextHref} label="下一页" icon="chevron-right" side="right" />
    </nav>
  )
}
