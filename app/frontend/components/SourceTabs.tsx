import { Tabs } from 'radix-ui'
import { useLayoutEffect, useRef, useState } from 'react'
import type * as React from 'react'

import { SourceMark } from '@/components/Illustration'
import { latinLang } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

// 来源切换：三条并排的纸报式索引条，当前项反白成墨块，其余 1px 描边；
// 44px 墨线图标 + 来源名 Newsreader 600。手机三格横排、图标在上名字在下。
// 竖排书脊方案被产品负责人否过（round-9 笔记），不要再提。
// 一次只显示一个来源（PRD 6.2）：条目已经全在 props 里，切换是本地状态，不回服务端。
// 画布：docs/design/src/pages_front3.py 的 tabs() 与 tabs_m()。
//
// 墨块平移（设计 skill「动效」M1）：索引条上叠一份 aria-hidden 的反白副本，clip-path 只露出当前项；
// 换来源时过渡 clip-path，墨块从旧来源滑到新来源，块里的字始终是纸色、块外是墨色。点击、焦点、读屏都还是
// 下面那条真的索引条（副本 pointer-events: none、inert）。量不到位置（还没布局、jsdom）就不叠副本，
// 当前项照旧自己反白。

// 栏级状态直接标在索引条的名字下面（PRD 6.2）；ok 与 pending 不占这一行。
// 用画布 tabs(kickers=…) 的短形：这一行是索引条上的小字，长句留给列表区。
const STATE_LINES: Record<SourceSummary['state'], string | null> = {
  ok: null,
  pending: null,
  failed: '抓取失败',
  empty: '本期无新内容',
  no_backfill: '无法回填',
}

export type Box = { left: number; top: number; width: number; height: number }

// 当前项相对索引条容器的位置换成 clip-path 的 inset(上 右 下 左)，四舍五入到 0.01px
export function inkInset(frame: { width: number; height: number }, tab: Box): string {
  const round = (value: number) => Math.round(value * 100) / 100
  const right = frame.width - (tab.left + tab.width)
  const bottom = frame.height - (tab.top + tab.height)
  return `inset(${round(tab.top)}px ${round(right)}px ${round(bottom)}px ${round(tab.left)}px)`
}

// 真的索引条与反白副本画同一张脸，位置才对得齐
function TabFace({ source }: { source: SourceSummary }) {
  return (
    <>
      <SourceMark adapter={source.adapter} hole="var(--tab-hole)" className="source-tab-icon" />
      <span className="source-tab-body">
        <span className="source-tab-name" lang={latinLang(source.name)}>{source.name}</span>
        {STATE_LINES[source.state] ? <span className="source-tab-state">{STATE_LINES[source.state]}</span> : null}
      </span>
    </>
  )
}

export type SourceTabsProps = {
  sources: SourceSummary[]
  activeId: string
  onSelect: (id: string) => void
  children: (source: SourceSummary) => React.ReactNode
}

export default function SourceTabs({ sources, activeId, onSelect, children }: SourceTabsProps) {
  const frameRef = useRef<HTMLDivElement>(null)
  const listRef = useRef<HTMLDivElement>(null)
  const [clip, setClip] = useState<string | null>(null)
  // 首次渲染的面板不做换入动画，读者切过一次之后新挂上的面板才做
  const [switched, setSwitched] = useState(false)

  useLayoutEffect(() => {
    const frame = frameRef.current
    const list = listRef.current
    if (!frame || !list) return
    let alive = true

    function measure() {
      if (!alive || !frame || !list) return
      const tab = list.querySelector<HTMLElement>('[role="tab"][data-state="active"]')
      const box = frame.getBoundingClientRect()
      if (!tab || box.width === 0) {
        setClip(null)
        return
      }
      const rect = tab.getBoundingClientRect()
      setClip(inkInset(box, { left: rect.left - box.left, top: rect.top - box.top, width: rect.width, height: rect.height }))
    }

    measure()
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(measure)
    observer?.observe(frame)
    // 网页字体到了，来源名的宽度会变（换行时连高度也变）：再量一次
    document.fonts?.ready.then(measure).catch(() => {})
    return () => {
      alive = false
      observer?.disconnect()
    }
  }, [activeId, sources])

  function select(id: string) {
    setSwitched(true)
    onSelect(id)
  }

  return (
    <Tabs.Root value={activeId} onValueChange={select}>
      <div className="source-tabs-frame" ref={frameRef} data-ink={clip ? '' : undefined}>
        {/* 不覆盖 tabIndex：Radix 的 roving focus 让整条索引占 Tab 序列里的一站（进来落在当前源），
            「返回来源目录」的锚点也靠这一站能聚焦。写成 -1 会把整条索引踢出 Tab 序列。 */}
        <Tabs.List ref={listRef} id="source-directory" className="source-tabs" aria-label="来源">
          {sources.map((source) => (
            <Tabs.Trigger key={source.id} value={source.id} className="source-tab">
              <TabFace source={source} />
            </Tabs.Trigger>
          ))}
        </Tabs.List>
        {clip ? (
          <div className="source-tabs source-tabs-ink" aria-hidden="true" inert style={{ clipPath: clip }}>
            {sources.map((source) => (
              <span key={source.id} className="source-tab" data-state="active">
                <TabFace source={source} />
              </span>
            ))}
          </div>
        ) : null}
      </div>

      {/* 每个源都摆一个面板，好让每条 trigger 的 aria-controls 指得到自己的 tabpanel；
          非当前的面板 Radix 自己会卸载，所以列多少个源都不多渲染一条条目。 */}
      {sources.map((source) => (
        <Tabs.Content key={source.id} value={source.id} className="source-panel" data-switched={switched ? '' : undefined}>
          {children(source)}
        </Tabs.Content>
      ))}
    </Tabs.Root>
  )
}
