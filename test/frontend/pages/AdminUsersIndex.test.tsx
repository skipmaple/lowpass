import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Index from '@/pages/Admin/Users/Index'
import { setPageProps } from '../support/inertia'
import { adminUserRow } from '../support/props'

// 用户（5.6，画布 admin_users()）：只读表

describe('Admin/Users/Index', () => {
  it('表、角色小签、缺值写破折号、汇总', () => {
    const props = { users: [adminUserRow(), adminUserRow({ id: 'u2', display_name: 'octocat', email: null, role: 'member', providers_label: 'GitHub', last_login_label: null })], summary: '2 个用户 · 只读', daily_time: '06:00', latest_weekly_key: null }
    setPageProps({ ...props, flash: {}, errors: {} })
    const { container } = render(<Index {...props} />)

    expect(screen.getByRole('link', { name: '用户' })).toHaveAttribute('aria-current', 'page')
    const rows = screen.getAllByRole('row')
    expect(rows).toHaveLength(3)
    expect(within(rows[1]).getByText('Drew Lee')).toBeInTheDocument()
    expect(within(rows[1]).getByText('管理员')).toBeInTheDocument()
    expect(within(rows[1]).getByText('Google · GitHub')).toBeInTheDocument()
    expect(within(rows[2]).getByText('成员')).toBeInTheDocument()
    expect(within(rows[2]).getAllByText('—')).toHaveLength(2)
    // 汇总走 Mixed（中文夹数字），文字被拆进多个 span：断言 textContent 而不是 getByText 整句
    // （与 AdminSourcesIndex.test.tsx、AdminIssuesIndex.test.tsx 的 .admin-summary 断言同一个理由）
    expect(container.querySelector('.admin-summary')?.textContent).toContain('2 个用户 · 只读')
  })
})
