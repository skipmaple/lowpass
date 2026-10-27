import type * as React from 'react'
import { Fragment, useEffect, useState } from 'react'

import Chip from '@/components/Chip'
import FavoriteButton from '@/components/FavoriteButton'
import Icon, { type IconName } from '@/components/Icon'
import WeeklyContent from '@/components/WeeklyContent'
import { Mixed, absoluteStamp, compactCount, latinLang, relativeAge } from '@/lib/typeset'
import type { Adapter, Item } from '@/types/lowpass'

// 十条格式一致的条目（PRD 5.1「条目结构」，不放大首条）：序号、标题、标题译文（HN、Hackaday，D25）、说明、
// 说明译文（GitHub Trending，D25）、元数据、兴趣标签、推荐理由。元数据行只有数字与记号，不出现中文单位（设计 skill）。
// 周刊那一版（variant="weekly"）只有序号、标题、摘要与发布时间（D19）。
// 兴趣标签紧跟标题最后一个词（所有宽度，2026-10-14 O1）：标题元素行内排，标签是它后面的行内小签，放不下就整个换到下一行行首。
// 书签（PRD 5.10）在条目行末另占一格，手机上与序号同一行、靠右；DOM 里排在正文后面，Tab 先到标题再到书签。
// 画布：docs/design/src/pages_front3.py 的 item() 与 item_m()。

const data = { fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' } as const

const clockListeners = new Set<(now: number) => void>()
let clockTimer: ReturnType<typeof setInterval> | undefined

function refreshClock() {
  if (document.visibilityState === 'visible') {
    const now = Date.now()
    clockListeners.forEach((listener) => listener(now))
  }
}

function subscribeClock(listener: (now: number) => void) {
  clockListeners.add(listener)
  if (clockListeners.size === 1) {
    clockTimer = setInterval(refreshClock, 60_000)
    document.addEventListener('visibilitychange', refreshClock)
    window.addEventListener('pageshow', refreshClock)
  }
  listener(Date.now())
  return () => {
    clockListeners.delete(listener)
    if (clockListeners.size === 0) {
      clearInterval(clockTimer)
      clockTimer = undefined
      document.removeEventListener('visibilitychange', refreshClock)
      window.removeEventListener('pageshow', refreshClock)
    }
  }
}

function Metric({ icon, label, children }: { icon: IconName; label: string; children: React.ReactNode }) {
  return (
    <span className="item-metric">
      <Icon name={icon} title={label} color="currentColor" />
      <span>{children}</span>
    </span>
  )
}

function Age({ published }: { published: string }) {
  const [now, setNow] = useState(Date.now)
  useEffect(() => subscribeClock(setNow), [])
  const age = relativeAge(published, now)
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

// 打印时标题后印链接的域名（print.css 读 data-host）；地址解析不了就不印
function hostOf(url: string): string | undefined {
  try {
    return new URL(url).host.replace(/^www\./, '')
  } catch {
    return undefined
  }
}

// D25 译文紧跟它译的那段原文：HN 与 Hackaday 在标题下，GitHub Trending 在简介下。不是链接（卡片只有标题可点）。
// 中文走文楷，夹在里面的产品名、项目名走 Newsreader，跟原文同一字体（设计 skill「译文排进 Newsreader」那条偏差的改法）；
// 字号与颜色交给 CSS 按断点走。收藏页的行也用它。
export function Translation({ text }: { text: string }) {
  return (
    <p className="item-translation">
      <Mixed text={text} font="latin" size="inherit" color="inherit" weight={400} />
    </p>
  )
}

// D19：周刊条目不生成推荐理由，也就没有兴趣标签；元数据只剩发布时间。
// heading 是标题的层级（PRD 6.4「标题层级语义正确」）：日刊页 h1 是日期，条目就是 h2；
// 周刊页 h1 是周次、h2 是源名、h3 是板块，所以条目按所在位置降一到两级。
// id 是搜索结果所在期链接的落点（设计 6.3）。
export type ItemVariant = 'daily' | 'weekly'
export type ItemRowProps = { item: Item; adapter: Adapter; rank: number; variant?: ItemVariant; heading?: 'h2' | 'h3' | 'h4' }

// 标签也参与父盒的 balance；保留英文末两词的断行关系，避免标签把标题末词独留一行。
// slice 原文而不重新拼词，空白与可读名称不变；超长片段仍可在自己的宽度上限内折行。
function TitleText({ text, tagged }: { text: string; tagged: boolean }) {
  const tail = tagged && latinLang(text) === 'en' ? text.match(/\S+\s+\S+\s*$/u) : null
  if (!tail || tail.index === undefined) return text

  return <>{text.slice(0, tail.index)}<span className="item-title-tail">{tail[0]}</span></>
}

export default function ItemRow({ item, adapter, rank, variant = 'daily', heading: Heading = 'h2' }: ItemRowProps) {
  const weekly = variant === 'weekly'
  const tagged = !weekly && Boolean(item.interest_tag)
  const copy = item.summary

  return (
    <article className={`item-row${weekly ? ' item-row--weekly' : ''}`} id={`item-${item.id}`} tabIndex={weekly ? -1 : undefined}>
      <span className="item-rank">{rank}</span>

      <div className="item-body">
        {/* 第二轮阅读评审：完整显示标题和摘要；外链仍在新标签页打开。标签在标题元素外面：不进标题的可读名称 */}
        <div className="item-heading">
          <Heading className="item-title">
            <a className="t" href={item.url} target="_blank" rel="noopener noreferrer" lang={latinLang(item.title)} data-host={hostOf(item.url)}>
              <TitleText text={item.title} tagged={tagged} />
            </a>
          </Heading>
          {tagged ? (
            <span className="item-tag"><Chip text={item.interest_tag!} variant="outline" className="item-interest-chip" /></span>
          ) : null}
        </div>
        {!weekly && item.title_zh ? <Translation text={item.title_zh} /> : null}
        {/* 周刊正文完整展开、按原文分段（SummaryCleaner.content 一行一段），并按中西文分配字体；日刊摘要完整显示。 */}
        {weekly ? <WeeklyContent item={item} /> : copy ? <span className="item-summary" lang={latinLang(copy)}>{copy}</span> : null}
        {!weekly && item.summary_zh ? <Translation text={item.summary_zh} /> : null}
        <Meta item={item} adapter={adapter} rank={rank} variant={variant} />
        {!weekly && item.reason ? (
          <div className="item-reason">
            <Mixed text={item.reason} font="latin" size="inherit" color="inherit" weight={400} lineHeight="inherit" />
          </div>
        ) : null}
      </div>

      <FavoriteButton className="item-mark" itemId={item.id} urlHash={item.url_hash} title={item.title} />
    </article>
  )
}
