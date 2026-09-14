import { router, useForm } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Field from '@/components/Field'
import InterestAreaRow from '@/components/InterestAreaRow'
import { ADMIN_SETTINGS, ADMIN_TEST_ALERT } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { AlertChannel, AlertChannels, InterestArea, ModelConfig, ReasonsStatus, Schedule } from '@/types/lowpass'

// 设置（5.6，画布 admin_settings()）：调度时间可改（R-1.1 精确到分）；白名单只读（R-5.5 由环境配置）。
// 告警渠道状态与测试告警（③）在这一页；兴趣画像与推荐理由（④，R-9.5、R-9.9、D18、D23）往这一页加了两节。
export type AdminSettingsShowProps = { schedule: Schedule; whitelist: string[]; alerts: AlertChannels; reasons: ReasonsStatus; interest_areas: InterestArea[] }

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

export default function Show({ schedule, whitelist, alerts, reasons, interest_areas }: AdminSettingsShowProps) {
  const form = useForm<Schedule>(schedule)
  form.transform((data) => ({ schedule: data }))
  const errors = form.errors as unknown as Record<string, string | string[] | undefined>
  const configured = alerts.email.configured || alerts.webhook.configured
  const [sending, setSending] = useState(false)

  const model = useForm<ModelConfig>({ base_url: reasons.base_url, model_name: reasons.model_name, input_price: reasons.input_price, output_price: reasons.output_price, monthly_cap: reasons.monthly_cap })
  model.transform((data) => ({ model: data }))
  const modelErrors = model.errors as unknown as Record<string, string | string[] | undefined>

  function submit(event: React.FormEvent) {
    event.preventDefault()
    form.patch(ADMIN_SETTINGS)
  }

  function submitModel(event: React.FormEvent) {
    event.preventDefault()
    model.patch(ADMIN_SETTINGS)
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

      <Section title="兴趣画像">
        <div className="admin-table-wrap">
          <table className="admin-table" aria-label="兴趣画像">
            <thead><tr>{['名称', '关键词', '排序', '启用', '操作'].map((h) => <th key={h} className="cjk" style={{ fontSize: 'var(--fs-13)', color: 'var(--ink2)', textAlign: 'left' }}>{h}</th>)}</tr></thead>
            <tbody>
              {interest_areas.map((area) => <InterestAreaRow key={area.id} area={area} />)}
              {/* 空白的新增行按行数取 key：新增成功后 props 回来行数就变了，这一行重新挂载，刚提交过的字自己清掉 */}
              <InterestAreaRow key={`new-${interest_areas.length}`} />
            </tbody>
          </table>
        </div>
      </Section>

      <Section title="推荐理由">
        {reasons.configured ? null : <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: 'var(--ink2)' }}>未配置模型供应商</span>}
        <form className="admin-form-row" onSubmit={submitModel} style={{ alignItems: 'flex-start' }}>
          <Field label="接口地址" name="base_url" value={model.data.base_url} onChange={(v) => model.setData('base_url', v)} mono width={320} note="OpenAI 兼容的 chat completions 地址" error={fieldError(modelErrors, 'base_url')} />
          <Field label="模型名" name="model_name" value={model.data.model_name} onChange={(v) => model.setData('model_name', v)} mono width={200} />
          <Field label="输入单价" name="input_price" value={model.data.input_price} onChange={(v) => model.setData('input_price', v)} mono width={120} note="每百万 token" error={fieldError(modelErrors, 'input_price')} />
          <Field label="输出单价" name="output_price" value={model.data.output_price} onChange={(v) => model.setData('output_price', v)} mono width={120} error={fieldError(modelErrors, 'output_price')} />
          <Field label="月费用上限" name="monthly_cap" value={model.data.monthly_cap} onChange={(v) => model.setData('monthly_cap', v)} mono width={120} note="0 = 不限" error={fieldError(modelErrors, 'monthly_cap')} />
          <div style={{ paddingTop: 26 }}><button type="submit" className="btn-primary" disabled={model.processing}>保存</button></div>
        </form>
        <div className="kv-row"><span className="kv-key">密钥</span><div className="kv-value"><span className="cjk" style={{ fontSize: 'var(--fs-15)', color: reasons.key_configured ? 'var(--ink)' : 'var(--ink2)' }}>{reasons.key_configured ? '密钥：已配置' : '密钥：未配置'}</span></div></div>
        <div className="reasons-usage">
          <Mixed text={`本月 ${reasons.month_calls} 次 · 费用 ${reasons.month_cost} / 上限 ${reasons.monthly_cap === '0' ? '不限' : reasons.monthly_cap}`} />
          <Mixed text={`今日 ${reasons.today_calls} 次`} />
        </div>
      </Section>
    </AdminPage>
  )
}

Show.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
