import '@/styles/themes-login.css'
import { Head, usePage } from '@inertiajs/react'
import { useEffect, useRef, useState } from 'react'
import type * as React from 'react'

import { usePageTurnCommit } from '@/lib/pageTurn'
import Icon from '@/components/Icon'
import ThemePicker from '@/components/ThemePicker'
import { authCallbackHref, authHref } from '@/lib/paths'
import type { AuthProvider, SharedProps } from '@/types/lowpass'

// 登录页沿用当前阅读主题的字形与平面；登录方式始终使用普通表单。
// Google / GitHub POST 到 /auth/<策略>（omniauth-rails_csrf_protection 要求 POST 带 CSRF 令牌），整页跳去 provider；
// 开发登录（仅 development）直接 GET 回调，字段就是 OmniAuth developer 策略要的 name / email。
// next（校验过的站内路径）放进隐藏字段 origin，OmniAuth 会存进会话、回调时交回。
// 不套持久布局：登录前没有报头导航与页脚可去的地方。

export type DevelopmentAccount = { role: 'admin' | 'reader'; name: string; email: string }
export type LoginShowProps = { providers: AuthProvider[]; next: string | null; developer_accounts?: DevelopmentAccount[] }

const LABELS: Record<AuthProvider, string> = { google_oauth2: '使用 Google 登录', github: '使用 GitHub 登录', developer: '开发登录' }

function csrfToken() {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
}

function ProviderForm({ provider, next, account }: { provider: AuthProvider; next: string | null; account?: DevelopmentAccount }) {
  const developer = provider === 'developer'
  const label = account ? (account.role === 'admin' ? '以管理员身份进入' : '以读者身份进入') : LABELS[provider]
  const [pending, setPending] = useState(false)
  useEffect(() => {
    const restore = () => setPending(false)
    window.addEventListener('pageshow', restore)
    return () => window.removeEventListener('pageshow', restore)
  }, [])

  return (
    <form method={developer ? 'get' : 'post'} action={developer ? authCallbackHref(provider) : authHref(provider)} className="login-form" onSubmit={() => setPending(true)} aria-busy={pending}>
      {developer ? null : <input type="hidden" name="authenticity_token" value={csrfToken()} />}
      {next ? <input type="hidden" name="origin" value={next} /> : null}
      {developer && account ? (
        <>
          <input type="hidden" name="name" value={account.name} />
          <input type="hidden" name="email" value={account.email} />
        </>
      ) : developer ? (
        <>
          <label className="field">
            <span className="field-label">显示名</span>
            <input className="field-input" name="name" required autoComplete="name" />
          </label>
          <label className="field">
            <span className="field-label">邮箱</span>
            <input className="field-input" name="email" type="email" required autoComplete="email" />
          </label>
        </>
      ) : null}
      <button type="submit" className={account?.role === 'reader' ? 'ctrl login-secondary' : 'login-button'} disabled={pending} aria-busy={pending}>
        {pending ? (developer ? '正在登录…' : `正在前往 ${provider === 'github' ? 'GitHub' : 'Google'}…`) : label}
      </button>
    </form>
  )
}

export default function Show({ providers, next, developer_accounts = [] }: LoginShowProps) {
  const page = usePage<SharedProps>()
  const { flash } = page.props
  const surface = useRef<HTMLElement>(null)
  usePageTurnCommit(page, surface)

  return (
    <main className="paper login-ground" ref={surface}>
      <Head title="登录" />
      <div className="login-card">
        <div className="login-band">
          <span className="masthead-brand">lowpass</span>
          <div className="login-composition" aria-hidden="true" />
        </div>
        <div className="login-body">
          <h1>登录</h1>
          <p className="login-tagline">每天一期技术日刊，登录后阅读</p>
          <div className="login-forms">
            {providers.map((provider) => provider === 'developer' ? (
              <div className="login-development" key={provider}>
                {developer_accounts.map((account) => (
                  <ProviderForm key={account.role} provider={provider} next={next} account={account} />
                ))}
                <details className="login-other-account">
                  <summary>使用其他账号<Icon name="chevron-down" size={14} /></summary>
                  <ProviderForm provider={provider} next={next} />
                </details>
              </div>
            ) : <ProviderForm key={provider} provider={provider} next={next} />)}
          </div>
          {flash?.alert ? (
            <div className="notice-line login-feedback" data-kind="fail" role="alert">
              <Icon name="triangle-alert" size={14} color="currentColor" />
              <span>{flash.alert}</span>
            </div>
          ) : null}
          {/* 不是出错的提示（注销之后的「已注销账号。」，R-5.11）：对勾，status 不打断读屏 */}
          {flash?.notice ? (
            <div className="notice-line login-feedback" data-kind="ok" role="status">
              <Icon name="check" size={14} color="currentColor" />
              <span>{flash.notice}</span>
            </div>
          ) : null}
        </div>
      </div>
      <div className="login-appearance">
        <ThemePicker compact />
      </div>
    </main>
  )
}

// 不套 application.tsx 里默认的 Layout（报头 / 页脚）。包一层 Fragment 不是多余：
// Inertia 3.7 先拿 props 试调一次 layout 函数（dist/index.js 的 renderChildren），返回的是元素才当布局函数，
// 不是就当成「解析 props 的回调」并套上默认布局——恒等函数原样交回 props 对象，正好落进后一条
Show.layout = (page: React.ReactNode) => <>{page}</>
