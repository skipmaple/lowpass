import { Archive, ArrowUp, ArrowUpRight, BookOpen, Check, ChevronLeft, ChevronRight, Clock, LogOut, MessageSquare, MessagesSquare, Plus, RefreshCw, Search, Star, TriangleAlert, User, X } from 'lucide'
import { MorphIcon } from 'morphicons/react'

// Lucide 提供图形数据，Morphicons 在同一个 SVG 内衔接状态；只导入实际使用的图标。
// 沿用纸报的墨色、24 网格和 1.75 描边。默认启用变形，遵循系统减少动态偏好，静态图标不循环播放。
const ICONS = {
  'chevron-left': ChevronLeft,
  'chevron-right': ChevronRight,
  'arrow-up-right': ArrowUpRight,
  'arrow-up': ArrowUp,
  archive: Archive,
  'book-open': BookOpen,
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

// 图标独自表意时传 title，由 MorphIcon 输出 role="img" 和可读名称；装饰图标对读屏隐藏。
export default function Icon({
  name,
  size = 14,
  color = 'var(--ink)',
  title,
}: {
  name: IconName
  size?: number
  color?: string
  title?: string
}) {
  return (
    <MorphIcon
      icon={ICONS[name]}
      size={size}
      color={color}
      strokeWidth={1.75}
      spring="snappy"
      reducedMotion="user"
      label={title}
      focusable="false"
      style={{ flex: 'none', display: 'block' }}
    />
  )
}
