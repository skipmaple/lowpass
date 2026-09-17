import { Head, usePage } from '@inertiajs/react'
import { useEffect, useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import { Sunrise } from '@/components/Illustration'
import { authCallbackHref, authHref } from '@/lib/paths'
import type { AuthProvider, SharedProps } from '@/types/lowpass'

// 登录页（PRD 5.5、6.2，画布 pages_site.py 的 login_card()）：深色底上一张 400px 纸卡——80px 墨带与品牌字、
// 1px 框里的低通日出、口号（附录 B）、每个 provider 一个 44px 描边按钮。按钮各是一个普通表单：
// Google / GitHub POST 到 /auth/<策略>（omniauth-rails_csrf_protection 要求 POST 带 CSRF 令牌），整页跳去 provider；
// 开发登录（仅 development）直接 GET 回调，字段就是 OmniAuth developer 策略要的 name / email。
// next（校验过的站内路径）放进隐藏字段 origin，OmniAuth 会存进会话、回调时交回。
// 不套持久布局：登录前没有报头导航与页脚可去的地方。

export type LoginShowProps = { providers: AuthProvider[]; next: string | null }

const LABELS: Record<AuthProvider, string> = { google_oauth2: '使用 Google 登录', github: '使用 GitHub 登录', developer: '开发登录' }

function csrfToken() {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
}

function ProviderForm({ provider, next }: { provider: AuthProvider; next: string | null }) {
  const developer = provider === 'developer'
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
      {developer ? (
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
      <button type="submit" className="login-button" disabled={pending}>
        {pending ? (developer ? '正在登录…' : `正在前往 ${provider === 'github' ? 'GitHub' : 'Google'}…`) : LABELS[provider]}
      </button>
    </form>
  )
}

export default function Show({ providers, next }: LoginShowProps) {
  const { flash } = usePage<SharedProps>().props

  return (
    <main className="login-ground">
      <Head title="登录" />
      <div className="paper login-card">
        <div className="login-band">
          <span className="masthead-brand">lowpass</span>
        </div>
        <div className="login-body">
          <h1 className="sr-only">登录</h1>
          <div className="login-art">
            <Sunrise />
          </div>
          <p className="login-tagline">每天一期技术日刊，登录后阅读</p>
          <div className="login-forms">
            {providers.map((provider) => (
              <ProviderForm key={provider} provider={provider} next={next} />
            ))}
          </div>
          {flash?.alert ? (
            <div className="notice-line" style={{ marginTop: 20 }} role="alert">
              <Icon name="triangle-alert" size={14} color="var(--ink2)" />
              <span>{flash.alert}</span>
            </div>
          ) : null}
        </div>
      </div>
    </main>
  )
}

// 不套 application.tsx 里默认的 Layout（报头 / 页脚）。包一层 Fragment 不是多余：
// Inertia 3.7 先拿 props 试调一次 layout 函数（dist/index.js 的 renderChildren），返回的是元素才当布局函数，
// 不是就当成「解析 props 的回调」并套上默认布局——恒等函数原样交回 props 对象，正好落进后一条
Show.layout = (page: React.ReactNode) => <>{page}</>
