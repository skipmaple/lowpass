import { Mixed } from '@/lib/typeset'

// 只读标签与来源筛选按钮分开，避免静态状态继承可点击外观。
// 形态、文字和表面颜色由主题决定，Mixed 仅负责中英文的字体角色。
export default function Chip({ text, variant = 'solid', className }: { text: string; variant?: 'solid' | 'outline'; className?: string }) {
  return (
    <span
      className={['chip-static', className].filter(Boolean).join(' ')}
      data-variant={variant}
    >
      <Mixed text={text} size="var(--fs-12)" color="currentColor" nowrap />
    </span>
  )
}
