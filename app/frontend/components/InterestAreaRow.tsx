import type { Page } from '@inertiajs/core'
import { router } from '@inertiajs/react'
import { useEffect, useId, useRef, useState } from 'react'

import Dialog from '@/components/Dialog'
import Field from '@/components/Field'
import { useDraftForm } from '@/lib/drafts'
import { ADMIN_INTEREST_AREAS, adminInterestAreaHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { InterestArea } from '@/types/lowpass'

type Props = {
  area?: InterestArea
  onStart: () => void
  onFinish: () => void
  onDirtyChange: (id: string, dirty: boolean) => void
  internalVisit: (action: () => void) => void
}
type Draft = { name: string; keywords: string; sort_order: string; enabled: boolean }
const EMPTY: Draft = { name: '', keywords: '', sort_order: '0', enabled: true }

export default function InterestAreaRow({ area, onStart, onFinish, onDirtyChange, internalVisit }: Props) {
  const rowKey = area?.id ?? 'new'
  const draft = useDraftForm<Draft>(`interest:${rowKey}`, area ? { name: area.name, keywords: area.keywords, sort_order: String(area.sort_order), enabled: area.enabled } : EMPTY)
  const [editing, setEditing] = useState(!area || draft.isDirty)
  const [busy, setBusy] = useState<'save' | 'delete' | null>(null)
  const [message, setMessage] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [confirming, setConfirming] = useState(false)
  const [deleted, setDeleted] = useState(false)
  const deletedRef = useRef(false)
  const mounted = useRef(true)
  const formRef = useRef<HTMLFormElement>(null)
  const editorId = useId()

  useEffect(() => {
    mounted.current = true
    return () => { mounted.current = false }
  }, [])
  useEffect(() => {
    onDirtyChange(rowKey, draft.isDirty)
    return () => onDirtyChange(rowKey, false)
  }, [rowKey, draft.isDirty, onDirtyChange])
  useEffect(() => {
    if (!busy && Object.keys(errors).length) formRef.current?.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus()
  }, [errors, busy])

  function change<K extends keyof Draft>(key: K, value: Draft[K]) {
    draft.setData((current) => ({ ...current, [key]: value }))
    setMessage('')
    setErrors((current) => { const next = { ...current }; delete next[key]; return next })
  }

  function save(remove = false) {
    if (busy) return
    setBusy(remove ? 'delete' : 'save')
    setMessage('')
    setErrors({})
    let started = false
    const submitted = { ...draft.data }
    const options = {
      async: true,
      preserveState: true,
      // Refresh membership once every outstanding mutation has completed. Partial
      // outcomes cannot resurrect a row from another request's older snapshot.
      only: ['flash', 'errors'],
      onStart: () => { started = true; onStart() },
      preserveScroll: true,
      onSuccess: (page: Page) => {
        // Inertia may discard an async response after navigation and call this
        // callback with the destination page. It cannot confirm our draft saved.
        if (!mounted.current) return
        const alert = (page.props.flash as { alert?: string } | undefined)?.alert
        setMessage(alert || (remove ? '已删除' : '已保存'))
        if (!alert) {
          if (remove) { deletedRef.current = true; setDeleted(true) }
          if (!area) draft.setData(EMPTY)
          draft.accept(area ? submitted : EMPTY)
          setConfirming(false)
        }
      },
      onError: (failures: Record<string, string | string[]>) => {
        if (!mounted.current) return
        setErrors(Object.fromEntries(Object.entries(failures).map(([key, value]) => [key, Array.isArray(value) ? value[0] : value])))
        setMessage(remove ? '未能删除，请重试' : '未能保存，请检查字段')
      },
      onFinish: () => { if (mounted.current) setBusy(null); if (started) onFinish() },
    }
    const payload = { interest_area: { ...submitted, sort_order: Number(submitted.sort_order) || 0 } }
    internalVisit(() => {
      if (remove && area) router.delete(adminInterestAreaHref(area.id), options)
      else if (area) router.patch(adminInterestAreaHref(area.id), payload, options)
      else router.post(ADMIN_INTEREST_AREAS, payload, options)
    })
  }

  if (deleted) return null

  return (
    <tr className={`interest-row${editing ? ' is-editing' : ''}${area ? '' : ' interest-new'}`}>
      <td>
        {area ? <div className="interest-summary">
          <div className="interest-summary-identity"><Mixed text={draft.data.name} size="var(--fs-15)" color="var(--ink)" /><span className="field-note">{draft.data.enabled ? '已启用' : '已停用'} · 排序 {draft.data.sort_order}</span></div>
          <div className="interest-summary-keywords"><Mixed text={draft.data.keywords || '未设关键词'} /></div>
          <div className="admin-actions">
            <button type="button" className="link-button" aria-expanded={editing} aria-controls={editorId} disabled={busy !== null} onClick={() => setEditing(!editing)}>{editing ? '收起编辑' : '编辑'}</button>
            <button type="button" className="link-button" disabled={busy !== null} onClick={() => setConfirming(true)}>{busy === 'delete' ? '正在删除…' : '删除'}</button>
          </div>
        </div> : <h3 className="field-label">新增兴趣画像</h3>}
        {editing ? <form ref={formRef} id={editorId} className="interest-editor" onSubmit={(event) => { event.preventDefault(); save() }}>
          <fieldset className="form-fieldset admin-form-row" disabled={busy !== null}>
            <Field label="名称" name="name" value={draft.data.name} onChange={(value) => change('name', value)} required width={160} note="最多 20 字" error={errors.name} />
            <div className="interest-keywords"><Field label="关键词" name="keywords" value={draft.data.keywords} onChange={(value) => change('keywords', value)} note="最多 200 字" error={errors.keywords} /></div>
            <Field label="排序" name="sort_order" value={draft.data.sort_order} onChange={(value) => change('sort_order', value)} type="number" mono width={80} error={errors.sort_order} />
            <label className="interest-enabled"><input type="checkbox" checked={draft.data.enabled} onChange={(event) => change('enabled', event.target.checked)} /> 启用</label>
            <button type="submit" className="btn-primary">{busy === 'save' ? '正在保存…' : area ? '保存' : '新增'}</button>
          </fieldset>
        </form> : null}
        <span role="status" className="field-note">{message || (draft.isDirty ? '有未保存的更改' : '')}</span>
        {draft.conflicted ? <p role="status" className="field-note">此画像已有变化，请核对恢复的草稿后保存。</p> : null}
        <Dialog open={confirming} text={`确认删除兴趣画像「${area?.name}」？`} cancel="取消" confirm={busy === 'delete' ? '正在删除…' : '确认删除'} busy={busy !== null} onCancel={() => setConfirming(false)} onConfirm={() => save(true)} returnFocus={() => deletedRef.current ? document.querySelector<HTMLElement>('#interests .admin-section-title') : null}>
          {message ? <p role="alert" className="field-note">{message}</p> : null}
        </Dialog>
      </td>
    </tr>
  )
}
