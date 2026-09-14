import { useForm } from '@inertiajs/react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Field from '@/components/Field'
import { ADMIN_SETTINGS } from '@/lib/paths'
import type { Schedule } from '@/types/lowpass'

// 设置（5.6，画布 admin_settings()）：调度时间可改（R-1.1 精确到分）；白名单只读（R-5.5 由环境配置）。
// 告警（③）、兴趣画像与推荐理由（④）各自往这一页加节。
export type AdminSettingsShowProps = { schedule: Schedule; whitelist: string[] }

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

export default function Show({ schedule, whitelist }: AdminSettingsShowProps) {
  const form = useForm<Schedule>(schedule)
  form.transform((data) => ({ schedule: data }))
  const errors = form.errors as unknown as Record<string, string | string[] | undefined>

  function submit(event: React.FormEvent) {
    event.preventDefault()
    form.patch(ADMIN_SETTINGS)
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
    </AdminPage>
  )
}

Show.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
