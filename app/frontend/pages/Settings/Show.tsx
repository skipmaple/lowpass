import { router, usePage } from '@inertiajs/react'
import type * as React from 'react'

import Chip from '@/components/Chip'
import Icon from '@/components/Icon'
import Layout from '@/components/Layout'
import PageHead from '@/components/PageHead'
import { SESSION, authHref, latestWeeklyHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { FooterData, SettingsIdentity } from '@/types/lowpass'

// 设置页（R-5.10，画布 pages_site.py 的 settings()）：期头「设置」+ 等宽邮箱与显示名，右端「登出」描边按钮；
// 键值行：头像与显示名、邮箱、角色、每个 provider 一行、本次会话。未绑定的 provider 给一个 POST 表单按钮
// 「使用 X 登录」（不是「以绑定」：邮箱不同时它会新建账号，走 R-5.3，设计 L2）。
// 无法合并的提示（AC-5.3）由共享 Layout 的 flash 反馈呈现。

export type SettingsShowProps = FooterData & {
  user: { display_name: string; email: string | null; avatar_url: string | null; role: 'admin' | 'member' }
  identities: SettingsIdentity[]
  session: { logged_in_label: string; expires_label: string }
}

const PROVIDER_LABELS = { google: 'Google', github: 'GitHub' } as const
const LOGIN_LABELS = { google: '使用 Google 登录', github: '使用 GitHub 登录' } as const

function csrfToken() {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
}

function Row({ label, children }: React.PropsWithChildren<{ label: string }>) {
  return (
    <div className="kv-row">
      <span className="kv-key">{label}</span>
      <div className="kv-value">{children}</div>
    </div>
  )
}

function IdentityRow({ identity }: { identity: SettingsIdentity }) {
  return (
    <Row label={PROVIDER_LABELS[identity.provider]}>
      {identity.linked_at_label ? (
        <>
          <span className="cjk" style={{ fontSize: 'var(--fs-15)' }}>
            已绑定
          </span>
          <Mixed text={`· ${identity.linked_at_label}`} size="var(--fs-13)" color="var(--ink2)" />
        </>
      ) : (
        <>
          <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: 'var(--ink2)' }}>
            未绑定
          </span>
          <form method="post" action={authHref(identity.strategy)}>
            <input type="hidden" name="authenticity_token" value={csrfToken()} />
            <button type="submit" className="link-button">
              {LOGIN_LABELS[identity.provider]}
            </button>
          </form>
        </>
      )}
    </Row>
  )
}

export default function Show({ user, identities, session }: SettingsShowProps) {

  return (
    <>
      <PageHead big="账户信息" />
      <p className="operation-feedback">使用另一登录方式时，相同的已验证邮箱会合并到此账户；邮箱不同则切换到另一个账户。</p>
      <div className="settings-rows">
        <Row label="头像与显示名">
          {/* 头像是 provider 的外链图，referrerPolicy 拦住 Referer（与报头同理） */}
          <span className="settings-avatar">
            {user.avatar_url ? <img src={user.avatar_url} alt="" referrerPolicy="no-referrer" /> : <Icon name="user" size={20} />}
          </span>
          <Mixed text={user.display_name} font="latin" size="var(--fs-20)" color="var(--ink)" />
        </Row>
        <Row label="邮箱">
          {user.email ? (
            <span className="data" style={{ color: 'var(--ink)' }}>
              {user.email}
            </span>
          ) : (
            <span className="cjk" style={{ fontSize: 'var(--fs-13)', color: 'var(--ink2)' }}>
              无
            </span>
          )}
        </Row>
        <Row label="角色">
          <Chip text={user.role === 'admin' ? '管理员' : '成员'} />
          {user.role === 'admin' ? (
            <span className="cjk" style={{ fontSize: 'var(--fs-13)', color: 'var(--ink2)' }}>
              邮箱在白名单中
            </span>
          ) : null}
        </Row>
        {identities.map((identity) => (
          <IdentityRow key={identity.provider} identity={identity} />
        ))}
        <Row label="本次会话">
          <Mixed text={`${session.logged_in_label} 登录 · 连续 30 天未活动需重新登录，单次会话最长 90 天 · ${session.expires_label} 到期`} size="var(--fs-13)" color="var(--ink2)" />
          <button type="button" className="link-button" onClick={() => router.delete(SESSION)}>登出</button>
        </Row>
      </div>
    </>
  )
}

function SettingsLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<SettingsShowProps>().props

  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}

Show.layout = (page: React.ReactNode) => <SettingsLayout>{page}</SettingsLayout>
