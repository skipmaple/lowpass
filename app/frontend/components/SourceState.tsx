import Icon from '@/components/Icon'
import { Mixed } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

// 空来源与抓取失败是不同事实；同一文字适配三套主题，不用装饰图替代状态。

export type SourceStateProps = {
  state: SourceSummary['state']
  lastOkLabel: string | null
}

export default function SourceState({ state, lastOkLabel }: SourceStateProps) {
  if (state === 'failed') {
    return (
      <div className="source-state source-state-failed">
        <Icon name="triangle-alert" size={18} color="currentColor" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="state-line">本期抓取失败，已通知管理员</span>
          {lastOkLabel ? <Mixed text={`上次成功 ${lastOkLabel}`} /> : null}
        </div>
      </div>
    )
  }

  if (state === 'empty') {
    return (
      <div className="source-state">
        <span className="state-line">本期未收录</span>
      </div>
    )
  }

  // R-1.6 补生成的期里不支持回填的源（7.7）：附录 B「该来源无法回填」
  if (state === 'no_backfill') {
    return (
      <div className="source-state">
        <span className="state-line">该来源无法回填</span>
      </div>
    )
  }

  // 连续阅读中，这个来源的等待状态独立可见。
  return <div className="source-state source-state-pending"><span className="state-line">正在收录</span></div>
}
