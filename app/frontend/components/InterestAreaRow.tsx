import { router } from '@inertiajs/react'
import { useState } from 'react'

import { ADMIN_INTEREST_AREAS, adminInterestAreaHref } from '@/lib/paths'
import type { InterestArea } from '@/types/lowpass'

// 兴趣画像的一行（设计 §6.1）：名称、关键词、排序、启用，行内改、保存 / 删除；最后一行是新增
type Props = { area?: InterestArea }

export default function InterestAreaRow({ area }: Props) {
  const [name, setName] = useState(area?.name ?? '')
  const [keywords, setKeywords] = useState(area?.keywords ?? '')
  const [sortOrder, setSortOrder] = useState(String(area?.sort_order ?? 0))
  const [enabled, setEnabled] = useState(area?.enabled ?? true)
  const payload = { interest_area: { name, keywords, sort_order: Number(sortOrder) || 0, enabled } }

  return (
    <tr>
      <td><input aria-label="名称" className="field-input field-input-cjk" value={name} onChange={(e) => setName(e.target.value)} style={{ width: 160 }} /></td>
      <td><input aria-label="关键词" className="field-input field-input-cjk" value={keywords} onChange={(e) => setKeywords(e.target.value)} style={{ width: '100%' }} /></td>
      <td><input aria-label="排序" className="field-input" inputMode="numeric" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} style={{ width: 64 }} /></td>
      <td><label className="cjk" style={{ fontSize: 'var(--fs-13)' }}><input type="checkbox" checked={enabled} onChange={(e) => setEnabled(e.target.checked)} /> 启用</label></td>
      <td className="admin-actions">
        {area ? (
          <>
            <button type="button" className="link-button" onClick={() => router.patch(adminInterestAreaHref(area.id), payload)}>保存</button>
            <button type="button" className="link-button" onClick={() => router.delete(adminInterestAreaHref(area.id))}>删除</button>
          </>
        ) : (
          <button type="button" className="link-button" onClick={() => router.post(ADMIN_INTEREST_AREAS, payload)}>新增</button>
        )}
      </td>
    </tr>
  )
}
