import type * as React from 'react'
import { Fragment, useState } from 'react'

import Icon from '@/components/Icon'
import { Mixed } from '@/lib/typeset'
import type { Item } from '@/types/lowpass'

function httpImage(url: unknown): url is string {
  if (typeof url !== 'string' || !/^https?:\/\//i.test(url)) return false
  try {
    return Boolean(new URL(url).hostname)
  } catch {
    return false
  }
}

function imagePositions(item: Item, paragraphs: string[]): number[] | undefined {
  const urls = item.meta.image_urls
  const positions = item.meta.image_positions
  if (!item.content || item.content.length >= 50_000 || !Array.isArray(urls) || !Array.isArray(positions)) return

  if (urls.length > 0 && urls.length <= 128 && Array.from(urls).every(httpImage) && new Set(urls).size === urls.length
    && positions.length === urls.length && paragraphs.every((text) => text.length > 0)
    && Array.from(positions).every((position, index) => Number.isInteger(position) && position >= 0 && position <= paragraphs.length && (index === 0 || position >= positions[index - 1]))) {
    return positions
  }
}

function WeeklyImage({ item, url, index, total, onError }: { item: Item; url: string; index: number; total: number; onError: () => void }) {
  const [loaded, setLoaded] = useState(false)
  const size = item.image_dimensions?.[url]
  const known = size && [size.width, size.height].every((value) => Number.isInteger(value) && value > 0 && value <= 100_000) ? size : undefined
  const geometry = known ? { '--image-width': `${known.width}px`, '--image-ratio': known.width / known.height } as React.CSSProperties : undefined
  const label = `${item.title}配图${total > 1 ? ` ${index + 1}` : ''}`

  return (
    <figure className={`item-media-frame${known ? ' item-media-frame--sized' : ''}${known && !loaded ? ' item-media-frame--loading' : ''}`} style={geometry}>
      <img
        className="item-media-image"
        src={url}
        width={known?.width}
        height={known?.height}
        alt={label}
        loading="lazy"
        decoding="async"
        referrerPolicy="no-referrer"
        onLoad={() => setLoaded(true)}
        onError={onError}
      />
      <figcaption>
        <a className="item-media-original t" href={url} target="_blank" rel="noopener noreferrer" aria-label={`查看${label}的原图（新标签页）`}>
          原图 <Icon name="arrow-up-right" size={12} />
        </a>
      </figcaption>
    </figure>
  )
}

function WeeklyMedia({ item, indices }: { item: Item; indices?: number[] }) {
  const [failed, setFailed] = useState<ReadonlySet<number>>(() => new Set())
  const imageUrls = Array.isArray(item.meta.image_urls)
    ? item.meta.image_urls.filter((url): url is string => typeof url === 'string' && /^https?:\/\//i.test(url))
    : []
  const visible = imageUrls.map((url, index) => ({ url, index }))
    .filter(({ index }) => !failed.has(index) && (!indices || indices.includes(index)))

  if (visible.length === 0) return null

  return (
    <div className={visible.length > 1 ? 'item-media item-media--multiple' : 'item-media item-media--single'}>
      {visible.map(({ url, index }) => (
        <WeeklyImage key={JSON.stringify([url, index])} item={item} url={url} index={index} total={imageUrls.length} onError={() => setFailed((current) => new Set(current).add(index))} />
      ))}
    </div>
  )
}

function Paragraph({ text, emphasized }: { text: string; emphasized: boolean }) {
  const copy = <Mixed text={text} font="latin" size="var(--fs-15)" color={emphasized ? 'var(--ink)' : 'var(--ink2)'} weight={emphasized ? 600 : 500} lineHeight={1.8} />
  return <p>{emphasized ? <strong>{copy}</strong> : copy}</p>
}

// 新抓取记录可保留图片的原文段落位置；旧记录或任何不可靠元数据完整沿用全文后配图。
export default function WeeklyContent({ item }: { item: Item }) {
  const copy = item.content ?? item.summary
  const paragraphs = copy ? copy.split('\n') : []
  const positions = imagePositions(item, paragraphs)
  const emphasis = item.content && Array.isArray(item.meta.emphasis_positions) && item.meta.emphasis_positions.length <= 256
    && Array.from(item.meta.emphasis_positions).every((position, index, values) => Number.isInteger(position) && position >= 0 && position < paragraphs.length && (index === 0 || position > values[index - 1]))
    ? new Set(item.meta.emphasis_positions) : new Set<number>()
  if (positions) {
    const groups = new Map<number, number[]>()
    positions.forEach((position, index) => {
      const indices = groups.get(position) ?? []
      indices.push(index)
      groups.set(position, indices)
    })

    return (
      <div className="item-content item-content--weekly">
        {Array.from({ length: paragraphs.length + 1 }, (_, boundary) => (
          <Fragment key={boundary}>
            {groups.has(boundary) ? <WeeklyMedia item={item} indices={groups.get(boundary)} /> : null}
            {boundary < paragraphs.length ? <Paragraph text={paragraphs[boundary]} emphasized={emphasis.has(boundary)} /> : null}
          </Fragment>
        ))}
      </div>
    )
  }

  return (
    <>
      {copy ? <div className="item-content item-content--weekly">{paragraphs.map((text, index) => <Paragraph key={index} text={text} emphasized={emphasis.has(index)} />)}</div> : null}
      <WeeklyMedia item={item} />
    </>
  )
}
