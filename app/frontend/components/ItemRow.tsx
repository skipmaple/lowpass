import { Link, router, usePage } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import Chip from '@/components/Chip'
import Icon from '@/components/Icon'
import { ADMIN_SETTINGS, adminItemReasonHref } from '@/lib/paths'
import { absoluteStamp, compactCount, relativeAge } from '@/lib/typeset'
import type { Adapter, Item, SharedProps } from '@/types/lowpass'

// 十条格式一致的条目（PRD 5.1「条目结构」，不放大首条）：序号、标题、说明、元数据、
// 兴趣标签、推荐理由。元数据行只有数字与记号，不出现中文单位（设计 skill）。
// 周刊那一版（variant="weekly"）只有序号、标题、摘要与发布时间（D19）。
// 桌面标签在右列，手机标签与序号组成眉行——同一份 DOM，靠 tokens.css 里的 grid-template-areas 换位。
// 画布：docs/design/src/pages_front3.py 的 item() 与 item_m()。

const DOT = <span style={{ fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' }}>·</span>

const data = { fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' } as const

function Age({ published }: { published: string }) {
  const age = relativeAge(published)
  if (age === '') return null
  return (
    <span style={data} title={absoluteStamp(published)}>
      {age}
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

function Meta({ item, adapter, rank, variant }: { item: Item; adapter: Adapter; rank: number; variant: ItemVariant }) {
  const parts: React.ReactNode[] = []

  // 周刊条目只有一个元数据：这条内容的发布时间（画布 pages_site.py 的 rss_section）。
  // 阮一峰那一节整期同一天发布，逐条重复没有信息量，所以 published_at 为空就整行不渲染。
  if (variant === 'weekly') {
    if (!item.published_at) return null
    return <span style={data}>{absoluteStamp(item.published_at)}</span>
  }

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

  if (item.published_at && relativeAge(item.published_at) !== '') parts.push(<Age published={item.published_at} />)

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

// D19：周刊条目不生成推荐理由，也就没有兴趣标签；元数据只剩发布时间。
// heading 是标题的层级（PRD 6.4「标题层级语义正确」）：日刊页 h1 是日期，条目就是 h2；
// 周刊页 h1 是周次、h2 是源名、h3 是板块，所以条目按所在位置降一到两级。
// id 是搜索结果所在期链接的落点（设计 6.3）。
export type ItemVariant = 'daily' | 'weekly'
export type ItemRowProps = { item: Item; adapter: Adapter; rank: number; variant?: ItemVariant; heading?: 'h2' | 'h3' | 'h4'; reasonAvailabilityId?: string }

export default function ItemRow({ item, adapter, rank, variant = 'daily', heading: Heading = 'h2', reasonAvailabilityId }: ItemRowProps) {
  const weekly = variant === 'weekly'
  // 读者页管理员的单条重生成（R-9.6，设计 C6）：读者页面上唯一的管理控件，周刊条目没有理由，也就没有这个按钮
  const { current_user, reason_generation } = usePage<SharedProps>().props
  const admin = current_user?.admin
  const [feedback, setFeedback] = useState<{ text: string; failed: boolean } | null>(null)
  const [sending, setSending] = useState(false)

  // 这一趟是同步调模型的，最坏 20 秒 × 3：请求回来之前按钮禁着，不让连点排三份账
  function regenerate() {
    setSending(true)
    setFeedback(null)
    router.post(adminItemReasonHref(item.id), {}, {
      preserveScroll: true,
      onSuccess: (page) => {
        const flash = page.props.flash as SharedProps['flash'] | undefined
        const text = flash?.alert || flash?.notice
        setFeedback({ text: text || '请求已结束，未收到生成结果，请刷新确认', failed: !!flash?.alert || !text })
      },
      onNetworkError: () => { setFeedback({ text: '网络连接失败，请刷新确认生成结果后重试', failed: true }); return false },
      onHttpException: () => { setFeedback({ text: '服务暂时无法处理请求，请刷新确认生成结果后重试', failed: true }); return false },
      onError: () => setFeedback({ text: '生成失败，请重试', failed: true }),
      onCancel: () => setFeedback({ text: '请求已取消，请刷新确认生成结果', failed: true }),
      onFinish: () => setSending(false),
    })
  }

  return (
    <article className="item-row" id={`item-${item.id}`}>
      <span className="item-rank">{rank}</span>

      <div className="item-body">
        {/* 标题是标题元素（层级见 heading），字号字重不随层级变；两行截断（PRD 6.3）
            落在标题这个块级元素上，下划线仍在里面的 a 上，前两行照常显示。
            R-8.4 原文外链在新标签页打开。 */}
        <Heading className="item-title">
          <a className="t" href={item.url} target="_blank" rel="noopener noreferrer">
            {item.title}
          </a>
        </Heading>
        {/* 周刊摘要行高 1.7（画布 pages_site.item() 的文楷 15/1.7），日刊摘要是 PRD 6.3 的 Newsreader 15/1.5 */}
        {item.summary ? <span className={weekly ? 'item-summary item-summary--weekly' : 'item-summary'}>{item.summary}</span> : null}
        <Meta item={item} adapter={adapter} rank={rank} variant={variant} />
        {!weekly && item.reason ? <div className="item-reason">{item.reason}</div> : null}
        {!weekly && admin ? (
          <div className="reason-controls" aria-busy={sending}>
            <button type="button" className="link-button" aria-describedby={reason_generation?.available === false ? reasonAvailabilityId : undefined} disabled={sending || reason_generation?.available === false} onClick={regenerate}>
              {sending ? '生成中…' : '重新生成理由'}
            </button>
            {reason_generation?.available === false && !reasonAvailabilityId ? <p className="operation-feedback">{reason_generation.unavailable_reason} <Link href={`${ADMIN_SETTINGS}#reasons`} className="t">推荐理由设置</Link></p> : null}
            {feedback ? <p className="operation-feedback" role={feedback.failed ? 'alert' : 'status'}>{feedback.text}</p> : null}
          </div>
        ) : null}
      </div>

      {!weekly && item.interest_tag ? (
        <div className="item-tag">
          <Chip text={item.interest_tag} />
        </div>
      ) : null}
    </article>
  )
}
