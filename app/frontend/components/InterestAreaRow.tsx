import type { Page } from '@inertiajs/core'
import { router } from '@inertiajs/react'
import { useState } from 'react'

import Dialog from '@/components/Dialog'
import Field from '@/components/Field'
import { ADMIN_INTEREST_AREAS, adminInterestAreaHref } from '@/lib/paths'
import type { InterestArea } from '@/types/lowpass'

type Props = { area?: InterestArea; onStart: () => void; onFinish: () => void }

export default function InterestAreaRow({ area, onStart, onFinish }: Props) {
  const [name, setName] = useState(area?.name ?? '')
  const [keywords, setKeywords] = useState(area?.keywords ?? '')
  const [sortOrder, setSortOrder] = useState(String(area?.sort_order ?? 0))
  const [enabled, setEnabled] = useState(area?.enabled ?? true)
  const [busy, setBusy] = useState<'save' | 'delete' | null>(null)
  const [message, setMessage] = useState('')
  const [confirming, setConfirming] = useState(false)
  const [deleted, setDeleted] = useState(false)

  function save(remove = false) {
    setBusy(remove ? 'delete' : 'save')
    setMessage('')
    let started = false
    const options = {
      async: true,
      preserveState: true,
      // Refresh membership once every outstanding mutation has completed. Partial
      // outcomes cannot resurrect a row from another request's older snapshot.
      only: ['flash', 'errors'],
      onStart: () => { started = true; onStart() },
      preserveScroll: true,
      onSuccess: (page: Page) => {
        // Existing endpoint reports validation failures in flash, not Inertia errors.
        const alert = (page.props.flash as { alert?: string } | undefined)?.alert
        setMessage(alert || (remove ? '已删除' : '已保存'))
        if (!alert && remove) setDeleted(true)
        if (!alert && !area) { setName(''); setKeywords(''); setSortOrder('0'); setEnabled(true) }
        setConfirming(false)
      },
      onError: () => setMessage('未能保存，请检查输入后重试'),
      onFinish: () => { setBusy(null); if (started) onFinish() },
    }
    const payload = { interest_area: { name, keywords, sort_order: Number(sortOrder) || 0, enabled } }
    if (remove && area) router.delete(adminInterestAreaHref(area.id), options)
    else if (area) router.patch(adminInterestAreaHref(area.id), payload, options)
    else router.post(ADMIN_INTEREST_AREAS, payload, options)
  }

  if (deleted) return null

  return (
    <tr className="interest-row">
      <td><Field label="名称" name="name" value={name} onChange={setName} required width={160} /></td>
      <td className="interest-keywords"><Field label="关键词" name="keywords" value={keywords} onChange={setKeywords} /></td>
      <td><Field label="排序" name="sort_order" value={sortOrder} onChange={setSortOrder} type="number" mono width={80} /></td>
      <td><label className="interest-enabled"><input type="checkbox" checked={enabled} onChange={(event) => setEnabled(event.target.checked)} /> 启用</label></td>
      <td>
        <div className="admin-actions">
          <button type="button" className="link-button" disabled={busy !== null} onClick={() => save()}>{busy === 'save' ? '正在保存…' : area ? '保存' : '新增'}</button>
          {area ? <button type="button" className="link-button" disabled={busy !== null} onClick={() => setConfirming(true)}>{busy === 'delete' ? '正在删除…' : '删除'}</button> : null}
        </div>
        <span role="status" className="field-note">{message}</span>
        <Dialog open={confirming} text={`确认删除兴趣画像「${area?.name}」？`} cancel="取消" confirm={busy === 'delete' ? '正在删除…' : '确认删除'} busy={busy !== null} onCancel={() => setConfirming(false)} onConfirm={() => save(true)} />
      </td>
    </tr>
  )
}
