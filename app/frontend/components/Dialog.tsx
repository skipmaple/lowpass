import { createPortal } from 'react-dom'
import { useEffect, useId, useRef } from 'react'
import type * as React from 'react'

import PendingLabel from '@/components/PendingLabel'

// 确认对话框共用取消优先、焦点圈和焦点返回；表面与危险操作样式由主题决定。
// 无法确认与正在执行是两种状态：前者仍允许取消，后者保护执行中的操作。
export type DialogProps = React.PropsWithChildren<{
  open: boolean
  text: string
  cancel: string
  confirm: string
  busyConfirm?: string
  busy?: boolean
  confirmDisabled?: boolean
  tone?: 'default' | 'danger'
  returnFocus?: () => HTMLElement | null
  onCancel: () => void
  onConfirm: () => void
}>

// 纸卡里的候选控件；同组 radio 只有当前选中项参与 Tab 首尾判断。
const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

function tabStops(paper: HTMLElement | null): HTMLElement[] {
  const elements = Array.from(paper?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])
  return elements.filter((element) => {
    if (element instanceof HTMLInputElement && element.type === 'radio' && element.name) {
      const group = elements.filter((candidate): candidate is HTMLInputElement =>
        candidate instanceof HTMLInputElement && candidate.type === 'radio' && candidate.name === element.name && candidate.form === element.form)
      return element === (group.find((candidate) => candidate.checked) ?? group[0])
    }
    return true
  })
}

export default function Dialog({ open, text, cancel, confirm, busyConfirm, busy = false, confirmDisabled = false, tone = 'default', returnFocus, onCancel, onConfirm, children }: DialogProps) {
  const paperRef = useRef<HTMLDivElement>(null)
  const initialFocusRef = useRef<HTMLButtonElement>(null)
  // 问句既是看得见的标题也是纸卡的名字：aria-labelledby 指过去，读屏读到的和眼睛看到的是同一段
  const textId = useId()
  // 取最新的 onCancel：只有 open 变化才需要重挂载监听与焦点。父组件重渲染（比如 usePolling 每
  // 5 秒 reload）常会传一个新的内联 onCancel 引用——若把它放进依赖数组，副作用会跟着重跑，
  // 焦点被收回去再塞回来，用户能看见确认按钮"闪"一下。
  const cancelRef = useRef(onCancel)
  cancelRef.current = onCancel
  const busyRef = useRef(busy)
  busyRef.current = busy
  const returnFocusRef = useRef(returnFocus)
  returnFocusRef.current = returnFocus

  useEffect(() => {
    if (!open) return
    const previous = document.activeElement as HTMLElement | null
    const overflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const background = Array.from(document.body.children).filter((element) => !element.contains(paperRef.current))
    const previousInert = background.map((element) => element.hasAttribute('inert'))
    background.forEach((element) => element.setAttribute('inert', ''))
    if (busyRef.current) paperRef.current?.focus()
    else initialFocusRef.current?.focus()
    // 焦点圈：只在走到两头的那一下把焦点接回来，中间几下照旧交给浏览器
    function keepFocusInside(event: KeyboardEvent) {
      const focusable = tabStops(paperRef.current)
      if (focusable.length === 0) { event.preventDefault(); paperRef.current?.focus(); return }
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (document.activeElement === paperRef.current || document.activeElement === (event.shiftKey ? first : last)) {
        event.preventDefault()
        const wrapped = event.shiftKey ? last : first
        wrapped.focus()
      }
    }

    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape') { event.preventDefault(); if (!busyRef.current) cancelRef.current() }
      if (event.key === 'Tab') keepFocusInside(event)
    }
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = overflow
      background.forEach((element, index) => { if (!previousInert[index]) element.removeAttribute('inert') })
      const target = returnFocusRef.current?.() ?? previous
      if (target?.isConnected) target.focus()
    }
  }, [open])

  useEffect(() => {
    if (open && busy && paperRef.current?.contains(document.activeElement)) paperRef.current.focus()
  }, [open, busy])

  if (!open) return null

  return createPortal(
    <div className="dialog-shade">
      <div className="dialog" data-tone={tone} role="dialog" aria-modal="true" aria-labelledby={textId} aria-busy={busy} tabIndex={-1} ref={paperRef}>
        <p className="dialog-text" id={textId}>
          {text}
        </p>
        {children}
        <div className="dialog-actions">
          <button type="button" className="ctrl" ref={initialFocusRef} disabled={busy} onClick={onCancel}>
            {cancel}
          </button>
          <button type="button" className={`btn-primary${tone === 'danger' ? ' btn-danger' : ''}`} disabled={busy || confirmDisabled} aria-busy={busy} onClick={onConfirm}>
            {busyConfirm ? <PendingLabel idle={confirm} pending={busyConfirm} busy={busy} /> : confirm}
          </button>
        </div>
      </div>
    </div>, document.body
  )
}
