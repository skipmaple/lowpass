import type * as React from 'react'

import { Ctrl, Square } from '@/components/Ctrl'

// 通用期头（画布 pages_site.py 的 page_head()）：大字文楷 56 在左，右侧叠放 Maple 13 与文楷 20，
// 右端控件，底线 2px。日刊详情、周刊详情、两个归档页共用这一个装置。
// 期导航（前一期 / 归档 / 后一期）在手机上收成三个 44px 方形图标按钮；
// 归档页的翻月、翻年按钮带的是月份与年份，收不成图标，就整行留在期头下面。

export type PageHeadNav = {
  prevHref: string | null
  nextHref: string | null
  archiveHref: string
  archiveLabel?: string
}

export type PageHeadProps = {
  big: string
  top?: React.ReactNode
  bottom?: string | null
  tag?: React.ReactNode
  nav?: PageHeadNav
  controls?: React.ReactNode
}

export default function PageHead({ big, top, bottom, tag, nav, controls }: PageHeadProps) {
  return (
    <>
      <header className="page-head">
        <div className="issue-head-main">
          <div className="issue-head-title">
            <h1 className="issue-head-date">{big}</h1>
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
            <Ctrl href={nav.prevHref} label="前一期" icon="chevron-left" side="left" />
            <Ctrl href={nav.archiveHref} label={nav.archiveLabel ?? '归档'} />
            <Ctrl href={nav.nextHref} label="后一期" icon="chevron-right" side="right" />
          </nav>
        ) : null}
        {controls ? <nav className="page-nav">{controls}</nav> : null}
      </header>

      {/* 手机上三个 44px 方形图标按钮另起一行排在期头底线下面：
          375px 宽里 40px 大字加三个文字按钮装不下。画布 page(compact=True) 的 controls 行就是这么排的。 */}
      {nav ? (
        <nav className="issue-nav-mobile" aria-label="期导航">
          <Square href={nav.prevHref} label="前一期" icon="chevron-left" />
          <Square href={nav.archiveHref} label={nav.archiveLabel ?? '归档'} icon="archive" />
          <Square href={nav.nextHref} label="后一期" icon="chevron-right" />
        </nav>
      ) : null}
    </>
  )
}
