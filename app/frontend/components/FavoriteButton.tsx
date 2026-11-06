import { useEffect, useImperativeHandle, useRef, useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import { useFavorites } from '@/lib/favorites'

// 条目上的书签（PRD 6.3「收藏按钮」、D30）：点一下收藏，再点取消，不弹确认。两态靠形状分——描线是未收藏，
// 实心是已收藏（tokens.css 的 .favorite-button[data-on]），不靠颜色。可读名称随状态换成「收藏」/「取消收藏」
// 并带条目标题（附录 B）。44px 见方的独立目标，与标题链接分开。页面没有套 FavoritesProvider 时不渲染。
export type FavoriteButtonProps = {
  urlHash: string
  title: string
  // 收藏页的行没有条目 id：那里的书签只会取消，恢复走「恢复」那个按钮
  itemId?: string
  className?: string
  ref?: React.Ref<HTMLButtonElement>
}

export default function FavoriteButton({ urlHash, title, itemId, className, ref }: FavoriteButtonProps) {
  const favorites = useFavorites()
  // 盖章（设计 skill「动效」M3）：读者点「收藏」时带上 data-stamp，压一下的动画在它出现时播一次；
  // 取消与失败回滚（data-on 去掉）只退墨，标记一起去掉，下次收藏才会再压。页面带进来的已收藏不压
  const [stamping, setStamping] = useState(false)
  const [feedback, setFeedback] = useState<{ text: string; undo: boolean; duration: number } | null>(null)
  const buttonRef = useRef<HTMLButtonElement>(null)
  const undoRef = useRef<HTMLButtonElement>(null)
  const actionVersion = useRef(0)
  const expiresAt = useRef(0)
  useImperativeHandle(ref, () => buttonRef.current!, [])
  useEffect(() => {
    const clear = () => {
      actionVersion.current += 1
      setFeedback(null)
    }
    window.addEventListener('lowpass:bookmark-action', clear)
    return () => {
      actionVersion.current += 1
      window.removeEventListener('lowpass:bookmark-action', clear)
    }
  }, [])
  useEffect(() => {
    if (!feedback) return
    expiresAt.current = Date.now() + feedback.duration
    const timer = window.setTimeout(() => {
      // Do not remove a focused undo control from beneath a keyboard user.
      if (document.activeElement !== undoRef.current) setFeedback(null)
    }, feedback.duration)
    return () => window.clearTimeout(timer)
  }, [feedback])
  if (!favorites) return null

  const on = favorites.has(urlHash)
  function change(undo = false) {
    // Only the latest action owns visible confirmation, even when older requests
    // finish late. Other items keep their server-backed bookmark state.
    window.dispatchEvent(new Event('lowpass:bookmark-action'))
    const version = actionVersion.current
    setStamping(!on)
    if (undo) buttonRef.current?.focus()
    favorites!.toggle({ urlHash, itemId, onSuccess: (saved) => {
      if (actionVersion.current !== version) return
      setFeedback({
        text: undo ? `已撤销「${title}」的收藏。` : saved ? `已收藏「${title}」，可在收藏中找回。` : `已取消「${title}」的收藏。`,
        undo: saved,
        duration: undo ? 2000 : 5000,
      })
    } })
  }

  return (
    <span className={`favorite-control ${className ?? ''}`}>
    <button
      ref={buttonRef}
      type="button"
      className={className ? `favorite-button ${className}` : 'favorite-button'}
      data-on={on ? '' : undefined}
      data-stamp={stamping && on ? '' : undefined}
      aria-label={`${on ? '取消收藏' : '收藏'}：${title}`}
      aria-pressed={on}
      onClick={() => change()}
    >
      {/* 描线一层常在；实心那层由 clip-path 从底部涨满（两态靠形状分，D30） */}
      <span className="favorite-line" aria-hidden="true"><Icon name="bookmark" size={18} color="currentColor" /></span>
      <span className="favorite-ink" aria-hidden="true"><Icon name="bookmark" size={18} color="currentColor" /></span>
      <span>{on ? '已收藏' : '收藏'}</span>
    </button>
      <span className="favorite-feedback" role="status">
        {feedback ? <span className="favorite-feedback-content">{feedback.text}{feedback.undo ? <button ref={undoRef} type="button" className="link-button" onClick={() => change(true)} onBlur={() => {
          if (Date.now() >= expiresAt.current) setFeedback(null)
        }}>撤销</button> : null}</span> : null}
      </span>
    </span>
  )
}
