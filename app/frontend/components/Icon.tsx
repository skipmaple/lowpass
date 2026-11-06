import { Archive, ArrowUp, ArrowUpRight, Bookmark, Check, ChevronDown, ChevronLeft, ChevronRight, Clock, LogOut, MessageSquare, MessagesSquare, Plus, RefreshCw, Search, Star, Sun, TriangleAlert, User, X } from 'lucide'
import { createElement } from 'react'

// Lucide geometry stays on a consistent 24px grid with a 1.75 stroke.
// Controls provide feedback through color/fill; icons do not need a spring runtime.
const ICONS = {
  'chevron-down': ChevronDown,
  sun: Sun,
  'chevron-left': ChevronLeft,
  'chevron-right': ChevronRight,
  'arrow-up-right': ArrowUpRight,
  'arrow-up': ArrowUp,
  archive: Archive,
  bookmark: Bookmark,
  clock: Clock,
  'message-square': MessageSquare,
  'messages-square': MessagesSquare,
  star: Star,
  search: Search,
  'log-out': LogOut,
  'triangle-alert': TriangleAlert,
  user: User,
  x: X,
  check: Check,
  plus: Plus,
  'refresh-cw': RefreshCw,
} as const

export type IconName = keyof typeof ICONS

// 图标跟随所在控件的状态颜色；独自表意时传 title，装饰图标对读屏隐藏。
export default function Icon({
  name,
  size = 14,
  color = 'currentColor',
  title,
}: {
  name: IconName
  size?: number
  color?: string
  title?: string
}) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke={color} strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" role={title ? 'img' : undefined} aria-label={title} aria-hidden={title ? undefined : true} focusable="false" style={{ flex: 'none', display: 'block' }}>
      {ICONS[name].map(([tag, attributes], index) => createElement(tag, { ...attributes, key: index }))}
    </svg>
  )
}
