import { Link } from '@inertiajs/react'
import type * as React from 'react'

import { DAILY_LATEST, WEEKLY_ARCHIVE } from '@/lib/paths'

// 报头黑带：80px 墨底，LOWPASS 用品牌字 40px 纸色，导航文楷 15，右侧搜索图标与头像位。
// 尺寸（高度、边距、品牌字号、间距）在 tokens.css 的 .masthead* 里，手机版由那里的 @media 收窄。
// 图标是墨线内联 SVG（在黑带上用纸色描边），不引图标库、不用 emoji。
//
// 搜索（F-13）与账户（F-1）是 P1/P2 的页面，P0 没有这两条路由：不传 href 时右侧两个位置
// 渲染成同样外观的非交互占位，不给读者一个点开就 404 的图标；P1/P2 把 href 传进来就还是链接。
export type MastheadProps = {
  active?: 'daily' | 'weekly'
  dailyHref?: string
  weeklyHref?: string
  searchHref?: string
  accountHref?: string
}

function Nav({ href, label, current }: { href: string; label: string; current: boolean }) {
  return (
    <Link
      href={href}
      aria-current={current ? 'page' : undefined}
      style={{
        fontFamily: 'var(--font-cjk)',
        fontSize: 'var(--fs-15)',
        color: 'var(--paper)',
        lineHeight: 1,
        paddingBottom: 2,
        whiteSpace: 'nowrap',
        opacity: current ? 1 : 0.72,
        borderBottom: current ? '1px solid var(--paper)' : '1px solid transparent',
      }}
    >
      {label}
    </Link>
  )
}

function StrokeIcon({ size, children }: React.PropsWithChildren<{ size: number }>) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      style={{ flex: 'none', display: 'block', stroke: 'var(--paper)' }}
    >
      {children}
    </svg>
  )
}

// 有 href 就是链接，没有就是占位：占位不进 tab 序、对读屏器不出声（图标本来就 aria-hidden），
// 因为这里没有任何可以做的事。外观两边一模一样。
function Action({ href, label, style, children }: React.PropsWithChildren<{ href?: string; label: string; style: React.CSSProperties }>) {
  if (href) {
    return (
      <Link href={href} aria-label={label} style={style}>
        {children}
      </Link>
    )
  }

  return (
    <span aria-disabled="true" style={style}>
      {children}
    </span>
  )
}

const SEARCH_STYLE: React.CSSProperties = { display: 'inline-flex' }
const ACCOUNT_STYLE: React.CSSProperties = {
  width: 32,
  height: 32,
  flex: 'none',
  borderRadius: '50%',
  border: '1px solid var(--paper)',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
}

export default function Masthead({ active, dailyHref = DAILY_LATEST, weeklyHref = WEEKLY_ARCHIVE, searchHref, accountHref }: MastheadProps) {
  return (
    <header className="masthead">
      <div className="masthead-left">
        <Link href={dailyHref} className="masthead-brand">
          lowpass
        </Link>
        <nav className="masthead-nav">
          <Nav href={dailyHref} label="日刊" current={active === 'daily'} />
          <Nav href={weeklyHref} label="周刊" current={active === 'weekly'} />
        </nav>
      </div>

      <div className="masthead-actions">
        <Action href={searchHref} label="搜索" style={SEARCH_STYLE}>
          <StrokeIcon size={20}>
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.3-4.3" />
          </StrokeIcon>
        </Action>
        <Action href={accountHref} label="账户" style={ACCOUNT_STYLE}>
          <StrokeIcon size={15}>
            <path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" />
            <circle cx="12" cy="7" r="4" />
          </StrokeIcon>
        </Action>
      </div>
    </header>
  )
}
