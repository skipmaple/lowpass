import { Link } from '@inertiajs/react'

import { Mixed } from '@/lib/typeset'

// 分段控件（画布 pages_site.py 的 seg()）：并排描边块，当前项反白。每一项是一个链接——筛选与排序全在地址里
// （AC-4.7），当前项标 aria-current。
export type SegOption = { label: string; href: string; active: boolean; preserveState?: boolean }

export default function Seg({ options, label }: { options: SegOption[]; label: string }) {
  return (
    <nav className="seg" aria-label={label}>
      {options.map((option) => (
        <Link key={option.label} className="seg-item" href={option.href} preserveState={option.preserveState} aria-current={option.active ? 'true' : undefined}>
          <Mixed text={option.label} size="var(--fs-15)" color={option.active ? 'var(--paper)' : 'var(--ink)'} nowrap />
        </Link>
      ))}
    </nav>
  )
}
