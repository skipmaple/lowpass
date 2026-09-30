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
  if (!favorites) return null

  const on = favorites.has(urlHash)

  return (
    <button
      ref={ref}
      type="button"
      className={className ? `favorite-button ${className}` : 'favorite-button'}
      data-on={on ? '' : undefined}
      aria-label={`${on ? '取消收藏' : '收藏'}：${title}`}
      onClick={() => favorites.toggle({ urlHash, itemId })}
    >
      <Icon name="bookmark" size={18} color="currentColor" />
    </button>
  )
}
