import { render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'

import Show from '@/pages/Login/Show'
import { setPageProps } from '../support/inertia'

// 登录页（PRD 5.5、6.2，画布 login_card()）：口号、每个 provider 一个 POST 表单按钮、附录 B 的提示句

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
    expect(screen.getByText('滤掉噪音，留下信号。')).toBeInTheDocument()
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

    const button = screen.getByRole('button', { name: '开发登录' })
    const form = button.closest('form')
    expect(form).toHaveAttribute('method', 'get')
    expect(form).toHaveAttribute('action', '/auth/developer/callback')
    expect(screen.getByLabelText('显示名')).toHaveAttribute('name', 'name')
    expect(screen.getByLabelText('邮箱')).toHaveAttribute('name', 'email')
    expect(form?.querySelector('input[name="origin"]')).toHaveAttribute('value', '/daily')
    expect(form?.querySelector('input[name="authenticity_token"]')).toBeNull()
  })

  it('flash 的提示句原样显示', () => {
    setPageProps({ flash: { alert: '已取消登录。' } })
    render(<Show providers={['github']} next={null} />)

    expect(screen.getByText('已取消登录。')).toBeInTheDocument()
  })

  it('不套持久布局', () => {
    expect(Show.layout(<div>x</div>)).toEqual(<div>x</div>)
  })
})
