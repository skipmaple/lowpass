import { Link } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import PendingLabel from '@/components/PendingLabel'
import Chip from '@/components/Chip'
import { Ctrl } from '@/components/Ctrl'
import Dialog from '@/components/Dialog'
import Icon from '@/components/Icon'
import Mark from '@/components/Mark'
import Seg from '@/components/Seg'
import Table from '@/components/Table'
import { ADMIN_TODAY_ISSUE, adminIssueBackfillHref, adminIssueReasonsHref, adminIssueRefetchHref, adminIssuesHref, dailyHref, weeklyHref } from '@/lib/paths'
import { usePolling } from '@/lib/polling'
import { useAdminOperations } from '@/lib/operations'
import { useManualRuns } from '@/lib/runs'
import { normalizeDateLabel } from '@/lib/displayDate'
import { Mixed } from '@/lib/typeset'
import type { AdminIssueRow, ArchiveNav, FinishedRun, IssueState, ManualRun } from '@/types/lowpass'

// 期（5.6，画布 admin_issues() 与 admin_dialogs()）：一页一个月，日刊逐天（缺期给「补生成」），周刊按周；
// 「重抓某源」在对话框里选源；「立即生成今日日刊」已有期时先弹附录 B 的确认（R-3.11）
export type AdminIssuesIndexProps = {
  month: string
  month_label: string
  prev_month: ArchiveNav
  next_month: ArchiveNav
  summary: string
  kind: 'all' | 'daily' | 'weekly'
  rows: AdminIssueRow[]
  today_issue_exists: boolean
  today_period_key: string
  today_issue_state: IssueState | null
  active_runs: ManualRun[]
  finished_runs: FinishedRun[]
}

const REFRESH_PROPS = ['rows', 'active_runs', 'finished_runs', 'summary', 'today_issue_exists', 'today_period_key', 'today_issue_state']
const HEADERS = ['刊物', '日期 / 周次', '状态', '发布 / 修订', '各源结果', '理由', '操作']
const WIDTHS = ['minmax(0, .5fr)', 'minmax(0, 1fr)', 'minmax(0, 1fr)', 'minmax(0, 1fr)', 'minmax(0, 1.5fr)', 'minmax(0, 1fr)', 'minmax(0, 1.5fr)']

function markOf(state: AdminIssueRow['state']) {
  if (state === 'published') return 'published'
  if (state === 'generating') return 'generating'
  if (state === 'missing') return 'missing'
  return 'empty'
}

