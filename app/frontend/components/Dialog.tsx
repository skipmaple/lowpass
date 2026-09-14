import { useEffect, useRef } from 'react'

// 确认对话框（画布 dialog()）：整页 40% 墨色遮罩，480px 纸卡，1px 墨线加 2px 顶线，文楷 20 的问句，
// 右下「取消」描边 + 确认反白。Escape 取消；打开时焦点进确认按钮，关掉后回到打开前的元素。
export type DialogProps = {
  open: boolean
  text: string
  cancel: string
  confirm: string
  busy?: boolean
  onCancel: () => void
  onConfirm: () => void
}

export default function Dialog({ open, text, cancel, confirm, busy = false, onCancel, onConfirm }: DialogProps) {
  const confirmRef = useRef<HTMLButtonElement>(null)
  // 取最新的 onCancel：只有 open 变化才需要重挂载监听与焦点。父组件重渲染（比如 usePolling 每
  // 5 秒 reload）常会传一个新的内联 onCancel 引用——若把它放进依赖数组，副作用会跟着重跑，
  // 焦点被收回去再塞回来，用户能看见确认按钮"闪"一下。
  const cancelRef = useRef(onCancel)
  cancelRef.current = onCancel

  useEffect(() => {
    if (!open) return
    const previous = document.activeElement as HTMLElement | null
    confirmRef.current?.focus()
    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape') cancelRef.current()
    }
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('keydown', onKey)
      previous?.focus()
    }
  }, [open])

  if (!open) return null

  return (
    <div className="dialog-shade">
      <div className="dialog" role="dialog" aria-modal="true" aria-label={text}>
        <p className="dialog-text">{text}</p>
        <div className="dialog-actions">
          <button type="button" className="ctrl" onClick={onCancel}>
            {cancel}
          </button>
          <button type="button" className="btn-primary" ref={confirmRef} disabled={busy} onClick={onConfirm}>
            {confirm}
          </button>
        </div>
      </div>
    </div>
  )
}
