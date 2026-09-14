import { Link } from '@inertiajs/react'

import { ADMIN_ISSUES, ADMIN_SETTINGS, ADMIN_SOURCES, ADMIN_USERS } from '@/lib/paths'

// 后台分页索引条（画布 pages_site.py 的 admin_nav()）：四格等分、56px、1px 墨线共用一条边，当前项反白
export type AdminSection = 'sources' | 'issues' | 'users' | 'settings'

const ITEMS: { key: AdminSection; label: string; href: string }[] = [
  { key: 'sources', label: '信息源', href: ADMIN_SOURCES },
  { key: 'issues', label: '期', href: ADMIN_ISSUES },
  { key: 'users', label: '用户', href: ADMIN_USERS },
  { key: 'settings', label: '设置', href: ADMIN_SETTINGS },
]

export default function AdminNav({ active }: { active: AdminSection }) {
  return (
    <nav className="admin-nav" aria-label="后台">
      {ITEMS.map((item) => (
        <Link key={item.key} className="admin-nav-item" href={item.href} aria-current={item.key === active ? 'page' : undefined}>
          {item.label}
        </Link>
      ))}
    </nav>
  )
}