export default function Index({ month, month_label, prev_month, next_month, summary, kind, rows, today_issue_exists, today_period_key, today_issue_state, active_runs, finished_runs }: AdminIssuesIndexProps) {
  const manual = useManualRuns({ active: active_runs, finished: finished_runs, only: REFRESH_PROPS })
  const operations = useAdminOperations(REFRESH_PROPS)
  const reasonsRunning = rows.some((row) => row.reasons?.progress?.active)
  // 手动抓取已经刷新同一组 props；只有它没有轮询时，才为理由或出刊任务启动轮询。
  usePolling((today_issue_state === 'generating' || reasonsRunning) && active_runs.length === 0, REFRESH_PROPS)
  const [pendingOnly, setPendingOnly] = useState(false)
  const [refetching, setRefetching] = useState<AdminIssueRow | null>(null)
  const [sourceId, setSourceId] = useState<string>('')
  const [confirmToday, setConfirmToday] = useState(false)

  function openRefetch(row: AdminIssueRow) {
    setRefetching(row)
    setSourceId(row.refetchable_sources[0]?.id ?? '')
  }

  const visibleRows = pendingOnly ? rows.filter((row) => {
    const progress = row.reasons?.progress
    return row.state === 'missing' || (row.reasons?.missing ?? 0) > 0 || progress?.active ||
      progress?.status === 'partial' || progress?.status === 'failed' ||
      row.source_marks?.split(' · ').some((mark) => mark.endsWith(' 失败'))
  }) : rows
  const todayRunning = manual.running(today_period_key) || today_issue_state === 'generating'
  const selectedSource = refetching?.refetchable_sources.find((source) => source.id === sourceId)

  const tableRows = visibleRows.map((row) => ({
    key: `${row.kind}-${row.period_key}`,
    cells: [
      <span className="chip-outline">{row.kind === 'daily' ? '日刊' : '周刊'}</span>,
      <span className="data" style={{ color: 'var(--ink)' }}>{normalizeDateLabel(row.period_key)}</span>,
      <>
        <Mark state={markOf(row.state)} label={row.state_label} />
        <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: row.state === 'published' ? 'var(--ink)' : 'var(--ink2)' }}>{row.state_label}</span>
      </>,
      row.time_label ? <Mixed text={normalizeDateLabel(row.time_label)} /> : null,
      row.source_marks ? <Mixed text={row.source_marks} /> : null,
      // 优先显示本次任务的进度和结果，不能把保留的旧理由误当作本次生成成功。
      row.reasons ? (
        row.reasons.progress ? (
          <div className="reason-progress" data-state={row.reasons.progress.status}>
            <strong>{row.reasons.progress.label}</strong>
            <span>{row.reasons.progress.detail}</span>
            {row.reasons.progress.error ? <span className="reason-progress-error">{row.reasons.progress.error}</span> : null}
          </div>
        ) : row.reasons.ready && row.reasons.missing > 0 ? (
          <Chip text={row.reasons.label} />
        ) : (
          <span className="cjk" style={{ fontSize: 'var(--fs-13)', color: 'var(--ink2)' }}>{row.reasons.label}</span>
        )
      ) : null,
      <span className="admin-actions">
        {row.state === 'missing' ? (
          <button type="button" className="link-button" disabled={operations.busy(`backfill-${row.period_key}`)} aria-busy={operations.busy(`backfill-${row.period_key}`)} onClick={() => operations.post(`backfill-${row.period_key}`, row.period_key, adminIssueBackfillHref(row.period_key))}>
            <Icon name="refresh-cw" color="currentColor" />
            <PendingLabel idle="补生成" pending="正在补生成…" busy={operations.busy(`backfill-${row.period_key}`)} />
          </button>
        ) : (
          <>
            {row.refetchable_sources.length > 0 ? (
              (manual.running(row.period_key) || operations.busy(`refetch-${row.period_key}`)) ? (
                <button type="button" className="link-button" disabled>进行中</button>
              ) : (
                <button type="button" className="link-button" onClick={() => openRefetch(row)}>重抓某源</button>
              )
            ) : null}
            {row.kind === 'daily' && row.reasons ? (
              <button type="button" className="link-button" disabled={!row.reasons.ready || row.reasons.progress?.active || operations.busy(`reasons-${row.period_key}`)} aria-busy={row.reasons.progress?.active || operations.busy(`reasons-${row.period_key}`)} title={!row.reasons.ready ? row.reasons.label : undefined} onClick={() => operations.post(`reasons-${row.period_key}`, row.period_key, adminIssueReasonsHref(row.period_key))}>
                <PendingLabel idle={row.reasons.progress?.active ? (row.reasons.progress.status === 'queued' ? '理由排队中…' : '理由生成中…') : '重生成理由'} pending="正在提交理由任务…" busy={operations.busy(`reasons-${row.period_key}`)} />
              </button>
            ) : null}
            <Link className="link-button" href={row.kind === 'daily' ? dailyHref(row.period_key) : weeklyHref(row.period_key)}>查看</Link>
          </>
        )}
      </span>,
    ],
  }))

  return (
    <AdminPage
      section="issues"
      bottom="刊物管理"
      toasts={manual.toasts}
      onDismissToast={manual.dismiss}
      controls={
        <button type="button" className="btn-primary" disabled={operations.busy('today') || todayRunning} aria-busy={operations.busy('today')} onClick={() => (today_issue_exists ? setConfirmToday(true) : operations.post('today', '今日日刊', ADMIN_TODAY_ISSUE))}>
          <Icon name="refresh-cw" color="currentColor" />
          <PendingLabel idle={todayRunning ? '今日日刊处理中…' : today_issue_exists ? '重抓今日日刊' : '生成今日日刊'} pending="正在提交…" busy={operations.busy('today')} reserve="今日日刊处理中…" />
        </button>
      }
    >
      <div className="admin-toolbar">
        <Seg
          label="刊物"
          options={[
            { label: '全部', href: adminIssuesHref({ kind: 'all', month }), active: kind === 'all' },
            { label: '日刊', href: adminIssuesHref({ kind: 'daily', month }), active: kind === 'daily' },
            { label: '周刊', href: adminIssuesHref({ kind: 'weekly', month }), active: kind === 'weekly' },
          ]}
        />
        <div className="admin-actions" style={{ alignItems: 'center' }}>
          <Mixed text={month_label} font="data" size="var(--fs-15)" color="var(--ink)" />
          {prev_month ? <Ctrl href={adminIssuesHref({ kind, month: prev_month.key })} label={prev_month.label} icon="chevron-left" side="left" /> : null}
          {next_month ? <Ctrl href={adminIssuesHref({ kind, month: next_month.key })} label={next_month.label} icon="chevron-right" side="right" /> : null}
        </div>
      </div>
      <label className="admin-pending-filter"><input type="checkbox" checked={pendingOnly} onChange={(event) => setPendingOnly(event.target.checked)} />待处理</label>
      {operations.errors.map((error) => <p key={error.key} role="alert" className="form-feedback">{error.text}</p>)}
      <Table className="issues-table" headers={HEADERS} widths={WIDTHS} rows={tableRows} mobile={{ primary: [1, 0, 2, 5, 6], detailsLabel: '刊物详情' }} empty={pendingOnly ? "没有待处理的刊物" : "这个月还没有期"} />
      <div className="admin-summary">
        <Mixed text={summary} />
      </div>

      <Dialog
        open={refetching !== null}
        text={`重抓 ${normalizeDateLabel(refetching?.period_key ?? '')} 的哪个来源？`}
        cancel="取消"
        confirm={`重抓 ${selectedSource?.name ?? '来源'}`}
        confirmDisabled={sourceId === ''}
        onCancel={() => setRefetching(null)}
        onConfirm={() => {
          if (refetching && selectedSource) operations.post(`refetch-${refetching.period_key}`, `${refetching.period_key} · ${selectedSource.name}`, adminIssueRefetchHref(refetching.period_key), { source_id: sourceId })
          setRefetching(null)
        }}
      >
        {refetching ? <fieldset className="refetch-sources"><legend>来源</legend>{refetching.refetchable_sources.map((source) => (
          <label key={source.id}><input type="radio" name="refetch-source" value={source.id} checked={sourceId === source.id} onChange={() => setSourceId(source.id)} /><Mixed text={source.name} font="latin" size="var(--fs-15)" color="var(--ink)" /></label>
        ))}</fieldset> : null}
      </Dialog>
      <Dialog
        open={confirmToday}
        text="今日日刊已存在。要对所有来源重抓吗？"
        cancel="取消"
        confirm="重抓全部"
        onCancel={() => setConfirmToday(false)}
        onConfirm={() => {
          operations.post('today', '今日日刊', ADMIN_TODAY_ISSUE, { confirm: '1' })
          setConfirmToday(false)
        }}
      />
    </AdminPage>
  )
}

Index.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
