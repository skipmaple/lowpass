import { createPortal } from 'react-dom'
import { useEffect, useId, useRef } from 'react'
import type * as React from 'react'

// 确认对话框（画布 dialog()）：整页 40% 墨色遮罩，480px 纸卡，1px 墨线加 2px 顶线，文楷 20 的问句，
// 右下「取消」描边 + 确认反白。Escape 取消；打开时焦点进取消按钮，关掉后回到打开前的元素；
// Tab / Shift+Tab 在纸卡里转圈，不跑到遮罩后面那一页上。
export type DialogProps = React.PropsWithChildren<{
  open: boolean
  text: string
  cancel: string
  confirm: string
  busy?: boolean
  returnFocus?: () => HTMLElement | null
  onCancel: () => void
  onConfirm: () => void
}>

// 纸卡里可以停焦点的元素，顺序就是 Tab 的顺序
const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

export default function Dialog({ open, text, cancel, confirm, busy = false, returnFocus, onCancel, onConfirm, children }: DialogProps) {
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
      const focusable = Array.from(paperRef.current?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])
      if (focusable.length === 0) { event.preventDefault(); paperRef.current?.focus(); return }
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (document.activeElement === (event.shiftKey ? first : last)) {
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
      <div className="dialog" role="dialog" aria-modal="true" aria-labelledby={textId} aria-busy={busy} tabIndex={-1} ref={paperRef}>
        <p className="dialog-text" id={textId}>
          {text}
        </p>
        {children}
        <div className="dialog-actions">
          <button type="button" className="ctrl" ref={initialFocusRef} disabled={busy} onClick={onCancel}>
            {cancel}
          </button>
          <button type="button" className="btn-primary" disabled={busy} onClick={onConfirm}>
            {confirm}
          </button>
        </div>
      </div>
    </div>, document.body
  )
}
