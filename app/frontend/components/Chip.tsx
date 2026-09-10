import { Mixed } from '@/lib/typeset'

// 反白小签：墨色小块，22px 高，纸色文字。条目的兴趣标签（PRD 6.3、D16）与搜索结果的刊物签都是它。
// 文字走 Mixed：中文用文楷，拉丁标签（AI / LLM）落到 Maple——画布 chip() 就是 mixed(text, PAPER, 12)。
export default function Chip({ text }: { text: string }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        height: 22,
        padding: '0 8px',
        background: 'var(--ink)',
        letterSpacing: '0.06em',
      }}
    >
      <Mixed text={text} size="var(--fs-12)" color="var(--paper)" nowrap />
    </span>
  )
}
