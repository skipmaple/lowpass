type PendingLabelProps = {
  idle: string
  pending: string
  busy: boolean
  reserve?: string
}

// 两种文案共用一个网格格位，只播报当前文案；请求开始/结束不推挤相邻操作。
export default function PendingLabel({ idle, pending, busy, reserve }: PendingLabelProps) {
  return (
    <span className="pending-label">
      <span aria-hidden={busy || undefined}>{idle}</span>
      <span aria-hidden={!busy || undefined}>{pending}</span>
      {reserve ? <span aria-hidden="true">{reserve}</span> : null}
    </span>
  )
}
