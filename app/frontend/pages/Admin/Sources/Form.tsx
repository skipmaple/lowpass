import { router, useForm } from '@inertiajs/react'
import { useEffect, useRef, useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import { Ctrl } from '@/components/Ctrl'
import Field from '@/components/Field'
import Icon from '@/components/Icon'
import SegButtons from '@/components/SegButtons'
import { testFetch } from '@/lib/admin'
import { ADMIN_SOURCES, adminSourceHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { Adapter, AdapterOption, AdminSourceForm, Publication, SourceConfig, TestFetchResult } from '@/types/lowpass'

// 新建 / 编辑来源（R-3.2 到 R-3.4，画布 admin_source_form() 与 admin_source_forms()）：适配器分段（编辑时是文字），
// 按适配器画字段，「测试抓取」是 JSON 端点、预览画在下面，「保存」走 Inertia 表单。错误按字段显示（键是 name / config.<字段>）。
export type AdminSourcesFormProps = { source: AdminSourceForm; adapters: AdapterOption[] }

type FormData = { name: string; adapter: Adapter; publication: Publication; sort_order: string; config: Record<string, string> }

// 表单里所有值都是字符串；归一化与范围校验在服务端（Source::Config）
const DEFAULTS: Record<Adapter, Record<string, string>> = {
  hacker_news: { list: 'top', count: '10', min_score: '0' },
  github_trending: { languages: '', count: '10' },
  rss: { feed_url: '', count: '10', window_hours: '24' },
  ruanyf_weekly: { min_items: '5' },
}

function toStrings(config: SourceConfig): Record<string, string> {
  return Object.fromEntries(Object.entries(config).map(([key, value]) => [key, Array.isArray(value) ? value.join(', ') : String(value ?? '')]))
}

// 项目全局把 Inertia 的 errorValueType 定成 string[]（types/globals.d.ts，配合 createInertiaApp 的 withAllErrors:
// true，每个字段收全部错误消息）；表单按字段只显示第一条。测试用的 useForm 替身已经按字段取第一条，
// 传来的就是纯字符串——两种形状都按「数组取第一条，字符串原样」处理
function fieldError(errors: Record<string, string | string[] | undefined>, key: string): string | undefined {
  const value = errors[key]
  return Array.isArray(value) ? value[0] : value
}

export default function Form({ source, adapters }: AdminSourcesFormProps) {
  const editing = source.id !== null
  const form = useForm<FormData>(`Source:${source.id ?? 'new'}`, {
    name: source.name,
    adapter: source.adapter,
    publication: source.publication,
    sort_order: String(source.sort_order),
    config: { ...DEFAULTS[source.adapter], ...toStrings(source.config) },
  })
  // useForm 提交时把 data 原样 POST 顶层键；控制器 params.require(:source) 要嵌套键，提交前包一层
  form.transform((data) => ({ source: data }))
  const [result, setResult] = useState<TestFetchResult | null>(null)
  const [testing, setTesting] = useState(false)
  const [stale, setStale] = useState(false)
  const [testedAt, setTestedAt] = useState('')
  const [saveStatus, setSaveStatus] = useState('')
  const revision = useRef(0)
  const saving = useRef(false)

  useEffect(() => {
    if (!form.isDirty) return
    function unload(event: BeforeUnloadEvent) {
      if (!saving.current) { event.preventDefault(); event.returnValue = '' }
    }
    window.addEventListener('beforeunload', unload)
    const remove = router.on('before', (event) => {
      if (!saving.current && !window.confirm('更改尚未保存，确认离开？')) event.preventDefault()
    })
    return () => { window.removeEventListener('beforeunload', unload); remove() }
  }, [form.isDirty])

  function changed() {
    revision.current += 1
    if (result || testing) setStale(true)
    setResult(null)
    setSaveStatus('')
  }

  function setValue<K extends keyof FormData>(key: K, value: FormData[K]) {
    changed()
    form.setData((current) => ({ ...current, [key]: value }))
  }

  const option = adapters.find((a) => a.key === form.data.adapter) ?? adapters[0]
  const errors = form.errors as unknown as Record<string, string | string[] | undefined>

  function setConfig(key: string, value: string) {
    setValue('config', { ...form.data.config, [key]: value })
  }

  function pickAdapter(key: string) {
    changed()
    const adapter = key as Adapter
    const next = adapters.find((a) => a.key === adapter)!
    // 真实 useForm 的 setData 传对象是整份替换（commitData 直接顶掉 data，不是合并），传一个只带
    // adapter/publication/config 三个键的对象会把 name、sort_order 丢掉；用函数形式自己展开 ...current 才保留其它字段
    form.setData((current) => ({ ...current, adapter, publication: next.publications[0], config: { ...DEFAULTS[adapter] } }))
    setResult(null)
  }

  async function runTest() {
    const testedRevision = revision.current
    setTesting(true)
    setStale(false)
    try {
      const outcome = await testFetch({ id: source.id, name: form.data.name, adapter: form.data.adapter, publication: form.data.publication, config: form.data.config })
      if (testedRevision !== revision.current) return
      setTestedAt(new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false }))
      setResult(outcome)
      if (outcome.ok && outcome.feed_title && form.data.name.trim() === '') form.setData('name', outcome.feed_title)
    } catch (error) {
      if (testedRevision !== revision.current) return
      setTestedAt(new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false }))
      setResult({ ok: false, entries: [], warnings: [], parsed: 0, dropped: 0, duration_ms: 0, feed_title: null, error: error instanceof Error ? error.message : '请求失败' })
    } finally {
      setTesting(false)
    }
  }

  function submit(event: React.FormEvent) {
    event.preventDefault()
    saving.current = true
    const options = { onError: () => setSaveStatus('未能保存，请检查字段'), onFinish: () => { saving.current = false } }
    if (editing) form.patch(adminSourceHref(source.id!), options)
    else form.post(ADMIN_SOURCES, options)
  }

  const config = form.data.config

  return (
    <AdminPage section="sources" big={editing ? `编辑来源 · ${source.name}` : '新建来源'} bottom={option.label} controls={<Ctrl href={ADMIN_SOURCES} label="返回列表" icon="chevron-left" side="left" />}>
      <form className="admin-form" onSubmit={submit}>
        {editing ? (
          <div className="field">
            <span className="field-label">来源类型</span>
            <Mixed text={option.label} font="latin" size="var(--fs-15)" color="var(--ink)" />
          </div>
        ) : (
          <div className="field">
            <span className="field-label">来源类型</span>
            <SegButtons label="来源类型" options={adapters.map((a) => ({ value: a.key, label: a.label }))} value={form.data.adapter} onChange={pickAdapter} />
          </div>
        )}

        {form.data.adapter === 'rss' ? <Field label="feed 地址" name="feed_url" value={config.feed_url ?? ''} onChange={(v) => setConfig('feed_url', v)} mono type="url" required error={fieldError(errors, 'config.feed_url')} /> : null}

        <div className="admin-form-row">
          <Field label="名称" name="name" required value={form.data.name} onChange={(v) => setValue('name', v)} note={form.data.adapter === 'rss' ? '默认取 feed 标题' : undefined} error={fieldError(errors, 'name')} width={320} />
          <div className="field">
            <span className="field-label">刊物</span>
            <SegButtons
              label="刊物"
              options={[
                { value: 'daily', label: '日刊', disabled: !option.publications.includes('daily') },
                { value: 'weekly', label: '周刊', disabled: !option.publications.includes('weekly') },
              ]}
              value={form.data.publication}
              onChange={(v) => setValue('publication', v as Publication)}
            />
            {option.publications.length === 1 ? <span className="field-note">此来源类型仅支持{option.publications[0] === 'daily' ? '日刊' : '周刊'}</span> : null}
            {fieldError(errors, 'publication') ? <span className="notice-line"><Icon name="triangle-alert" size={14} color="var(--ink2)" /><span>{fieldError(errors, 'publication')}</span></span> : null}
          </div>
        </div>

        {form.data.adapter === 'hacker_news' ? (
          <>
            <div className="field">
              <span className="field-label">榜单</span>
              <SegButtons label="榜单" options={[{ value: 'top', label: 'top' }, { value: 'best', label: 'best' }]} value={config.list ?? 'top'} onChange={(v) => setConfig('list', v)} />
            </div>
            <div className="admin-form-row">
              <Field label="条数" name="count" value={config.count ?? ''} onChange={(v) => setConfig('count', v)} mono type="number" min={1} max={100} width={160} note="1 到 100" error={fieldError(errors, 'config.count')} />
              <Field label="最低分数" name="min_score" value={config.min_score ?? ''} onChange={(v) => setConfig('min_score', v)} mono type="number" min={0} width={160} error={fieldError(errors, 'config.min_score')} />
            </div>
          </>
        ) : null}

        {form.data.adapter === 'github_trending' ? (
          <>
            <Field label="语言列表" name="languages" value={config.languages ?? ''} onChange={(v) => setConfig('languages', v)} note="最多 3 个，逗号分隔，留空为综合榜" error={fieldError(errors, 'config.languages')} />
            <Field label="每语言条数" name="count" value={config.count ?? ''} onChange={(v) => setConfig('count', v)} mono type="number" min={1} max={25} width={160} note="1 到 25；综合榜 10，多语言各 5" error={fieldError(errors, 'config.count')} />
          </>
        ) : null}

        {form.data.adapter === 'rss' ? (
          <div className="admin-form-row">
            <Field label="条数上限" name="count" value={config.count ?? ''} onChange={(v) => setConfig('count', v)} mono type="number" min={1} max={50} width={160} note="1 到 50" error={fieldError(errors, 'config.count')} />
            {form.data.publication === 'daily' ? (
              <Field label="时间窗口（小时）" name="window_hours" value={config.window_hours ?? ''} onChange={(v) => setConfig('window_hours', v)} mono type="number" min={1} max={72} width={160} note="1 到 72" error={fieldError(errors, 'config.window_hours')} />
            ) : null}
          </div>
        ) : null}

        {form.data.adapter === 'ruanyf_weekly' ? (
          <div className="admin-form-row">
            <Field label="仓库" name="repo" value="ruanyf/weekly" onChange={() => {}} mono readOnly width={320} note="固定，不可改" />
            <Field label="最少条目阈值" name="min_items" value={config.min_items ?? ''} onChange={(v) => setConfig('min_items', v)} mono type="number" min={1} width={160} note="低于此值降级为整期一条并告警" error={fieldError(errors, 'config.min_items')} />
          </div>
        ) : null}

        <Field label="排序值" name="sort_order" value={form.data.sort_order} onChange={(v) => setValue('sort_order', v)} mono type="number" min={0} width={160} error={fieldError(errors, 'sort_order')} />

        <div className="admin-form-buttons">
          <button type="button" className="ctrl" disabled={testing} onClick={runTest}>
            <Icon name="refresh-cw" color="currentColor" />
            <span>{testing ? '测试中…' : '测试抓取'}</span>
          </button>
          <button type="submit" className="btn-primary" disabled={form.processing}>
            {form.processing ? '正在保存…' : '保存'}
          </button>
          {result && !result.ok ? <span className="field-note">尚未通过测试，仍可保存。</span> : null}
        </div>
      </form>

      <div role="status" className="field-note">
        {form.isDirty ? <p>有未保存的更改</p> : null}
        {stale ? <p>配置已变化，请重新测试</p> : null}
        {saveStatus ? <p>{saveStatus}</p> : null}
        {result ? <p>测试时间（Asia/Shanghai）：{testedAt}</p> : null}
      </div>
      {result ? <Preview result={result} /> : null}
    </AdminPage>
  )
}

