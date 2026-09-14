import { Link, router } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import { Ctrl } from '@/components/Ctrl'
import Dialog from '@/components/Dialog'
import Icon from '@/components/Icon'
import Mark from '@/components/Mark'
import Seg from '@/components/Seg'
import SegButtons from '@/components/SegButtons'
import Table from '@/components/Table'
import { ADMIN_TODAY_ISSUE, adminIssueBackfillHref, adminIssueReasonsHref, adminIssueRefetchHref, adminIssuesHref, dailyHref, weeklyHref } from '@/lib/paths'
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
  active_runs: ManualRun[]
  finished_runs: FinishedRun[]
}

const HEADERS = ['刊物', '周期键', '状态', '生成时间', '各源结果', '理由', '操作']
const WIDTHS = ['70px', '120px', '200px', '120px', 'minmax(0, 1fr)', '150px', '200px']

function markOf(state: AdminIssueRow['state']) {
  if (state === 'published') return 'published'
  if (state === 'generating') return 'generating'
  if (state === 'missing') return 'missing'
  return 'empty'
}

export default function Index({ month_label, prev_month, next_month, summary, kind, rows, today_issue_exists, active_runs, finished_runs }: AdminIssuesIndexProps) {
  const manual = useManualRuns({ active: active_runs, finished: finished_runs, only: ['rows', 'active_runs', 'finished_runs', 'summary'] })
  const [refetching, setRefetching] = useState<AdminIssueRow | null>(null)
  const [sourceId, setSourceId] = useState<string>('')
  const [confirmToday, setConfirmToday] = useState(false)

  function openRefetch(row: AdminIssueRow) {
    setRefetching(row)
    setSourceId(row.refetchable_sources[0]?.id ?? '')
  }

  const tableRows = rows.map((row) => ({
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
      row.reasons ? <span className="cjk" style={{ fontSize: 'var(--fs-13)', color: row.reasons.missing > 0 ? 'var(--ink)' : 'var(--ink2)' }}>{row.reasons.label}</span> : null,
      <span className="admin-actions">
        {row.state === 'missing' ? (
          <button type="button" className="btn-primary" onClick={() => router.post(adminIssueBackfillHref(row.period_key))}>
            <Icon name="refresh-cw" color="currentColor" />
            <span>补生成</span>
          </button>
        ) : (
          <>
            {row.refetchable_sources.length > 0 ? (
              manual.running(row.period_key) ? (
                <button type="button" className="link-button" disabled>进行中</button>
              ) : (
                <button type="button" className="link-button" onClick={() => openRefetch(row)}>重抓某源</button>
              )
            ) : null}
            {row.kind === 'daily' && row.reasons ? (
              <button type="button" className="link-button" disabled={row.reasons.label === '未配置模型供应商'} onClick={() => router.post(adminIssueReasonsHref(row.period_key))}>重生成理由</button>
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
      bottom="期"
      toasts={manual.toasts}
      onDismissToast={manual.dismiss}
      controls={
        <button type="button" className="btn-primary" onClick={() => (today_issue_exists ? setConfirmToday(true) : router.post(ADMIN_TODAY_ISSUE, {}))}>
          <Icon name="refresh-cw" color="currentColor" />
          <span>立即生成今日日刊</span>
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
      <Table headers={HEADERS} widths={WIDTHS} rows={tableRows} empty="这个月还没有期" />
      <div className="admin-summary">
        <Mixed text={summary} />
      </div>

      <Dialog
        open={refetching !== null}
        text={`重抓 ${refetching?.period_key ?? ''} 的哪个来源？`}
        cancel="取消"
        confirm="重抓"
        busy={sourceId === ''}
        onCancel={() => setRefetching(null)}
        onConfirm={() => {
          if (refetching && sourceId) router.post(adminIssueRefetchHref(refetching.period_key), { source_id: sourceId })
          setRefetching(null)
        }}
      >
        {refetching ? <SegButtons label="来源" options={refetching.refetchable_sources.map((s) => ({ value: s.id, label: s.name }))} value={sourceId} onChange={setSourceId} /> : null}
      </Dialog>
      <Dialog
        open={confirmToday}
        text="今日日刊已存在。要对所有来源重抓吗？"
        cancel="取消"
        confirm="重抓全部"
        onCancel={() => setConfirmToday(false)}
        onConfirm={() => {
          router.post(ADMIN_TODAY_ISSUE, { confirm: '1' })
          setConfirmToday(false)
        }}
      />
    </AdminPage>
  )
}

Index.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
