// 四幅原创墨线插图（讨论气泡、分支与星、焊接、低通日出），45° 排线做阴影。
// 几何逐点搬自 docs/design/src/pages_press.py 的 ill_bubbles / ill_branches / ill_solder / ill_sunrise
// 与 hatch()；那里是这些图形的定稿。
//
// 反白的索引条上，原本纸色的填充要改填墨色才继续读作「挖空」——画布里是
// `ill().replace(PAPER, INK)`，这里由 hole 这个参数承担。

import type * as React from 'react'

import type { Adapter } from '@/types/lowpass'

// 45° 排线：把一块矩形按 step 切成一组斜线，只画落在矩形里的那一段。
function hatch(x: number, y: number, w: number, h: number, step: number): React.ReactElement[] {
  const lines: React.ReactElement[] = []
  for (let d = -h; d < w; d += step) {
    const t1 = Math.max(d, 0)
    const t2 = Math.min(d + h, w)
    if (t2 <= t1) continue
    lines.push(
      <line
        key={d}
        x1={x + t1}
        y1={y + (t1 - d)}
        x2={x + t2}
        y2={y + (t2 - d)}
        strokeWidth={0.9}
      />,
    )
  }
  return lines
}

export type SourceMarkProps = {
  // 挖空处的填充：常态是纸色，反白成墨块时也填墨色
  hole: string
  className?: string
}

function Bubbles({ hole, className }: SourceMarkProps) {
  return (
    <svg viewBox="0 0 120 78" className={className} fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <rect x="10" y="10" width="62" height="34" rx="8" fill={hole} />
      <path d="M22 44 l-4 10 l12 -10" />
      <rect x="48" y="30" width="62" height="34" rx="8" fill={hole} />
      {hatch(54, 35, 50, 24, 6)}
      <path d="M96 64 l4 10 l-12 -10" />
      <polygon points="24,22 30,32 18,32" fill="var(--ink)" />
      <line x1="36" y1="27" x2="62" y2="27" />
    </svg>
  )
}

function Branches({ hole, className }: SourceMarkProps) {
  return (
    <svg viewBox="0 0 120 78" className={className} fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <line x1="30" y1="72" x2="30" y2="14" />
      <path d="M30 46 C 40 30 56 30 70 30" />
      <path d="M70 30 C 84 30 92 22 100 16" />
      <circle cx="30" cy="66" r="4" fill={hole} />
      <circle cx="30" cy="46" r="4" fill={hole} />
      <circle cx="30" cy="24" r="4" fill={hole} />
      <circle cx="70" cy="30" r="4" fill={hole} />
      <polygon points="100,6 103,13 110,13 104,17 106,24 100,20 94,24 96,17 90,13 97,13" fill="var(--green)" strokeWidth={1.2} />
    </svg>
  )
}

function Solder({ hole, className }: SourceMarkProps) {
  return (
    <svg viewBox="0 0 120 78" className={className} fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <path d="M14 68 L 52 40" strokeWidth={6} />
      <path d="M52 40 L 82 20" strokeWidth={1.8} />
      <path d="M84 20 c 3 -4 -2 -6 2 -10 s 5 -2 3 -5" />
      <rect x="58" y="48" width="34" height="22" fill={hole} />
      {hatch(60, 50, 30, 18, 5)}
      {[64, 72, 80, 88].map((x) => (
        <line key={`pin-${x}`} x1={x} y1="70" x2={x} y2="76" strokeWidth={1.2} />
      ))}
      {[64, 72, 80, 88].map((x) => (
        <line key={`leg-${x}`} x1={x} y1="48" x2={x} y2="42" strokeWidth={1.2} />
      ))}
    </svg>
  )
}

