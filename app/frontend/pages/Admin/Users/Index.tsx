import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Chip from '@/components/Chip'
import Table from '@/components/Table'
import { Mixed } from '@/lib/typeset'
import type { AdminUserRow } from '@/types/lowpass'

// 用户（5.6，画布 admin_users()）：只读——显示名、邮箱、角色、登录方式、最近登录
export type AdminUsersIndexProps = { users: AdminUserRow[]; summary: string }

const HEADERS = ['显示名', '邮箱', '角色', '登录方式', '最近登录']
const WIDTHS = ['minmax(0, 1fr)', 'minmax(0, 1.5fr)', 'minmax(0, .7fr)', 'minmax(0, 1fr)', 'minmax(0, 1fr)']

export default function Index({ users, summary }: AdminUsersIndexProps) {
  const rows = users.map((user) => ({
    key: user.id,
    cells: [
      <Mixed text={user.display_name} font="latin" size="var(--fs-15)" color="var(--ink)" />,
      user.email ? <span className="data" style={{ color: 'var(--ink)' }}>{user.email}</span> : null,
      user.role === 'admin' ? <Chip text="管理员" /> : <span className="chip-outline">成员</span>,
      <Mixed text={user.providers_label} font="latin" size="var(--fs-15)" color="var(--ink2)" />,
      user.last_login_label ? <span className="data">{user.last_login_label}</span> : null,
    ],
  }))

  return (
    <AdminPage section="users" bottom="用户">
      <p className="cjk admin-readonly-note">用户信息只读。管理员身份由邮箱白名单决定。</p>
      <Table headers={HEADERS} widths={WIDTHS} rows={rows} empty="还没有用户" />
      <div className="admin-summary">
        <Mixed text={summary} />
      </div>
    </AdminPage>
  )
}

Index.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
