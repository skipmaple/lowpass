import type * as React from 'react'
import { Fragment, useState } from 'react'

import Chip from '@/components/Chip'
import Icon, { type IconName } from '@/components/Icon'
import { absoluteStamp, compactCount, relativeAge } from '@/lib/typeset'
import type { Adapter, Item } from '@/types/lowpass'

// 十条格式一致的条目（PRD 5.1「条目结构」，不放大首条）：序号、标题、说明、元数据、
// 兴趣标签、推荐理由。元数据行只有数字与记号，不出现中文单位（设计 skill）。
// 周刊那一版（variant="weekly"）只有序号、标题、摘要与发布时间（D19）。
// 标签跟随标题，始终属于同一阅读组，不再放到页面远端。
// 画布：docs/design/src/pages_front3.py 的 item() 与 item_m()。

const data = { fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' } as const

function Metric({ icon, label, children }: { icon: IconName; label: string; children: React.ReactNode }) {
  return (
    <span className="item-metric">
      <Icon name={icon} title={label} color="currentColor" />
      <span>{children}</span>
    </span>
  )
}

function Age({ published }: { published: string }) {
  const age = relativeAge(published)
  if (age === '') return null
  return (
    <time className="item-metric" dateTime={published} title={absoluteStamp(published)}>
      <Icon name="clock" title="发布时间" color="currentColor" />
      <span>{age}</span>
    </time>
  )
}

function Comments({ count, url }: { count: number; url?: string }) {
  const [hovered, setHovered] = useState(false)
  const [focused, setFocused] = useState(false)

  if (!url) return <Metric icon="message-square" label="评论">{count}</Metric>

  // 动效反馈对应真实的讨论链接；得分和时间是信息，不伪装成可操作按钮。
  return (
    <a
      className="item-metric item-comments"
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`${count} 条评论，在 Hacker News 打开`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
    >
      <Icon name={hovered || focused ? 'messages-square' : 'message-square'} color="currentColor" />
      <span>{count}</span>
    </a>
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

function Meta({ item, adapter, rank, variant }: { item: Item; adapter: Adapter; rank: number; variant: ItemVariant }) {
  const parts: React.ReactNode[] = []

  // 周刊条目只有一个元数据：这条内容的发布时间（画布 pages_site.py 的 rss_section）。
  // 阮一峰那一节整期同一天发布，逐条重复没有信息量，所以 published_at 为空就整行不渲染。
  if (variant === 'weekly') {
    if (!item.published_at) return null
    return <span style={data}>{absoluteStamp(item.published_at)}</span>
  }

  if (adapter === 'hacker_news') {
    if (item.meta.score !== undefined) parts.push(<Metric icon="arrow-up" label="得分">{item.meta.score}</Metric>)
    if (item.meta.comments !== undefined) {
      parts.push(<Comments count={item.meta.comments} url={item.meta.comments_url} />)
    }
  } else if (adapter === 'github_trending') {
    if (item.meta.language) parts.push(<span style={data}>{item.meta.language}</span>)
    if (item.meta.stars !== undefined) parts.push(<Metric icon="star" label="Star">{compactCount(item.meta.stars)}</Metric>)
    if (item.meta.stars_today !== undefined) parts.push(<StarsToday value={item.meta.stars_today} highlight={rank <= 3} />)
  } else if (item.author) {
    // RSS 源：作者与 GitHub 的语言名一样属于元数据，整行只有一个字体角色（Maple）
    parts.push(<span style={data}>{item.author}</span>)
  }

  if (item.published_at && relativeAge(item.published_at) !== '') parts.push(<Age published={item.published_at} />)

  return (
    <span className="item-meta">
      {parts.map((part, index) => <Fragment key={index}>{part}</Fragment>)}
    </span>
  )
}

// D19：周刊条目不生成推荐理由，也就没有兴趣标签；元数据只剩发布时间。
// heading 是标题的层级（PRD 6.4「标题层级语义正确」）：日刊页 h1 是日期，条目就是 h2；
// 周刊页 h1 是周次、h2 是源名、h3 是板块，所以条目按所在位置降一到两级。
// id 是搜索结果所在期链接的落点（设计 6.3）。
export type ItemVariant = 'daily' | 'weekly'
export type ItemRowProps = { item: Item; adapter: Adapter; rank: number; variant?: ItemVariant; heading?: 'h2' | 'h3' | 'h4' }

export default function ItemRow({ item, adapter, rank, variant = 'daily', heading: Heading = 'h2' }: ItemRowProps) {
  const weekly = variant === 'weekly'

  return (
    <article className="item-row" id={`item-${item.id}`}>
      <span className="item-rank">{rank}</span>

      <div className="item-body">
        {/* 第二轮阅读评审：完整显示标题和摘要；外链仍在新标签页打开。 */}
        <div className="item-heading">
          <Heading className="item-title">
            <a className="t" href={item.url} target="_blank" rel="noopener noreferrer">
              {item.title}
            </a>
          </Heading>
          {!weekly && item.interest_tag ? (
            <div className="item-tag"><Chip text={item.interest_tag} /></div>
          ) : null}
        </div>
        {/* 周刊摘要行高 1.7（画布 pages_site.item() 的文楷 15/1.7），日刊摘要是 PRD 6.3 的 Newsreader 15/1.5 */}
        {item.summary ? <span className={weekly ? 'item-summary item-summary--weekly' : 'item-summary'}>{item.summary}</span> : null}
        <Meta item={item} adapter={adapter} rank={rank} variant={variant} />
        {!weekly && item.reason ? <div className="item-reason">{item.reason}</div> : null}
      </div>
    </article>
  )
}
