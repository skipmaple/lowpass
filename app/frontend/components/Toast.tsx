import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'

import Icon, { type IconName } from '@/components/Icon'
import type { Flash } from '@/types/lowpass'

// 操作反馈（画布 toast()）：页面顶部一行 44px，1px 墨线纸底，图标 + 文楷 15 + 关闭叉；
// info / ok 5 秒自动收起，鼠标停留或焦点在提示上时暂停；fail 不收（设计 skill「状态」：失败的要留着给人看）。
export type ToastKind = 'info' | 'ok' | 'fail'
const ICONS: Record<ToastKind, IconName> = { info: 'clock', ok: 'check', fail: 'triangle-alert' }
const AUTO_HIDE_MS = 5000

// 提示区由 Layout 常驻画一个（固定在视口顶部、不占文档流，带 role="status"）：提示出现与收起时正文不跳，
// 提示插进一个早已存在的 live region，读屏才会播报。flash 与页面自己推的都画进这同一个区域，叠成一列。
// 没有 Layout 的地方（单测）拿到 undefined，就地画一个区域。
export const ToastRegion = createContext<HTMLElement | null | undefined>(undefined)

export default function Toast({ kind, text, onClose }: { kind: ToastKind; text: string; onClose: () => void }) {
  // 取最新的 onClose：只有 kind/text 变化才需要重开计时器。父组件重渲染（比如轮询）常会传一个
  // 新的内联 onClose 引用——若把它放进依赖数组，计时器会被重置，一条提示在轮询期间可能永远
  // 等不到自动收起。
  const closeRef = useRef(onClose)
  closeRef.current = onClose
  const [paused, setPaused] = useState(false)

  useEffect(() => {
    if (kind === 'fail' || paused) return
    const timer = setTimeout(() => closeRef.current(), AUTO_HIDE_MS)
    return () => clearTimeout(timer)
  }, [kind, text, paused])

  return (
    <div
      className="toast"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocus={() => setPaused(true)}
      onBlur={(event) => { if (!event.currentTarget.contains(event.relatedTarget)) setPaused(false) }}
    >
      <Icon name={ICONS[kind]} size={16} />
      <span className="toast-text">{text}</span>
      <button type="button" className="toast-close" aria-label="关闭" onClick={onClose}>
        <Icon name="x" size={14} color="var(--ink2)" />
      </button>
    </div>
  )
}

export type ToastItem = { id: string; kind: ToastKind; text: string }

// 页面自己推的提示（重抓结束、测试抓取的结果）
export function useToasts() {
  const [toasts, setToasts] = useState<ToastItem[]>([])
  const dismiss = useCallback((id: string) => setToasts((list) => list.filter((t) => t.id !== id)), [])
  const push = useCallback((kind: ToastKind, text: string, id = `${Date.now()}-${Math.random()}`) => {
    setToasts((list) => (list.some((t) => t.id === id) ? list : [...list, { id, kind, text }]))
  }, [])
  return { toasts, push, dismiss }
}

// flash 带来的提示（notice → ok，alert → fail）加页面自己推的，一起画进提示区
export function Toasts({ flash, items = [], onDismiss }: { flash?: Flash; items?: ToastItem[]; onDismiss?: (id: string) => void }) {
  const [hidden, setHidden] = useState<string[]>([])
  useEffect(() => setHidden([]), [flash?.id, flash?.notice, flash?.alert])
  const rows: ToastItem[] = []
  if (flash?.notice && !hidden.includes('notice')) rows.push({ id: 'notice', kind: 'ok', text: flash.notice })
  if (flash?.alert && !hidden.includes('alert')) rows.push({ id: 'alert', kind: 'fail', text: flash.alert })
  rows.push(...items)
  const region = useContext(ToastRegion)

  const list = rows.map((row) => (
    <Toast
      key={row.id === 'notice' || row.id === 'alert' ? `${flash?.id ?? ''}-${row.id}-${row.text}` : row.id}
      kind={row.kind}
      text={row.text}
      onClose={() => (row.id === 'notice' || row.id === 'alert' ? setHidden((h) => [...h, row.id]) : onDismiss?.(row.id))}
    />
  ))

  if (region === undefined) return <div className="toasts" role="status">{list}</div>
  // Layout 的区域在同一次提交里才挂上：第一帧还没有节点，下一帧再画进去
  return region ? createPortal(list, region) : null
}
