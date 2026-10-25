import { useEffect, useState } from 'react'

import Dialog from '@/components/Dialog'
import { LOGIN, adminIssueTranslationsHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'

type Preview = { token: string; target_count: number; reassess: boolean }
class PreviewError extends Error {}

export default function AdminTranslationDialog({ periodKey, onCancel, onConfirm, returnFocus }: { periodKey: string; onCancel: () => void; onConfirm: (token: string) => void; returnFocus: () => HTMLElement | null }) {
  const [reassess, setReassess] = useState(false)
  const [preview, setPreview] = useState<Preview | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let active = true
    const controller = new AbortController()
    setPreview(null)
    setError('')
    fetch(`${adminIssueTranslationsHref(periodKey)}/new?reassess=${reassess}`, { headers: { Accept: 'application/json' }, credentials: 'same-origin', signal: controller.signal })
      .then(async (response) => {
        if (response.status === 401 || (response.redirected && new URL(response.url).pathname === LOGIN)) throw new PreviewError('登录状态已失效，请刷新后重试')
        if (!response.ok) throw new PreviewError(`无法获取预览（${response.status}），请重新打开确认`)
        let data
        try { data = await response.json() }
        catch { throw new PreviewError('预览响应无法读取，请重新打开确认') }
        if (!data || typeof data.token !== 'string' || data.token.trim() === '' || !Number.isInteger(data.target_count) || data.target_count < 0) throw new PreviewError('预览不完整，请重新打开确认')
        if (active) setPreview({ ...data, reassess })
      })
      .catch((failure: unknown) => {
        if (active) setError(failure instanceof PreviewError ? failure.message : '网络连接失败，请重新打开确认')
      })
    return () => { active = false; controller.abort() }
  }, [periodKey, reassess])

  const current = preview?.reassess === reassess ? preview : null
  return (
    <Dialog open text={`只补 ${periodKey} 本期缺译文，可能产生额外模型费用，受现有月上限约束。`} cancel="取消" confirm="提交补全" confirmDisabled={!current || current.target_count === 0} onCancel={onCancel} onConfirm={() => { if (current && current.target_count > 0) onConfirm(current.token) }} returnFocus={returnFocus}>
      <label className="admin-pending-filter"><input type="checkbox" checked={reassess} onChange={(event) => setReassess(event.target.checked)} />重新评估保留原文的条目</label>
      {error ? <p role="alert" className="form-feedback">{error}</p> : <p role="status"><Mixed text={current ? `本次处理 ${current.target_count} 条` : '正在获取预览…'} /></p>}
    </Dialog>
  )
}
