import { Link } from '@inertiajs/react'

import Icon, { type IconName } from '@/components/Icon'
import { pageTurn, type TurnDirection } from '@/lib/pageTurn'

// 40px 描边按钮（画布 pages_front2.py 的 ctrl()）：期导航、翻月、翻年都用它。
// 没有目标（最新一期的「后一期」、最早一个月的「前一月」）时退成 35% 墨线的不可点态。
// 尺寸在 tokens.css 的 .ctrl 里而不是行内样式：行内样式盖不住手机断点的 @media。

export type CtrlProps = {
  href: string | null
  label: string
  icon?: IconName
  side?: 'left' | 'right'
  // 前一期 / 后一期：带方向的翻页（设计 skill「动效」M2），并告诉读屏 ← / → 也能翻（M8）
  turn?: TurnDirection
}

const KEYS: Record<TurnDirection, string> = { back: 'ArrowLeft', forward: 'ArrowRight' }

export function Ctrl({ href, label, icon, side, turn }: CtrlProps) {
  const off = href === null
  const body = (
    <>
      {icon && side === 'left' ? <Icon name={icon} color="currentColor" /> : null}
      <span>{label}</span>
      {icon && side === 'right' ? <Icon name={icon} color="currentColor" /> : null}
    </>
  )

  if (off) {
    return (
      <span className="ctrl ctrl-off" role="link" aria-disabled="true">
        {body}
      </span>
    )
  }
  return (
    <Link className="ctrl" href={href} viewTransition={turn ? pageTurn(turn) : undefined} aria-keyshortcuts={turn ? KEYS[turn] : undefined}>
      {body}
    </Link>
  )
}

// 手机版的方形图标按钮：44px 触控目标（PRD 6.4），名字交给 aria-label
export function Square({ href, label, icon, turn }: { href: string | null; label: string; icon: IconName; turn?: TurnDirection }) {
  if (href === null) {
    return (
      <span className="ctrl ctrl-off ctrl-square" role="link" aria-disabled="true" aria-label={label}>
        <Icon name={icon} size={18} color="currentColor" />
      </span>
    )
  }
  return (
    <Link className="ctrl ctrl-square" href={href} aria-label={label} viewTransition={turn ? pageTurn(turn) : undefined} aria-keyshortcuts={turn ? KEYS[turn] : undefined}>
      <Icon name={icon} size={18} color="currentColor" />
    </Link>
  )
}
