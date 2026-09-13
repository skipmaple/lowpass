import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'

import Show, { type SettingsShowProps } from '@/pages/Settings/Show'
import { router, setPageProps } from '../support/inertia'

// 设置页（R-5.10，画布 settings()）：期头「设置」+ 邮箱与显示名，键值行，登出

function show(overrides: Partial<SettingsShowProps> = {}) {
  const props: SettingsShowProps = {
    user: { display_name: 'Drew Lee', email: 'drew@example.com', avatar_url: null, role: 'admin' },
    identities: [
      { provider: 'google', strategy: 'google_oauth2', linked_at_label: '2026-09-08 14:02' },
      { provider: 'github', strategy: 'github', linked_at_label: null },
    ],
    session: { logged_in_label: '2026-09-09 08:12', expires_label: '2026-12-08' },
    daily_time: '06:00',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }
  setPageProps({ ...props, flash: {} })
  return render(<Show {...props} />)
}

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="tok-123">'
})

afterEach(() => {
  document.head.innerHTML = ''
  router.delete.mockClear()
})

describe('Settings/Show', () => {
  it('期头与键值行', () => {
    show()

    expect(screen.getByRole('heading', { level: 1, name: '设置' })).toBeInTheDocument()
    // 期头与「邮箱」行各一次
    expect(screen.getAllByText('drew@example.com')).toHaveLength(2)
    expect(screen.getByText('管理员')).toBeInTheDocument()
    expect(screen.getByText('邮箱在白名单中')).toBeInTheDocument()
    expect(screen.getByText('已绑定')).toBeInTheDocument()
    expect(screen.getByText('· 2026-09-08 14:02')).toBeInTheDocument()
    expect(screen.getByText('未绑定')).toBeInTheDocument()
  })

  it('未绑定的 provider 给一个 POST 表单按钮「使用 GitHub 登录」（不是「以绑定」，设计 L2）', () => {
    show()

    const button = screen.getByRole('button', { name: '使用 GitHub 登录' })
    const form = button.closest('form')
    expect(form).toHaveAttribute('method', 'post')
    expect(form).toHaveAttribute('action', '/auth/github')
    expect(form?.querySelector('input[name="authenticity_token"]')).toHaveAttribute('value', 'tok-123')
    expect(screen.queryByText(/以绑定/)).toBeNull()
  })

  it('成员没有白名单说明；没邮箱写「无」', () => {
    show({ user: { display_name: '客人', email: null, avatar_url: null, role: 'member' } })

    expect(screen.getByText('成员')).toBeInTheDocument()
    expect(screen.queryByText('邮箱在白名单中')).toBeNull()
    expect(screen.getByText('无')).toBeInTheDocument()
  })

  it('本次会话一行', () => {
    const { container } = show()

    expect(container.textContent).toContain('2026-09-09 08:12 登录 · 30 天内免登录 · 2026-12-08 到期')
  })

  it('登出走 DELETE /session', async () => {
    show()

    await userEvent.click(screen.getByRole('button', { name: '登出' }))

    expect(router.delete).toHaveBeenCalledWith('/session')
  })

  it('flash 的提示句显示在期头之下', () => {
    const props = { flash: { alert: '这个邮箱无法自动合并。如果你之前用其他方式登录过，请改用原方式。' } }
    setPageProps(props)
    render(
      <Show
        user={{ display_name: 'X', email: null, avatar_url: null, role: 'member' }}
        identities={[]}
        session={{ logged_in_label: '2026-09-09 08:12', expires_label: '2026-12-08' }}
        daily_time="06:00"
        latest_weekly_key={null}
      />,
    )

    expect(screen.getByText('这个邮箱无法自动合并。如果你之前用其他方式登录过，请改用原方式。')).toBeInTheDocument()
  })

  it('有头像时圆里是图片', () => {
    const { container } = show({ user: { display_name: 'Drew Lee', email: 'drew@example.com', avatar_url: 'https://avatars.example/drew.png', role: 'admin' } })

    expect(container.querySelector('.settings-avatar img')).toHaveAttribute('src', 'https://avatars.example/drew.png')
  })
})
