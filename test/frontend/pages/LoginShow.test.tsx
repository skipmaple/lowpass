import { fireEvent, render, screen } from '@testing-library/react'
import { isValidElement } from 'react'
import type * as React from 'react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'

import Show, { type DevelopmentAccount } from '@/pages/Login/Show'
import { setPageProps } from '../support/inertia'

// 登录页（PRD 5.5、6.2，画布 login_card()）：口号、每个 provider 一个 POST 表单按钮、附录 B 的提示句

const developerAccounts: DevelopmentAccount[] = [
  { role: 'admin', name: '开发管理员', email: 'admin@example.test' },
  { role: 'reader', name: '普通读者', email: 'reader@example.test' },
]

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="tok-123">'
  setPageProps({ flash: {} })
})

afterEach(() => {
  document.head.innerHTML = ''
})

describe('Login/Show', () => {
  it('口号与两个 provider 的表单按钮，带 CSRF 令牌与 origin', () => {
    render(<Show providers={['google_oauth2', 'github']} next="/weekly" />)

    expect(screen.getByRole('heading', { level: 1, name: '登录' })).toBeInTheDocument()
    expect(screen.getByText('每天一期技术日刊，登录后阅读')).toBeInTheDocument()
    const google = screen.getByRole('button', { name: '使用 Google 登录' })
    const form = google.closest('form')
    expect(form).toHaveAttribute('method', 'post')
    expect(form).toHaveAttribute('action', '/auth/google_oauth2')
    expect(form?.querySelector('input[name="authenticity_token"]')).toHaveAttribute('value', 'tok-123')
    expect(form?.querySelector('input[name="origin"]')).toHaveAttribute('value', '/weekly')
    expect(screen.getByRole('button', { name: '使用 GitHub 登录' }).closest('form')).toHaveAttribute('action', '/auth/github')
  })

  it('没有 next 就不带 origin；只画配置了的 provider', () => {
    render(<Show providers={['github']} next={null} />)

    expect(screen.queryByRole('button', { name: '使用 Google 登录' })).toBeNull()
    expect(document.querySelector('input[name="origin"]')).toBeNull()
  })

  it('开发登录是直接 GET 回调的表单：显示名、邮箱', () => {
    render(<Show providers={['developer']} next="/daily" />)

    fireEvent.click(screen.getByText('使用其他账号'))
    const button = screen.getByRole('button', { name: '开发登录' })
    const form = button.closest('form')
    expect(form).toHaveAttribute('method', 'get')
    expect(form).toHaveAttribute('action', '/auth/developer/callback')
    expect(screen.getByLabelText('显示名')).toHaveAttribute('name', 'name')
    expect(screen.getByLabelText('邮箱')).toHaveAttribute('name', 'email')
    expect(form?.querySelector('input[name="origin"]')).toHaveAttribute('value', '/daily')
    expect(form?.querySelector('input[name="authenticity_token"]')).toBeNull()
  })

  it('开发账号一键登录，无需输入，并保留原访问地址', () => {
    render(<Show providers={['developer']} developer_accounts={developerAccounts} next="/admin/sources" />)

    for (const [index, label] of ['以管理员身份进入', '以读者身份进入'].entries()) {
      const form = screen.getByRole('button', { name: label }).closest('form')!
      expect(form).toHaveAttribute('action', '/auth/developer/callback')
      expect(form).toHaveAttribute('method', 'get')
      expect(form.querySelector('[name="name"]')).toHaveValue(developerAccounts[index].name)
      expect(form.querySelector('[name="email"]')).toHaveValue(developerAccounts[index].email)
      expect(form.querySelector('[name="origin"]')).toHaveValue('/admin/sources')
      expect(form.querySelector('input:not([type="hidden"])')).toBeNull()
    }
    expect(screen.getByLabelText('显示名')).not.toBeVisible()
    expect(screen.getByLabelText('邮箱')).not.toBeVisible()
    expect(screen.getByText('使用其他账号').closest('details')).not.toHaveAttribute('open')
    fireEvent.click(screen.getByText('使用其他账号'))
    expect(screen.getByRole('textbox', { name: '邮箱' })).toBeVisible()
  })

  it('未启用 developer 策略时不渲染快捷账号或手工开发登录', () => {
    render(<Show providers={['github']} developer_accounts={developerAccounts} next={null} />)

    expect(screen.queryByRole('button', { name: '以管理员身份进入' })).toBeNull()
    expect(screen.queryByRole('button', { name: '以读者身份进入' })).toBeNull()
    expect(screen.queryByText('使用其他账号')).toBeNull()
  })

  it('快捷登录独立显示等待状态，返回页面后恢复', () => {
    render(<Show providers={['developer']} developer_accounts={developerAccounts} next={null} />)
    fireEvent.submit(screen.getByRole('button', { name: '以管理员身份进入' }).closest('form')!)
    expect(screen.getByRole('button', { name: '正在登录…' })).toBeDisabled()
    expect(screen.getByRole('button', { name: '以读者身份进入' })).toBeEnabled()
    fireEvent(window, new Event('pageshow'))
    expect(screen.getByRole('button', { name: '以管理员身份进入' })).toBeEnabled()
  })

  it('flash 的提示句原样显示', () => {
    setPageProps({ flash: { alert: '已取消登录。' } })
    render(<Show providers={['github']} next={null} />)

    expect(screen.getByText('已取消登录。')).toBeInTheDocument()
  })

  // 注销之后回到这里（R-5.11、AC-5.8）：不是出错，走 status，不是 alert
  it('notice 也显示：已注销账号。', () => {
    setPageProps({ flash: { notice: '已注销账号。' } })
    render(<Show providers={['github']} next={null} />)

    expect(screen.getByRole('status')).toHaveTextContent('已注销账号。')
    expect(screen.queryByRole('alert')).toBeNull()
  })

  // 布局函数要经得起 Inertia 3.7 的两道关：先用 props 试调一次（返回元素才算布局函数，
  // 否则套默认 Layout），再用页面元素正式调一次——出来的东西里不能有报头
  it('不套持久布局：props 试调返回元素，页面外只有登录卡、没有报头', () => {
    expect(isValidElement(Show.layout({ providers: ['github'], next: null } as unknown as React.ReactNode))).toBe(true)

    const { container } = render(<>{Show.layout(<Show providers={['github']} next={null} />)}</>)

    expect(container.querySelector('.masthead')).toBeNull()
    expect(container.querySelector('.login-card')).not.toBeNull()
  })
})

