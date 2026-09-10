import Icon from '@/components/Icon'
import type { ArchiveMark } from '@/types/lowpass'

// 归档的状态记号（画布 pages_site.py 的 mark()）：10px 实心方块 = 已发布，
// 描边方块 = 空刊 / 无内容，叉 = 缺期，时钟 = 生成中。名字给读屏，别的地方不重复说。
const NAMES: Record<ArchiveMark, string> = {
  published: '已发布',
  empty: '空刊',
  generating: '生成中',
  missing: '缺期',
}

export default function Mark({ state }: { state: ArchiveMark }) {
  const label = NAMES[state]

  if (state === 'missing') return <Icon name="x" size={12} color="var(--ink2)" title={label} />
  if (state === 'generating') return <Icon name="clock" size={12} color="var(--ink2)" title={label} />

  return (
    <span
      role="img"
      aria-label={label}
      style={{
        display: 'inline-block',
        width: 10,
        height: 10,
        boxSizing: 'border-box',
        background: state === 'published' ? 'var(--ink)' : 'transparent',
        border: state === 'published' ? undefined : '1px solid var(--ink)',
      }}
    />
  )
}
