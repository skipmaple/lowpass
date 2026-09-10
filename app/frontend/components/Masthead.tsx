import { Link } from '@inertiajs/react'
import type * as React from 'react'

// 报头黑带：80px 墨底，LOWPASS 用品牌字 40px 纸色，导航文楷 15，右侧搜索图标与头像位。
// 尺寸（高度、边距、品牌字号、间距）在 tokens.css 的 .masthead* 里，手机版由那里的 @media 收窄。
// 图标是墨线内联 SVG（在黑带上用纸色描边），不引图标库、不用 emoji。
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

export default function Masthead({
  active,
  dailyHref = '/',
  weeklyHref = '/weekly',
  searchHref = '/search',
  accountHref = '/account',
}: MastheadProps) {
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
        <Link href={searchHref} aria-label="搜索" style={{ display: 'inline-flex' }}>
          <StrokeIcon size={20}>
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.3-4.3" />
          </StrokeIcon>
        </Link>
        <Link
          href={accountHref}
          aria-label="账户"
          style={{
            width: 32,
            height: 32,
            flex: 'none',
            borderRadius: '50%',
            border: '1px solid var(--paper)',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <StrokeIcon size={15}>
            <path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" />
            <circle cx="12" cy="7" r="4" />
          </StrokeIcon>
        </Link>
      </div>
    </header>
  )
}
