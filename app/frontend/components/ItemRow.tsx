import Icon from '@/components/Icon'
import type * as React from 'react'

import { Mixed, absoluteStamp, compactCount, relativeAge } from '@/lib/typeset'
import type { Adapter, Item } from '@/types/lowpass'

// 十条格式一致的条目（PRD 5.1「条目结构」，不放大首条）：序号、标题、说明、元数据、
// 兴趣标签、推荐理由。元数据行只有数字与记号，不出现中文单位（设计 skill）。
// 桌面标签在右列，手机标签与序号组成眉行——同一份 DOM，靠 tokens.css 里的 grid-template-areas 换位。
// 画布：docs/design/src/pages_front3.py 的 item() 与 item_m()。

const DOT = <span style={{ fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' }}>·</span>

const data = { fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' } as const

function Age({ published }: { published: string }) {
  return (
    <span style={data} title={absoluteStamp(published)}>
      {relativeAge(published)}
    </span>
  )
}

// 今日新增：前三名反白成鼠尾草绿小徽章（唯一的彩色角色之一），其余同色等宽
function StarsToday({ value, highlight }: { value: number; highlight: boolean }) {
  const text = `+${value}`
  if (highlight) {
    return (
      <span style={{ fontFamily: 'var(--font-data)', fontSize: 'var(--fs-12)', background: 'var(--green)', color: 'var(--ink)', padding: '2px 7px', whiteSpace: 'nowrap' }}>
        {text}
      </span>
    )
  }
  return <span style={data}>{text}</span>
}

function Meta({ item, adapter, rank }: { item: Item; adapter: Adapter; rank: number }) {
  const parts: React.ReactNode[] = []

  if (adapter === 'hacker_news') {
    if (item.meta.score !== undefined) parts.push(<span style={data}>▲ {item.meta.score}</span>)
    if (item.meta.comments !== undefined) {
      const count = (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
          <Icon name="message-square" size={12} color="var(--ink2)" />
          <span style={data}>{item.meta.comments}</span>
        </span>
      )
      // PRD 5.1：评论数链接到 HN 讨论页（R-8.4 新标签页打开）；样式不变，只多一条下划线
      parts.push(
        item.meta.comments_url ? (
          <a className="t" href={item.meta.comments_url} target="_blank" rel="noopener noreferrer">
            {count}
          </a>
        ) : (
          count
        ),
      )
    }
  } else if (adapter === 'github_trending') {
    if (item.meta.language) parts.push(<span style={data}>{item.meta.language}</span>)
    if (item.meta.stars !== undefined) parts.push(<span style={data}>★ {compactCount(item.meta.stars)}</span>)
    if (item.meta.stars_today !== undefined) parts.push(<StarsToday value={item.meta.stars_today} highlight={rank <= 3} />)
  } else if (item.author) {
    // RSS 源：作者与 GitHub 的语言名一样属于元数据，整行只有一个字体角色（Maple）
    parts.push(<span style={data}>{item.author}</span>)
  }

  if (item.published_at) parts.push(<Age published={item.published_at} />)

  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
      {parts.map((part, index) => (
        <span key={index} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          {index > 0 ? DOT : null}
          {part}
        </span>
      ))}
    </span>
  )
}

// 兴趣标签：墨色反白小块，22px 高，纸色文字（PRD 6.3、D16）。
// 文字走 Mixed：中文用文楷，拉丁标签（AI / LLM）落到 Maple——画布 chip() 就是 mixed(text, PAPER, 12)。
function Chip({ text }: { text: string }) {
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

export type ItemRowProps = { item: Item; adapter: Adapter; rank: number }

export default function ItemRow({ item, adapter, rank }: ItemRowProps) {
  return (
    <article className="item-row">
      <span className="item-rank">{rank}</span>

      <div className="item-body">
        {/* 标题是二级标题（PRD 6.4 标题层级语义正确），字号字重不变；
            两行截断（PRD 6.3）落在 h2 上，下划线仍在里面的 a 上，前两行照常显示。
            R-8.4 原文外链在新标签页打开。 */}
        <h2 className="item-title">
          <a className="t" href={item.url} target="_blank" rel="noopener noreferrer">
            {item.title}
          </a>
        </h2>
        {item.summary ? <span className="item-summary">{item.summary}</span> : null}
        <Meta item={item} adapter={adapter} rank={rank} />
        {item.reason ? (
          <div className="item-reason">{item.reason}</div>
        ) : null}
      </div>

      {item.interest_tag ? (
        <div className="item-tag">
          <Chip text={item.interest_tag} />
        </div>
      ) : null}
    </article>
  )
}