// 翻开的书：周刊的来源图形（阮一峰周刊与以后的周刊源都用它）。左页几行字，右页一块排线像版面上的图，下面是书口。
// 与其余三幅同一套笔法：2px 墨线、圆头、45° 排线；反白时挖空处填墨（hole）。
export function OpenBook({ hole, className }: SourceMarkProps) {
  return (
    <svg viewBox="0 0 120 78" className={className} fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <path d="M60 18 C 48 12 30 10 14 13 L 14 64 C 30 61 48 63 60 70 Z" fill={hole} />
      <path d="M60 18 C 72 12 90 10 106 13 L 106 64 C 90 61 72 63 60 70 Z" fill={hole} />
      <line x1="60" y1="18" x2="60" y2="70" />
      <path d="M22 24 C 32 22 42 23 52 26" strokeWidth={1.4} />
      <path d="M22 32 C 32 30 42 31 52 34" strokeWidth={1.4} />
      <path d="M22 40 C 32 38 42 39 52 42" strokeWidth={1.4} />
      <path d="M22 48 C 30 46.5 36 47 42 48.5" strokeWidth={1.4} />
      <rect x="68" y="24" width="30" height="26" fill={hole} strokeWidth={1.4} />
      {hatch(70, 26, 26, 22, 5)}
      <path d="M14 64 C 30 61 48 63 60 70 C 72 63 90 61 106 64 L 106 68 C 90 65 72 67 60 74 C 48 67 30 65 14 68 Z" strokeWidth={1.4} />
    </svg>
  )
}

const RAY_ANGLES = [0.35, 0.7, 1.05, 1.4, 1.75, 2.1, 2.45, 2.8]

// 低通日出：失败态那张小图（画布 130×69，viewBox 260×138）
export function Sunrise({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 260 138" className={className} fill="none" stroke="var(--ink)" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <path d="M96 84 a34 34 0 0 1 68 0 z" fill="var(--green)" />
      <path d="M96 84 a34 34 0 0 1 68 0" />
      {RAY_ANGLES.map((a) => (
        <line
          key={a}
          x1={round(130 + 44 * Math.cos(a))}
          y1={round(84 - 44 * Math.sin(a))}
          x2={round(130 + 56 * Math.cos(a))}
          y2={round(84 - 56 * Math.sin(a))}
        />
      ))}
      <line x1="14" y1="84" x2="246" y2="84" strokeWidth={2} />
      <path d="M14 118 C 50 100 84 104 118 112 S 190 122 246 108" />
      <path d="M14 126 C 70 112 120 118 160 124 S 220 130 246 122" strokeWidth={1} />
      <path d="M14 42 l6 -12 l6 16 l6 -20 l6 18 l6 -14 l6 16 l6 -12 l6 10 l6 -14 l6 12 l6 -12 l6 10 l4 -6" strokeWidth={1.4} />
      <rect x="90" y="24" width="30" height="32" fill="var(--paper)" />
      {hatch(92, 26, 26, 28, 4)}
      <path d="M120 40 c 14 -18 28 -18 42 0 s 28 18 42 0 s 28 -18 42 0" strokeWidth={1.6} />
    </svg>
  )
}

// 缺页：一张对折的报纸，右页正中被裁去一块（虚线是裁口），缺口里是 45° 排线的阴影。404 与 403 用（viewBox 同日出，260×138）。
export function MissingPage({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 260 138" className={className} fill="none" stroke="var(--ink)" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <path d="M30 20 L 128 14 L 128 124 L 30 118 Z" fill="var(--paper)" />
      <path d="M132 14 L 230 20 L 230 118 L 132 124 Z" fill="var(--paper)" />
      <line x1="130" y1="12" x2="130" y2="126" strokeWidth={1} />
      <line x1="40" y1="30" x2="118" y2="26" strokeWidth={4} />
      {[44, 54, 64, 74, 84, 94, 104].map((y, index) => (
        <line key={y} x1="40" y1={y - index * 0.4} x2={index % 3 === 2 ? 96 : 118} y2={y - index * 0.4 - 3} strokeWidth={1} />
      ))}
      <line x1="146" y1="28" x2="218" y2="31" strokeWidth={1} />
      <rect x="150" y="40" width="62" height="48" fill="var(--paper)" strokeDasharray="4 3" />
      {hatch(152, 42, 58, 44, 4)}
      <line x1="146" y1="100" x2="218" y2="103" strokeWidth={1} />
      <line x1="146" y1="110" x2="200" y2="112.5" strokeWidth={1} />
    </svg>
  )
}

function round(value: number): number {
  return Math.round(value * 10) / 10
}

// 适配器决定用哪一幅。ruanyf_weekly 是周刊源，不会出现在日刊的索引条上；周刊源用「翻开的书」（2026-10-14）。
const MARKS: Record<Adapter, (props: SourceMarkProps) => React.ReactElement> = {
  hacker_news: Bubbles,
  github_trending: Branches,
  rss: Solder,
  ruanyf_weekly: OpenBook,
}

export function SourceMark({ adapter, hole, className }: SourceMarkProps & { adapter: Adapter }) {
  const Mark = MARKS[adapter]
  return <Mark hole={hole} className={className} />
}
