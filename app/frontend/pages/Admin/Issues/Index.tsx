import { Link } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Chip from '@/components/Chip'
import { Ctrl } from '@/components/Ctrl'
import Dialog from '@/components/Dialog'
import Icon from '@/components/Icon'
import Mark from '@/components/Mark'
import Seg from '@/components/Seg'
import Table from '@/components/Table'
import { ADMIN_TODAY_ISSUE, adminIssueBackfillHref, adminIssueReasonsHref, adminIssueRefetchHref, adminIssuesHref, dailyHref, weeklyHref } from '@/lib/paths'
import { useAdminOperations } from '@/lib/operations'
import { useManualRuns } from '@/lib/runs'
import { Mixed } from '@/lib/typeset'
import type { AdminIssueRow, ArchiveNav, FinishedRun, ManualRun } from '@/types/lowpass'

// 期（5.6，画布 admin_issues() 与 admin_dialogs()）：一页一个月，日刊逐天（缺期给「补生成」），周刊按周；
// 「重抓某源」在对话框里选源；「立即生成今日日刊」已有期时先弹附录 B 的确认（R-3.11）
export type AdminIssuesIndexProps = {
  month_label: string
  prev_month: ArchiveNav
  next_month: ArchiveNav
  summary: string
  kind: 'all' | 'daily' | 'weekly'
  rows: AdminIssueRow[]
  today_issue_exists: boolean
  today_period_key: string
  active_runs: ManualRun[]
  finished_runs: FinishedRun[]
}

const HEADERS = ['刊物', '日期 / 周次', '状态', '生成时间', '各源结果', '理由', '操作']
const WIDTHS = ['minmax(0, .5fr)', 'minmax(0, 1fr)', 'minmax(0, 1fr)', 'minmax(0, 1fr)', 'minmax(0, 1.5fr)', 'minmax(0, 1fr)', 'minmax(0, 1.5fr)']

function markOf(state: AdminIssueRow['state']) {
  if (state === 'published') return 'published'
  if (state === 'generating') return 'generating'
  if (state === 'missing') return 'missing'
  return 'empty'
}

export default function Index({ month_label, prev_month, next_month, summary, kind, rows, today_issue_exists, today_period_key, active_runs, finished_runs }: AdminIssuesIndexProps) {
  const manual = useManualRuns({ active: active_runs, finished: finished_runs, only: ['rows', 'active_runs', 'finished_runs', 'summary', 'today_issue_exists', 'today_period_key'] })
  const operations = useAdminOperations()
  const [pendingOnly, setPendingOnly] = useState(false)
  const [refetching, setRefetching] = useState<AdminIssueRow | null>(null)
  const [sourceId, setSourceId] = useState<string>('')
  const [confirmToday, setConfirmToday] = useState(false)

  function openRefetch(row: AdminIssueRow) {
    setRefetching(row)
    setSourceId(row.refetchable_sources[0]?.id ?? '')
  }

  const visibleRows = pendingOnly ? rows.filter((row) => row.state === 'missing' || (row.reasons?.missing ?? 0) > 0 || row.source_marks?.split(' · ').some((mark) => mark.endsWith(' 失败'))) : rows
  const todayRunning = manual.running(today_period_key) || rows.some((row) => row.kind === 'daily' && row.period_key === today_period_key && row.state === 'generating')
  const selectedSource = refetching?.refetchable_sources.find((source) => source.id === sourceId)

  const tableRows = visibleRows.map((row) => ({
    key: `${row.kind}-${row.period_key}`,
    cells: [
      <span className="chip-outline">{row.kind === 'daily' ? '日刊' : '周刊'}</span>,
      <span className="data" style={{ color: 'var(--ink)' }}>{row.period_key}</span>,
      <>
        <Mark state={markOf(row.state)} label={row.state_label} />
        <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: row.state === 'published' ? 'var(--ink)' : 'var(--ink2)' }}>{row.state_label}</span>
      </>,
      row.time_label ? <Mixed text={row.time_label} /> : null,
      row.source_marks ? <Mixed text={row.source_marks} /> : null,
      // 缺 N 条是反白小签（设计 §6.2）；已生成与生成不了的两句都是文楷灰字
      row.reasons ? (
        row.reasons.ready && row.reasons.missing > 0 ? (
          <Chip text={row.reasons.label} />
        ) : (
          <span className="cjk" style={{ fontSize: 'var(--fs-13)', color: 'var(--ink2)' }}>{row.reasons.label}</span>
        )
      ) : null,
      <span className="admin-actions">
        {row.state === 'missing' ? (
          <button type="button" className="link-button" disabled={operations.busy(`backfill-${row.period_key}`)} onClick={() => operations.post(`backfill-${row.period_key}`, row.period_key, adminIssueBackfillHref(row.period_key))}>
            <Icon name="refresh-cw" color="currentColor" />
            <span>{operations.busy(`backfill-${row.period_key}`) ? '正在补生成…' : '补生成'}</span>
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
              <button type="button" className="link-button" disabled={!row.reasons.ready || operations.busy(`reasons-${row.period_key}`)} title={!row.reasons.ready ? row.reasons.label : undefined} onClick={() => operations.post(`reasons-${row.period_key}`, row.period_key, adminIssueReasonsHref(row.period_key))}>{operations.busy(`reasons-${row.period_key}`) ? '正在提交理由任务…' : '重生成理由'}</button>
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
        <button type="button" className="btn-primary" disabled={operations.busy('today') || todayRunning} onClick={() => (today_issue_exists ? setConfirmToday(true) : operations.post('today', '今日日刊', ADMIN_TODAY_ISSUE))}>
          <Icon name="refresh-cw" color="currentColor" />
          <span>{operations.busy('today') ? '正在提交…' : todayRunning ? '今日日刊处理中…' : today_issue_exists ? '重抓今日日刊' : '生成今日日刊'}</span>
        </button>
      }
    >
      <div className="admin-toolbar">
        <Seg
          label="刊物"
          options={[
            { label: '全部', href: adminIssuesHref({ kind: 'all' }), active: kind === 'all' },
            { label: '日刊', href: adminIssuesHref({ kind: 'daily' }), active: kind === 'daily' },
            { label: '周刊', href: adminIssuesHref({ kind: 'weekly' }), active: kind === 'weekly' },
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
      <Table headers={HEADERS} widths={WIDTHS} rows={tableRows} empty={pendingOnly ? "没有待处理的刊物" : "这个月还没有期"} />
      <div className="admin-summary">
        <Mixed text={summary} />
      </div>

      <Dialog
        open={refetching !== null}
        text={`重抓 ${refetching?.period_key ?? ''} 的哪个来源？`}
        cancel="取消"
        confirm={`重抓 ${selectedSource?.name ?? '来源'}`}
        busy={sourceId === ''}
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
