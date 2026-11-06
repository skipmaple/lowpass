import { Head } from '@inertiajs/react'
import type * as React from 'react'

import { Ctrl } from '@/components/Ctrl'
import { Mixed } from '@/lib/typeset'

// 通用期头（画布 pages_site.py 的 page_head()）：大字文楷 56 在左，右侧叠放 Maple 13 与文楷 20，
// 右端控件，底线 2px。日刊详情、周刊详情、两个归档页共用这一个装置。
// 期导航在所有宽度使用同一组文字链接；手机上独立一行，保留 44px 触控高度。
// 归档页的翻月、翻年按钮带的是月份与年份，收不成图标，就整行留在期头下面。

export type PageHeadNav = {
  prevHref: string | null
  nextHref: string | null
  archiveHref: string
  archiveLabel?: string
}

export type PageHeadProps = {
  big: string
  headingRef?: React.Ref<HTMLHeadingElement>
  context?: string
  title?: string
  top?: React.ReactNode
  bottom?: string | null
  tag?: React.ReactNode
  nav?: PageHeadNav
  controls?: React.ReactNode
}

export default function PageHead({ big, headingRef, context, title, top, bottom, tag, nav, controls }: PageHeadProps) {
  return (
    <>
      <Head title={title ?? (context ? `${context} · ${big}` : big)} />
      <header className={nav ? 'page-head page-head--issue' : 'page-head'}>
        <div className="issue-head-main">
          {context ? <p className="page-context">{context}</p> : null}
          <div className="issue-head-title">
            <h1 ref={headingRef} tabIndex={headingRef ? -1 : undefined} className="issue-head-date" aria-label={big}><Mixed text={big} font="latin" size="inherit" color="inherit" lineHeight="inherit" /></h1>
            {top || bottom ? (
              <div className="issue-head-stack">
                {top}
                {bottom ? <span className="issue-head-weekday">{bottom}</span> : null}
              </div>
            ) : null}
          </div>
          {tag ? <div className="issue-head-tag">{tag}</div> : null}
        </div>

        {nav ? (
          <nav className="issue-nav" aria-label="期导航">
            <Ctrl href={nav.prevHref} label="上一期" icon="chevron-left" side="left" turn="back" />
            <Ctrl href={nav.archiveHref} label={nav.archiveLabel ?? '归档'} />
            <Ctrl href={nav.nextHref} label="下一期" icon="chevron-right" side="right" turn="forward" />
          </nav>
        ) : null}
        {controls ? <nav className="page-nav" aria-label="页面导航">{controls}</nav> : null}
      </header>

    </>
  )
}
