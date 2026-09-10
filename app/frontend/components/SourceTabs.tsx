import { Tabs } from 'radix-ui'
import type * as React from 'react'

import { SourceMark } from '@/components/Illustration'
import type { SourceSummary } from '@/types/lowpass'

// 来源切换：三条并排的纸报式索引条，当前项反白成墨块，其余 1px 描边；
// 44px 墨线图标 + 来源名 Newsreader 600 32px。手机三格横排、图标在上名字在下。
// 竖排书脊方案被产品负责人否过（round-9 笔记），不要再提。
// 一次只显示一个来源（PRD 6.2）：条目已经全在 props 里，切换是本地状态，不回服务端。
// 画布：docs/design/src/pages_front3.py 的 tabs() 与 tabs_m()。

// 栏级状态直接标在索引条的名字下面（PRD 6.2）；ok 与 pending 不占这一行。
const STATE_LINES: Record<SourceSummary['state'], string | null> = {
  ok: null,
  pending: null,
  failed: '今日抓取失败',
  empty: '今日无新内容',
}

export type SourceTabsProps = React.PropsWithChildren<{
  sources: SourceSummary[]
  activeId: string
  onSelect: (id: string) => void
}>

export default function SourceTabs({ sources, activeId, onSelect, children }: SourceTabsProps) {
  return (
    <Tabs.Root value={activeId} onValueChange={onSelect}>
      <Tabs.List className="source-tabs" aria-label="来源">
        {sources.map((source) => (
          <Tabs.Trigger key={source.id} value={source.id} className="source-tab">
            <SourceMark adapter={source.adapter} hole="var(--tab-hole)" className="source-tab-icon" />
            <span className="source-tab-body">
              <span className="source-tab-name">{source.name}</span>
              {STATE_LINES[source.state] ? <span className="source-tab-state">{STATE_LINES[source.state]}</span> : null}
            </span>
          </Tabs.Trigger>
        ))}
      </Tabs.List>

      <Tabs.Content value={activeId}>{children}</Tabs.Content>
    </Tabs.Root>
  )
}
