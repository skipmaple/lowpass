import { Sunrise } from '@/components/Illustration'
import { Mixed } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

// 栏级状态：一句事实 + 一个时间（设计 skill「状态」）。
// 抓取失败留一幅 130×69 的低通日出加上次成功时间；无新内容只有一句。
// 生成中不在这里说话——期头的标签已经写着「生成中，约 1 分钟后刷新」。
// 画布：docs/design/src/pages_front3.py 的 failure_box() 与 message()。

export type SourceStateProps = {
  state: SourceSummary['state']
  lastOkLabel: string | null
}

export default function SourceState({ state, lastOkLabel }: SourceStateProps) {
  if (state === 'failed') {
    return (
      <div className="source-state source-state-failed">
        <Sunrise className="source-state-art" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="state-line">今日抓取失败，已通知管理员</span>
          {lastOkLabel ? <Mixed text={`上次成功 ${lastOkLabel}`} /> : null}
        </div>
      </div>
    )
  }

  if (state === 'empty') {
    return (
      <div className="source-state">
        <span className="state-line">今日无新内容</span>
      </div>
    )
  }

  // 这一栏还在抓（期头写着「生成中，约 1 分钟后刷新」）：留一段空白，不再说第二遍
  return <div className="source-state-pending" />
}
