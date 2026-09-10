import { Link } from '@inertiajs/react'
import type * as React from 'react'

// 页脚：2px 墨线顶线、LP 邮戳、「明早 06:00 · 下一期」、最新周刊链接、前后期 40px 描边按钮。
// 中文走文楷，时间走 Maple；按钮没有圆角、没有阴影。
export type FooterProps = {
  nextAt?: string
  latestWeeklyHref?: string
  prevHref?: string | null
  nextHref?: string | null
}

const cjk: React.CSSProperties = { fontFamily: 'var(--font-cjk)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' }
const data: React.CSSProperties = { fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' }

function Chevron({ direction }: { direction: 'left' | 'right' }) {
  return (
    <svg
      width={14}
      height={14}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      style={{ flex: 'none', display: 'block' }}
    >
      <path d={direction === 'left' ? 'm15 18-6-6 6-6' : 'm9 18 6-6-6-6'} />
    </svg>
  )
}

function Ctrl({ href, label, direction }: { href: string | null | undefined; label: string; direction: 'left' | 'right' }) {
  const off = !href
  const style: React.CSSProperties = {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 6,
    height: 40,
    padding: '0 14px',
    border: `1px solid ${off ? 'var(--rule)' : 'var(--ink)'}`,
    fontFamily: 'var(--font-cjk)',
    fontSize: 'var(--fs-15)',
    color: off ? 'var(--ink2)' : 'var(--ink)',
    whiteSpace: 'nowrap',
  }
  const inner = (
    <>
      {direction === 'left' ? <Chevron direction="left" /> : null}
      <span>{label}</span>
      {direction === 'right' ? <Chevron direction="right" /> : null}
    </>
  )

  if (off) {
    return (
      <span style={style} aria-disabled="true">
        {inner}
      </span>
    )
  }
  return (
    <Link href={href} style={style}>
      {inner}
    </Link>
  )
}

function Stamp() {
  return (
    <svg
      viewBox="0 0 64 64"
      width={48}
      height={48}
      fill="none"
      strokeWidth={1.6}
      aria-hidden="true"
      focusable="false"
      style={{ display: 'block', flex: 'none', stroke: 'var(--ink)' }}
    >
      <circle cx="32" cy="32" r="29" />
      <circle cx="32" cy="32" r="23" strokeDasharray="3 3" strokeWidth="1" />
      <text
        x="32"
        y="37"
        textAnchor="middle"
        fontSize="15"
        fontWeight="900"
        stroke="none"
        style={{ fontFamily: 'var(--font-brand)', fill: 'var(--ink)' }}
      >
        LP
      </text>
    </svg>
  )
}

export default function Footer({
  nextAt = '06:00',
  latestWeeklyHref = '/weekly',
  prevHref = null,
  nextHref = null,
}: FooterProps) {
  return (
    <footer
      style={{
        borderTop: '2px solid var(--ink)',
        marginTop: 36,
        padding: '18px 0 8px 0',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 16,
        flexWrap: 'wrap',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
        <Stamp />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          <span style={{ lineHeight: 1.6, whiteSpace: 'nowrap' }}>
            <span style={cjk}>明早 </span>
            <span style={data}>{nextAt}</span>
            <span style={data}> · </span>
            <span style={cjk}>下一期</span>
          </span>
          <Link href={latestWeeklyHref} className="t cjk" style={{ fontSize: 'var(--fs-15)' }}>
            最新周刊
          </Link>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8 }}>
        <Ctrl href={prevHref} label="前一期" direction="left" />
        <Ctrl href={nextHref} label="后一期" direction="right" />
      </div>
    </footer>
  )
}
