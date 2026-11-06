import type * as React from 'react'
import { Fragment, useState } from 'react'

import FavoriteButton from '@/components/FavoriteButton'
import Icon, { type IconName } from '@/components/Icon'
import { Mixed, absoluteStamp, compactCount, latinLang, relativeAge } from '@/lib/typeset'
import { useTheme } from '@/lib/theme'
import type { Adapter, Item } from '@/types/lowpass'

// 三套主题共用一份内容和操作节点；排版改变时不重建收藏或原文的展开状态。
// 中文解释优先，原文保留；周刊始终展示完整正文，不生成日刊的推荐理由。

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

// 今日新增：前三名以主题强调色标注，保留真实的榜单排序。
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
    // RSS 源：作者与 GitHub 的语言名一样属于元数据，整行只有一个字体角色（数据字体）
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

// 收藏等页面保留的混排工具；字体由当前主题令牌指定。
export function Translation({ text }: { text: string }) {
  return (
    <p className="item-translation">
      <Mixed text={text} font="latin" size="inherit" color="inherit" weight={400} />
    </p>
  )
}

function WeeklyMedia({ item }: { item: Item }) {
  const [failed, setFailed] = useState<ReadonlySet<number>>(() => new Set())
  const imageUrls = Array.isArray(item.meta.image_urls)
    ? item.meta.image_urls.filter((url): url is string => typeof url === 'string' && /^https?:\/\//i.test(url))
    : []
  const visible = imageUrls.map((url, index) => ({ url, index })).filter(({ index }) => !failed.has(index))

  if (visible.length === 0) return null

  return (
    <div className={visible.length > 1 ? 'item-media item-media--multiple' : 'item-media item-media--single'}>
      {visible.map(({ url, index }) => (
        <figure className="item-media-frame" key={`${url}-${index}`}>
          <img
            className="item-media-image"
            src={url}
            alt={`${item.title}配图${imageUrls.length > 1 ? ` ${index + 1}` : ''}`}
            loading="lazy"
            decoding="async"
            referrerPolicy="no-referrer"
            onError={() => setFailed((current) => new Set(current).add(index))}
          />
        </figure>
      ))}
    </div>
  )
}

// D19：周刊条目不生成推荐理由，也就没有兴趣标签；元数据只剩发布时间。
// heading 是标题的层级（PRD 6.4「标题层级语义正确」）：日刊页 h1 是日期，条目就是 h2；
// 周刊页 h1 是周次、h2 是源名、h3 是板块，所以条目按所在位置降一到两级。
// id 是搜索结果所在期链接的落点（设计 6.3）。
export type ItemVariant = 'daily' | 'weekly'
export type ItemRowProps = { item: Item; adapter: Adapter; rank: number; variant?: ItemVariant; heading?: 'h2' | 'h3' | 'h4'; sourceName?: string }

function OriginalClues({ item }: { item: Item }) {
  const { theme } = useTheme()
  const [open, setOpen] = useState(() => {
    const query = theme === 'unfold' ? '(min-width: 1101px)' : '(min-width: 701px)'
    return typeof window !== 'undefined' && window.matchMedia?.(query).matches === true
  })
  const translatedTitle = Boolean(item.title_zh && item.title_zh !== item.title)
  const translatedSummary = Boolean(item.summary_zh && item.summary_zh !== item.summary)
  if (!translatedTitle && !translatedSummary) return null

  return (
    <details className="item-original" open={theme === 'daybreak' || open} onToggle={(event) => { if (theme !== 'daybreak') setOpen(event.currentTarget.open) }}>
      <summary><span>原文线索</span><Icon name="chevron-down" size={14} color="currentColor" /></summary>
      {translatedTitle ? <p className="item-original-title" lang={latinLang(item.title)}>{item.title}</p> : null}
      {translatedSummary && item.summary ? <p className="item-original-summary" lang={latinLang(item.summary)}>{item.summary}</p> : null}
    </details>
  )
}

export default function ItemRow({ item, adapter, rank, variant = 'daily', heading: Heading = 'h2', sourceName }: ItemRowProps) {
  const weekly = variant === 'weekly'
  const title = weekly ? item.title : item.title_zh || item.title
  const copy = weekly ? item.content ?? item.summary : item.summary_zh || item.summary

  return (
    <article className={`item-row item-row--${variant}`} id={`item-${item.id}`}>
      <div className="item-rail" aria-label={`第 ${rank} 条`}><span className="item-rank">{String(rank).padStart(2, '0')}</span></div>
      <div className="item-body">
        <div className="item-heading">
          <Heading className="item-title">
            <a className="t" href={item.url} target="_blank" rel="noopener noreferrer" lang={latinLang(title)} data-host={hostOf(item.url)}>{title}</a>
          </Heading>
        </div>
        <div className="item-context">
          {!weekly ? <>
            {sourceName ? <span className="item-source-name">{sourceName}</span> : null}
            <div className="item-provenance">
              <span className="item-domain">{hostOf(item.url)}</span>
              {item.interest_tag ? <span className="item-tag">{item.interest_tag}</span> : null}
              <Meta item={item} adapter={adapter} rank={rank} variant={variant} />
            </div>
            <OriginalClues item={item} />
          </> : <Meta item={item} adapter={adapter} rank={rank} variant={variant} />}
        </div>
        {copy ? (
          weekly ? (
            <div className="item-content item-content--weekly">
              {copy.split('\n').map((paragraph, index) => (
                <p key={index}><Mixed text={paragraph} font="latin" size="inherit" color="inherit" lineHeight={1.9} /></p>
              ))}
            </div>
          ) : <p className="item-summary" lang={latinLang(copy)}>{copy}</p>
        ) : null}
        {weekly ? <WeeklyMedia item={item} /> : (
          item.reason ? <section className="item-reason-panel" aria-label="值得关注">
            <p className="item-reason-label">值得关注</p>
            <p className="item-reason">{item.reason}</p>
          </section> : <p className="item-reason-missing">理由尚未补上</p>
        )}
      </div>
      <div className="item-actions">
        <a className="item-original-action" href={item.url} target="_blank" rel="noopener noreferrer">
          <span>{adapter === 'github_trending' ? '查看仓库' : '阅读原文'}</span><Icon name="arrow-up-right" size={16} color="currentColor" />
        </a>
        <FavoriteButton className="item-mark" itemId={item.id} urlHash={item.url_hash} title={title} />
      </div>
    </article>
  )
}