it('各登录方式显示自己的等待状态，从登录方返回后可重试', () => {
 render(<Show providers={['google_oauth2', 'github']} next={null} />)
 const google = screen.getByRole('button', { name: '使用 Google 登录' })
 fireEvent.submit(google.closest('form')!)
 expect(screen.getByRole('button', { name: '正在前往 Google…' })).toBeDisabled()
 expect(screen.getByRole('button', { name: '正在前往 Google…' })).toHaveAttribute('aria-busy', 'true')
 expect(screen.getByRole('button', { name: '使用 GitHub 登录' })).toBeEnabled()
 fireEvent(window, new Event('pageshow'))
 expect(screen.getByRole('button', { name: '使用 Google 登录' })).toBeEnabled()
 expect(screen.getByRole('button', { name: '使用 Google 登录' })).toHaveAttribute('aria-busy', 'false')
})

it('品牌几何仅作装饰，登录控件立即可用', () => {
  const { container } = render(<Show providers={['google_oauth2', 'github']} next={null} />)

  expect(container.querySelector('.login-composition')).toHaveAttribute('aria-hidden', 'true')
  expect(screen.getByRole('button', { name: '使用 Google 登录' })).toBeEnabled()
})

it('紧凑外观选项可聚焦，切换不清空登录输入', () => {
  render(<Show providers={['developer']} next="/daily" />)
  fireEvent.click(screen.getByText('使用其他账号'))
  const name = screen.getByLabelText('显示名')
  const email = screen.getByLabelText('邮箱')
  fireEvent.change(name, { target: { value: 'Drew' } })
  fireEvent.change(email, { target: { value: 'drew@example.com' } })
  expect(screen.getByRole('group', { name: '阅读外观' })).toBeInTheDocument()
  const duet = screen.getByRole('radio', { name: '双声部' })
  duet.focus()
  fireEvent.click(duet)
  expect(duet).toBeChecked()
  expect(name).toHaveValue('Drew')
  expect(email).toHaveValue('drew@example.com')
  expect(screen.getByRole('button', { name: '开发登录' }).closest('form')?.querySelector('[name="origin"]')).toHaveValue('/daily')
})

// 自查第 1 轮：纸纹只铺在纸卡上时，纸卡四周露出一圈不同纹理的边。纸纹铺满整页，纸卡不另起一块
it('纸纹铺满整页，纸卡不另起一块纸纹', () => {
  const { container } = render(<Show providers={['google_oauth2']} next={null} />)

  expect(container.querySelector('.login-ground')).toHaveClass('paper')
  expect(container.querySelector('.login-card')).not.toHaveClass('paper')
})
