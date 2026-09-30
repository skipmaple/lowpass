import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'

import Layout from '@/components/Layout'
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

    expect(screen.getByRole('heading', { level: 1, name: '账户信息' })).toBeInTheDocument()
    // 账户信息仅在键值行显示
    expect(screen.getAllByText('drew@example.com')).toHaveLength(1)
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

    expect(container.textContent).toContain('2026-09-09 08:12 登录 · 连续 30 天未活动需重新登录，单次会话最长 90 天 · 2026-12-08 到期')
  })

  it('登出走 DELETE /session', async () => {
    show()

    await userEvent.click(screen.getByRole('button', { name: '登出' }))

    expect(router.delete).toHaveBeenCalledWith('/session')
  })

  // 注销（R-5.11、AC-5.8、AC-5.9、D26）：一行说删什么；「注销」只开确认框，确认才发 DELETE /user
  describe('注销账号', () => {
    it('一行说删什么，「注销」打开确认框，框里是要注销的账号', async () => {
      show()

      expect(screen.getByText('删除账号、登录方式与全部会话，期与条目不受影响')).toBeInTheDocument()
      await userEvent.click(screen.getByRole('button', { name: '注销' }))

      const dialog = screen.getByRole('dialog', { name: '注销后无法恢复。确认注销这个账号？' })
      expect(dialog).toHaveTextContent('drew@example.com')
      expect(router.delete).not.toHaveBeenCalled()
    })

    it('没有邮箱的账号在框里写显示名', async () => {
      show({ user: { display_name: 'octocat', email: null, avatar_url: null, role: 'member' } })

      await userEvent.click(screen.getByRole('button', { name: '注销' }))

      expect(screen.getByRole('dialog')).toHaveTextContent('octocat')
    })

    it('AC-5.9 取消或 Esc：框关上，什么都不发，焦点回到「注销」', async () => {
      show()
      const button = screen.getByRole('button', { name: '注销' })

      await userEvent.click(button)
      await userEvent.click(screen.getByRole('button', { name: '取消' }))
      expect(screen.queryByRole('dialog')).toBeNull()
      expect(button).toHaveFocus()

      await userEvent.click(button)
      await userEvent.keyboard('{Escape}')
      expect(screen.queryByRole('dialog')).toBeNull()
      expect(router.delete).not.toHaveBeenCalled()
    })

    it('确认才发 DELETE /user；进行中按钮说「正在注销…」', async () => {
      show()

      await userEvent.click(screen.getByRole('button', { name: '注销' }))
      await userEvent.click(screen.getByRole('button', { name: '确认注销' }))

      expect(router.delete).toHaveBeenCalledWith('/user', expect.any(Object))
      expect(screen.getByRole('button', { name: '正在注销…' })).toBeDisabled()
      expect(screen.getByRole('button', { name: '取消' })).toBeDisabled()
    })

    it('没跳走就是没删成：框留着，说一句，可以再试', async () => {
      show()

      await userEvent.click(screen.getByRole('button', { name: '注销' }))
      await userEvent.click(screen.getByRole('button', { name: '确认注销' }))
      const options = router.delete.mock.calls[0][1] as { onFinish: () => void }
      act(() => options.onFinish())

      expect(screen.getByRole('alert')).toHaveTextContent('注销没有完成，请重试。')
      expect(screen.getByRole('button', { name: '确认注销' })).toBeEnabled()
    })

    it('访问成功了就不说失败', async () => {
      show()

      await userEvent.click(screen.getByRole('button', { name: '注销' }))
      await userEvent.click(screen.getByRole('button', { name: '确认注销' }))
      const options = router.delete.mock.calls[0][1] as { onSuccess: () => void; onFinish: () => void }
      act(() => { options.onSuccess(); options.onFinish() })

      expect(screen.queryByRole('alert')).toBeNull()
    })
  })

  it('flash 的提示句由共享布局显示一次', () => {
    const props = { flash: { alert: '这个邮箱无法自动合并。如果你之前用其他方式登录过，请改用原方式。' } }
    setPageProps(props)
    render(
      <Layout footer={false}><Show
        user={{ display_name: 'X', email: null, avatar_url: null, role: 'member' }}
        identities={[]}
        session={{ logged_in_label: '2026-09-09 08:12', expires_label: '2026-12-08' }}
        daily_time="06:00"
        latest_weekly_key={null}
      /></Layout>,
    )

    expect(screen.getByText('这个邮箱无法自动合并。如果你之前用其他方式登录过，请改用原方式。')).toBeInTheDocument()
  })

  // 头像是 provider 的外链图：加载它别把读者在看哪一页捎给 Google / GitHub
  it('有头像时圆里是图片，且不带 Referer', () => {
    const { container } = show({ user: { display_name: 'Drew Lee', email: 'drew@example.com', avatar_url: 'https://avatars.example/drew.png', role: 'admin' } })

    const img = container.querySelector('.settings-avatar img')
    expect(img).toHaveAttribute('src', 'https://avatars.example/drew.png')
    expect(img).toHaveAttribute('referrerpolicy', 'no-referrer')
  })
})
