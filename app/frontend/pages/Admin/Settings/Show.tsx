import { router } from '@inertiajs/react'
import { useCallback, useEffect, useRef, useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Field from '@/components/Field'
import InterestAreaRow from '@/components/InterestAreaRow'
import { useDraftAccount, useDraftForm, useUnsavedChanges } from '@/lib/drafts'
import { ADMIN_SETTINGS, ADMIN_TEST_ALERT } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { AlertChannel, AlertChannels, InterestArea, ModelConfig, ReasonsStatus, Schedule } from '@/types/lowpass'

// 设置（5.6，画布 admin_settings()）：调度时间可改（R-1.1 精确到分）；白名单只读（R-5.5 由环境配置）。
// 告警渠道状态与测试告警（③）在这一页；兴趣画像与推荐理由（④，R-9.5、R-9.9、D18、D23）往这一页加了两节。
export type AdminSettingsShowProps = { schedule: Schedule; whitelist: string[]; alerts: AlertChannels; reasons: ReasonsStatus; interest_areas: InterestArea[] }

function Section({ title, id, children }: React.PropsWithChildren<{ title: string; id: string }>) {
  return (
    <section className="admin-section" id={id}>
      <h2 className="admin-section-title" tabIndex={-1}>{title}</h2>
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

export default function Show(props: AdminSettingsShowProps) {
  const account = useDraftAccount()
  return <Settings key={account ?? 'anonymous'} {...props} />
}

function Settings({ schedule, whitelist, alerts, reasons, interest_areas }: AdminSettingsShowProps) {
  const form = useDraftForm<Schedule>('settings:schedule', schedule)
  form.transform((data) => ({ schedule: data }))
  const errors = form.errors as unknown as Record<string, string | string[] | undefined>
  const configured = alerts.email.configured || alerts.webhook.configured
  const [sending, setSending] = useState(false)
  const [scheduleStatus, setScheduleStatus] = useState('')
  const [modelStatus, setModelStatus] = useState('')
  const [alertStatus, setAlertStatus] = useState('')
  const [scheduleBusy, setScheduleBusy] = useState(false)
  const [modelBusy, setModelBusy] = useState(false)
  const [interestDrafts, setInterestDrafts] = useState<Record<string, boolean>>({})
  const interestDirtyChanged = useCallback((id: string, dirty: boolean) => {
    setInterestDrafts((current) => current[id] === dirty ? current : { ...current, [id]: dirty })
  }, [])
  const scheduleRef = useRef<HTMLFormElement>(null)
  const modelRef = useRef<HTMLFormElement>(null)
  const [focusError, setFocusError] = useState<'schedule' | 'model' | null>(null)
  useEffect(() => {
    if (focusError && !(focusError === 'schedule' ? scheduleBusy : modelBusy)) {
      const target = focusError === 'schedule' ? scheduleRef : modelRef
      target.current?.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus()
      setFocusError(null)
    }
  }, [focusError, scheduleBusy, modelBusy])

  const pendingInterests = useRef(0)
  const mounted = useRef(true)
  const interestReload = useRef<{ cancel: () => void } | null>(null)
  useEffect(() => {
    mounted.current = true
    return () => { mounted.current = false; interestReload.current?.cancel() }
  }, [])

  function interestStarted() {
    pendingInterests.current += 1
    interestReload.current?.cancel()
    interestReload.current = null
  }

  function interestFinished() {
    if (pendingInterests.current === 0) return
    pendingInterests.current -= 1
    if (pendingInterests.current === 0 && mounted.current) {
      internalVisit(() => router.reload({
        only: ['interest_areas'],
        onCancelToken: (token) => { interestReload.current = token },
      }))
    }
  }

  const model = useDraftForm<ModelConfig>('settings:model', { currency: reasons.currency, currency_confirmation: '', base_url: reasons.base_url, model_name: reasons.model_name, input_price: reasons.input_price, output_price: reasons.output_price, monthly_cap: reasons.monthly_cap })
  model.transform((data) => ({ model: data }))
  const modelErrors = model.errors as unknown as Record<string, string | string[] | undefined>

  const internalVisit = useUnsavedChanges(form.isDirty || model.isDirty || Object.values(interestDrafts).some(Boolean))

  function scheduleChange(key: keyof Schedule, value: string) {
    form.setData(key, value)
    setScheduleStatus('')
  }

  function modelChange(key: keyof ModelConfig, value: string) {
    model.setData(key, value)
    setModelStatus('')
  }

  function submit(event: React.FormEvent) {
    event.preventDefault()
    if (scheduleBusy) return
    setScheduleBusy(true)
    setScheduleStatus('')
    const submitted = { ...form.data }
    internalVisit(() => form.patch(ADMIN_SETTINGS, {
      only: ['schedule', 'flash', 'errors'],
      preserveScroll: true,
      onSuccess: () => { form.accept(submitted); setScheduleStatus('调度已保存') },
      onError: () => { setScheduleStatus('调度未保存，请检查字段'); setFocusError('schedule') },
      onFinish: () => setScheduleBusy(false),
    }))
  }

  function submitModel(event: React.FormEvent) {
    event.preventDefault()
    if (modelBusy) return
    setModelBusy(true)
    setModelStatus('')
    const submitted = { ...model.data }
    internalVisit(() => model.patch(ADMIN_SETTINGS, {
      only: ['reasons', 'flash', 'errors'],
      preserveScroll: true,
      onSuccess: () => { model.accept(submitted); setModelStatus('模型设置已保存；尚未测试连接') },
      onError: () => { setModelStatus('模型设置未保存，请检查字段'); setFocusError('model') },
      onFinish: () => setModelBusy(false),
    }))
  }

  // 一次点击一封：请求回来之前按钮禁着（每分钟 5 次的限流是后一道门）
  function sendTestAlert() {
    setSending(true)
    setAlertStatus('')
    internalVisit(() => router.post(ADMIN_TEST_ALERT, {}, { only: ['alerts', 'flash', 'errors'], preserveScroll: true, onSuccess: (page) => { const flash = page.props.flash as { alert?: string; notice?: string } | undefined; setAlertStatus(flash?.alert || flash?.notice || '') }, onError: () => setAlertStatus('测试告警未能发送，请重试'), onFinish: () => setSending(false) }))
  }

  return (
    <AdminPage section="settings" bottom="设置">
      <nav className="settings-directory" aria-label="设置目录">
        <a href="#schedule">调度</a><a href="#whitelist">管理员白名单</a><a href="#alerts">告警</a><a href="#interests">兴趣画像</a><a href="#reasons">推荐理由</a><a href="#deployment">部署配置帮助</a>
      </nav>
      <Section title="调度" id="schedule">
        <form ref={scheduleRef} onSubmit={submit}>
          <fieldset className="form-fieldset admin-form-row" disabled={scheduleBusy} style={{ alignItems: 'flex-start' }}>
            <Field label="日刊生成时间" name="daily_time" value={form.data.daily_time} onChange={(v) => scheduleChange('daily_time', v)} mono type="time" required width={160} note="Asia/Shanghai，精确到分" error={fieldError(errors, 'daily_time')} />
            <Field label="周刊检查时间" name="weekly_time" value={form.data.weekly_time} onChange={(v) => scheduleChange('weekly_time', v)} mono type="time" required width={160} note="Asia/Shanghai，精确到分" error={fieldError(errors, 'weekly_time')} />
            <div style={{ paddingTop: 26 }}>
              <button type="submit" className="btn-primary" disabled={scheduleBusy}>
                {scheduleBusy ? '正在保存…' : '保存调度'}
              </button>
            </div>
          </fieldset>
        </form>
        <span role="status" className="field-note">{scheduleStatus || (form.isDirty ? '调度有未保存的更改' : '')}</span>
        {form.conflicted ? <p role="status" className="field-note">服务端设置已有变化，请核对恢复的草稿后保存。</p> : null}
      </Section>

      <Section title="管理员白名单（只读）" id="whitelist">
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

      <Section title="告警" id="alerts">
        <ChannelRow label="邮件" channel={alerts.email} />
        <ChannelRow label="Webhook" channel={alerts.webhook} />
        <div className="admin-actions" style={{ alignItems: 'center' }}>
          <button type="button" className="btn-primary" disabled={!configured || sending} onClick={sendTestAlert}>
            {sending ? '发送中…' : '发送测试告警'}
          </button>
          {configured ? null : <span className="field-note">未配置告警渠道，无法发送测试。<a href="#deployment">查看部署配置帮助</a></span>}
        </div>
        <span role="status" className="field-note">{alertStatus}</span>
      </Section>

      <Section title="兴趣画像" id="interests">
        <div className="interest-table-wrap">
          <table className="admin-table interest-table" aria-label="兴趣画像">
            <thead><tr><th scope="col">兴趣画像</th></tr></thead>
            <tbody>
              {interest_areas.map((area) => <InterestAreaRow key={area.id} area={area} onStart={interestStarted} onFinish={interestFinished} onDirtyChange={interestDirtyChanged} internalVisit={internalVisit} />)}
              <InterestAreaRow key="new" onStart={interestStarted} onFinish={interestFinished} onDirtyChange={interestDirtyChanged} internalVisit={internalVisit} />
            </tbody>
          </table>
        </div>
      </Section>

      <Section title="推荐理由" id="reasons">
        {reasons.configured ? null : <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: 'var(--ink2)' }}>未配置模型供应商</span>}
        <form ref={modelRef} onSubmit={submitModel}>
          <fieldset className="form-fieldset admin-form-row" disabled={modelBusy} style={{ alignItems: 'flex-start' }}>
            <Field label="API 基础地址" name="base_url" value={model.data.base_url} onChange={(v) => modelChange('base_url', v)} mono width={320} note="例如 https://api.openai.com/v1；自动追加 /chat/completions。保存配置不会测试连接。" error={fieldError(modelErrors, 'base_url')} />
            <div className="model-name-field">
              <Field label="模型名" name="model_name" value={model.data.model_name} onChange={(v) => modelChange('model_name', v)} mono width={200} error={fieldError(modelErrors, 'model_name')} />
              {model.data.model_name.length > 24 ? <details className="field-note model-name-detail"><summary>查看完整模型名</summary><code>{model.data.model_name}</code></details> : null}
            </div>
            <div className="field">
              <label className="field-label" htmlFor="model-currency">记账币种</label>
              <select id="model-currency" className="field-input" value={model.data.currency} disabled={Boolean(reasons.currency && reasons.has_nonzero_costs)} aria-describedby="currency-note" aria-invalid={fieldError(modelErrors, 'currency') ? true : undefined} onChange={(event) => { modelChange('currency', event.target.value); modelChange('currency_confirmation', '') }}>
                <option value="">未指定币种</option><option value="USD">USD</option><option value="CNY">CNY</option>
              </select>
              <span id="currency-note" className="field-note">{fieldError(modelErrors, 'currency') || (reasons.currency && reasons.has_nonzero_costs ? '仍有非零历史费用，不能更改币种。' : '请明确选择账目使用的币种；数值不会换算。')}</span>
              {!reasons.currency && reasons.has_nonzero_costs && model.data.currency ? <label className="interest-enabled"><input type="checkbox" aria-describedby={fieldError(modelErrors, 'currency_confirmation') ? 'currency-confirmation-error' : undefined} checked={model.data.currency_confirmation === '1'} onChange={(event) => modelChange('currency_confirmation', event.target.checked ? '1' : '')} />确认现有单价、上限和历史费用均使用 {model.data.currency}，保留原数值。</label> : null}
              {fieldError(modelErrors, 'currency_confirmation') ? <span id="currency-confirmation-error" role="alert" className="field-note">{fieldError(modelErrors, 'currency_confirmation')}</span> : null}
            </div>
            <Field label="输入单价" name="input_price" value={model.data.input_price} onChange={(v) => modelChange('input_price', v)} mono type="number" min={0} step="any" required width={160} note={`${model.data.currency || '未指定币种'} / 百万 tokens`} error={fieldError(modelErrors, 'input_price')} />
            <Field label="输出单价" name="output_price" value={model.data.output_price} onChange={(v) => modelChange('output_price', v)} mono type="number" min={0} step="any" required width={160} note={`${model.data.currency || '未指定币种'} / 百万 tokens`} error={fieldError(modelErrors, 'output_price')} />
            <Field label="月费用上限" name="monthly_cap" value={model.data.monthly_cap} onChange={(v) => modelChange('monthly_cap', v)} mono type="number" min={0} step="any" required width={160} note={`${model.data.currency || '未指定币种'}；0 = 不限`} error={fieldError(modelErrors, 'monthly_cap')} />
            <div style={{ paddingTop: 26 }}><button type="submit" className="btn-primary" disabled={modelBusy}>{modelBusy ? '正在保存…' : '保存模型设置'}</button></div>
          </fieldset>
        </form>
        <span role="status" className="field-note">{modelStatus || (model.isDirty ? '模型设置有未保存的更改' : '')}</span>
        {model.conflicted ? <p role="status" className="field-note">服务端设置已有变化，请核对恢复的草稿后保存。</p> : null}
        <div className="kv-row"><span className="kv-key">密钥</span><div className="kv-value"><span className="cjk" style={{ fontSize: 'var(--fs-15)', color: reasons.key_configured ? 'var(--ink)' : 'var(--ink2)' }}>{reasons.key_configured ? '已配置' : '未配置'}</span></div></div>
        <div className="reasons-usage">
          <Mixed text={`本月 ${reasons.month_calls} 次 · 费用 ${reasons.month_cost} ${reasons.currency || '未指定币种'} / 上限 ${Number(reasons.monthly_cap) === 0 ? '不限' : `${reasons.monthly_cap} ${reasons.currency || '未指定币种'}`}`} />
          <Mixed text={`今日 ${reasons.today_calls} 次`} />
        </div>
      </Section>
      <Section title="部署配置帮助" id="deployment">
        <details>
          <summary>查看服务器环境变量</summary>
          <div className="deployment-help">
            <p>在服务器环境中设置，下次启动服务时载入。密钥只保存在服务器环境中，不要填入页面、代码或日志。</p>
            <p>管理员白名单：<code>ADMIN_EMAILS</code>，逗号分隔；变更在下次登录生效。</p>
            <p>模型密钥：<code>MODEL_API_KEY</code>。接口地址、模型名和价格在上方保存。</p>
            <p>邮件渠道需要 <code>ALERT_EMAIL_TO</code> 和 <code>SMTP_ADDRESS</code>；发件地址为 <code>ALERT_EMAIL_FROM</code>。SMTP 可配置 <code>SMTP_PORT</code>、<code>SMTP_USERNAME</code>、<code>SMTP_PASSWORD</code>、<code>SMTP_DOMAIN</code>、<code>SMTP_AUTHENTICATION</code>、<code>SMTP_STARTTLS</code>。</p>
            <p>Webhook 渠道：<code>ALERT_WEBHOOK_URL</code>（HTTPS）和 <code>ALERT_WEBHOOK_FORMAT</code>（generic / feishu / wecom / dingtalk）。</p>
          </div>
        </details>
      </Section>
    </AdminPage>
  )
}

Show.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