// R-3.3 前 5 条规范化条目与解析警告；失败只有一句原因
function Preview({ result }: { result: TestFetchResult }) {
  if (!result.ok) {
    return (
      <div className="preview">
        <div className="preview-warning">
          <Icon name="triangle-alert" size={14} color="var(--ink2)" />
          <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: 'var(--ink)' }}>{result.error}</span>
        </div>
      </div>
    )
  }

  return (
    <div className="preview">
      <div className="preview-head">
        <span className="cjk" style={{ fontSize: 'var(--fs-15)' }}>测试抓取 · 前 5 条</span>
        <Mixed text={`用时 ${(result.duration_ms / 1000).toFixed(1)} 秒 · 解析 ${result.parsed} 条 · 丢弃 ${result.dropped} 条`} />
      </div>
      {result.entries.map((entry, index) => (
        <div key={entry.url + index} className="preview-row">
          <span className="data">{index + 1}</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
            <a className="t" href={entry.url} target="_blank" rel="noopener noreferrer">
              <Mixed text={entry.title} font="latin" size="var(--fs-15)" color="var(--ink)" />
            </a>
            <Mixed text={[entry.author, entry.published_label, ...Object.entries(entry.meta).map(([k, v]) => `${k} ${v}`)].filter(Boolean).join(' · ')} />
          </div>
        </div>
      ))}
      {result.warnings.map((warning) => (
        <div key={warning} className="preview-warning">
          <Icon name="triangle-alert" size={14} color="var(--ink2)" />
          <span>{warning}</span>
        </div>
      ))}
    </div>
  )
}

Form.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
