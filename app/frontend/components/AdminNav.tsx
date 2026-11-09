import { Link } from '@inertiajs/react'

import { ADMIN_ISSUES, ADMIN_JOBS, ADMIN_SETTINGS, ADMIN_SOURCES, ADMIN_USERS } from '@/lib/paths'

// 各主题改变导航构图，路由与当前页语义保持一致。
export type AdminSection = 'sources' | 'issues' | 'users' | 'settings'

const ITEMS: { key: AdminSection; label: string; href: string }[] = [
  { key: 'sources', label: '信息源', href: ADMIN_SOURCES },
  { key: 'issues', label: '刊物管理', href: ADMIN_ISSUES },
  { key: 'users', label: '用户', href: ADMIN_USERS },
  { key: 'settings', label: '设置', href: ADMIN_SETTINGS },
]

export default function AdminNav({ active }: { active: AdminSection }) {
  return (
    <nav className="admin-nav" aria-label="后台" onFocus={(event) => {
      const nav = event.currentTarget
      if (nav.scrollWidth <= nav.clientWidth) return
      const item = event.target.getBoundingClientRect()
      const frame = nav.getBoundingClientRect()
      // 只滚动导航自身，键盘浏览不带动正文或整个页面。
      if (item.right > frame.right - 6) nav.scrollLeft += item.right - frame.right + 6
      else if (item.left < frame.left + 6) nav.scrollLeft -= frame.left - item.left + 6
    }}>
      {ITEMS.map((item) => (
        <Link key={item.key} className="admin-nav-item" href={item.href} aria-current={item.key === active ? 'page' : undefined}>
          {item.label}
        </Link>
      ))}
      <a className="admin-nav-item" href={ADMIN_JOBS}>任务队列</a>
    </nav>
  )
}
