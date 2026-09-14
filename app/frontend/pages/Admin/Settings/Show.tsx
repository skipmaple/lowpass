import { router, useForm } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Field from '@/components/Field'
import { ADMIN_SETTINGS, ADMIN_TEST_ALERT } from '@/lib/paths'
import type { AlertChannel, AlertChannels, Schedule } from '@/types/lowpass'

// 设置（5.6，画布 admin_settings()）：调度时间可改（R-1.1 精确到分）；白名单只读（R-5.5 由环境配置）。
// 告警渠道状态与测试告警（③）在这一页；兴趣画像与推荐理由（④）往这一页加节。
export type AdminSettingsShowProps = { schedule: Schedule; whitelist: string[]; alerts: AlertChannels }

function Section({ title, children }: React.PropsWithChildren<{ title: string }>) {
  return (
    <section className="admin-section">
      <h2 className="admin-section-title">{title}</h2>
      <div className="admin-section-body">{children}</div>
    </section>
  )
}

// 项目全局把 Inertia 的 errorValueType 定成 string[]（types/globals.d.ts）；表单按字段只显示第一条。
// 测试用的 useForm 替身已经按字段取第一条，传来的就是纯字符串——两种形状都按「数组取第一条，字符串原样」
// 处理（同 Admin/Sources/Form.tsx 的 fieldError）
function fieldError(errors: Record<string, string | string[] | undefined>, key: string): string | undefined {
  const value = errors[key]
  return Array.isArray(value) ? value[0] : value
}

// 渠道状态一行：已配置显示脱敏地址 / 主机名（数据，Maple），未配置是一句中文
function ChannelRow({ label, channel }: { label: string; channel: AlertChannel }) {
  return (
    <div className="kv-row">
      <span className="kv-key">{label}</span>
      <div className="kv-value">
        {channel.configured ? (
          <span className="data" style={{ color: 'var(--ink)' }}>{channel.label}</span>
        ) : (
          <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: 'var(--ink2)' }}>{channel.label}</span>
        )}
      </div>
    </div>
  )
}

export default function Show({ schedule, whitelist, alerts }: AdminSettingsShowProps) {
  const form = useForm<Schedule>(schedule)
  form.transform((data) => ({ schedule: data }))
  const errors = form.errors as unknown as Record<string, string | string[] | undefined>
  const configured = alerts.email.configured || alerts.webhook.configured
  const [sending, setSending] = useState(false)

  function submit(event: React.FormEvent) {
    event.preventDefault()
    form.patch(ADMIN_SETTINGS)
  }

  // 一次点击一封：请求回来之前按钮禁着（每分钟 5 次的限流是后一道门）
  function sendTestAlert() {
    setSending(true)
    router.post(ADMIN_TEST_ALERT, {}, { onFinish: () => setSending(false) })
  }

  return (
    <AdminPage section="settings" bottom="设置">
      <Section title="调度">
        <form className="admin-form-row" onSubmit={submit} style={{ alignItems: 'flex-start' }}>
          <Field label="日刊生成时间" name="daily_time" value={form.data.daily_time} onChange={(v) => form.setData('daily_time', v)} mono width={160} note="Asia/Shanghai，精确到分" error={fieldError(errors, 'daily_time')} />
          <Field label="周刊检查时间" name="weekly_time" value={form.data.weekly_time} onChange={(v) => form.setData('weekly_time', v)} mono width={160} error={fieldError(errors, 'weekly_time')} />
          <div style={{ paddingTop: 26 }}>
            <button type="submit" className="btn-primary" disabled={form.processing}>
              保存
            </button>
          </div>
        </form>
      </Section>

      <Section title="管理员白名单（只读）">
        {whitelist.length === 0 ? (
          <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: 'var(--ink2)' }}>未配置</span>
        ) : (
          whitelist.map((email) => (
            <span key={email} className="data" style={{ color: 'var(--ink)' }}>
              {email}
            </span>
          ))
        )}
        <span className="field-note">白名单由环境配置，改动在下次登录生效。</span>
      </Section>

      <Section title="告警">
        <ChannelRow label="邮件" channel={alerts.email} />
        <ChannelRow label="Webhook" channel={alerts.webhook} />
        <div className="admin-actions" style={{ alignItems: 'center' }}>
          <button type="button" className="btn-primary" disabled={!configured || sending} onClick={sendTestAlert}>
            发送测试告警
          </button>
          {configured ? null : <span className="field-note">渠道由环境配置，见 docs/development.md</span>}
        </div>
      </Section>
    </AdminPage>
  )
}

Show.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
