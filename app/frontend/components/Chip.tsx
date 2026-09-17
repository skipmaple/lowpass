import { Mixed } from '@/lib/typeset'

// 默认是反白小签；阅读页的兴趣标签使用描边变体，降低与当前来源页签的视觉竞争。
// 文字走 Mixed：中文用文楷，拉丁标签（AI / LLM）落到 Maple。
export default function Chip({ text, variant = 'solid', className }: { text: string; variant?: 'solid' | 'outline'; className?: string }) {
  const outline = variant === 'outline'

  return (
    <span
      className={[outline ? 'chip-outline' : null, className].filter(Boolean).join(' ') || undefined}
      style={outline ? undefined : {
        display: 'inline-flex', alignItems: 'center', height: 22, padding: '0 8px',
        background: 'var(--ink)', letterSpacing: '0.06em',
      }}
    >
      <Mixed text={text} size="var(--fs-12)" color={outline ? 'var(--ink2)' : 'var(--paper)'} nowrap />
    </span>
  )
}
