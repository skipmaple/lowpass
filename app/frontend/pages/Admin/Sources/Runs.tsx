import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import { Ctrl } from '@/components/Ctrl'
import Dialog from '@/components/Dialog'
import Icon from '@/components/Icon'
import Mark from '@/components/Mark'
import Seg from '@/components/Seg'
import Table from '@/components/Table'
import { ADMIN_SOURCES, adminIssueRefetchHref, adminSourceRunsHref } from '@/lib/paths'
import { useAdminOperations } from '@/lib/operations'
import { useManualRuns } from '@/lib/runs'
import { Mixed } from '@/lib/typeset'
import type { AdminRunRow, FinishedRun, LatestIssue, ManualRun, Publication } from '@/types/lowpass'

// 抓取记录（R-3.9，画布 admin_runs()）：最近 50 次，按状态筛选（地址参数）；右上角重抓最新一期（R-3.10）
export type AdminSourcesRunsProps = {
  source: { id: string; name: string; adapter_label: string; publication: Publication }
  status: 'all' | 'succeeded' | 'failed'
  runs: AdminRunRow[]
  latest_issue: LatestIssue
  active_runs: ManualRun[]
  finished_runs: FinishedRun[]
}

const HEADERS = ['状态 / 开始时间', '错误', '抓取详情']
const WIDTHS = ['minmax(0, 1fr)', 'minmax(0, 2fr)', 'minmax(0, 1fr)']

function RunError({ error }: { error: string | null }) {
  if (!error) return <span className="data">—</span>
  if (error.length <= 80) return <Mixed text={error} font="latin" />

  return (
    <details className="admin-details">
      <summary><span>错误详情</span> · <Mixed text={`${error.slice(0, 80)}…`} font="latin" /></summary>
      <Mixed text={error} font="latin" />
    </details>
  )
}

export default function Runs({ source, status, runs, latest_issue, active_runs, finished_runs }: AdminSourcesRunsProps) {
  const [confirm, setConfirm] = useState(false)
  const operations = useAdminOperations(['runs', 'active_runs', 'finished_runs', 'latest_issue'])
  const manual = useManualRuns({ active: active_runs, finished: finished_runs, only: ['runs', 'active_runs', 'finished_runs'] })
  const busy = operations.busy('refetch') || (latest_issue !== null && manual.running(latest_issue.period_key, source.name))

  const rows = runs.map((run) => ({
    key: run.id,
    cells: [
      <div className="admin-cell-stack">
        <span className="table-cell-content"><Mark state={run.status === 'succeeded' ? 'published' : run.status === 'queued' || run.status === 'running' ? 'generating' : 'empty'} label={run.status_label} /><span className="cjk">{run.status_label}</span></span>
        <Mixed text={run.started_label || '—'} color="var(--ink)" />
      </div>,
      <RunError error={run.error_summary} />,
      <details className="admin-details"><summary>耗时 / 条目 / 尝试</summary><dl className="admin-run-metrics">
        <dt>耗时</dt><dd><Mixed text={run.duration_label || '—'} /></dd>
        <dt>条目</dt><dd className="data">{run.item_count ?? '—'}</dd>
        <dt>丢弃</dt><dd className="data">{run.dropped_count ?? '—'}</dd>
        <dt>尝试</dt><dd className="data">{run.attempt_label}</dd>
        <dt>触发</dt><dd className="cjk">{run.trigger_label}</dd>
      </dl></details>,
    ],
  }))

  return (
    <AdminPage
      section="sources"
      big={source.name}
      top={source.adapter_label !== source.name ? <Mixed text={source.adapter_label} font="latin" /> : null}
      bottom="抓取记录"
      toasts={manual.toasts}
      onDismissToast={manual.dismiss}
      controls={
        <>
          <Ctrl href={ADMIN_SOURCES} label="返回列表" icon="chevron-left" side="left" />
          {latest_issue ? (
            <button type="button" className="btn-primary" disabled={busy} onClick={() => setConfirm(true)}>
              <Icon name={busy ? 'clock' : 'refresh-cw'} color="currentColor" />
              <span>{busy ? '进行中' : `重抓最新一期 · ${latest_issue.label}`}</span>
            </button>
          ) : null}
        </>
      }
    >
      <div className="admin-toolbar">
        <Seg
          label="状态"
          options={[
            { label: '全部', href: adminSourceRunsHref(source.id), active: status === 'all' },
            { label: '成功', href: adminSourceRunsHref(source.id, 'succeeded'), active: status === 'succeeded' },
            { label: '失败', href: adminSourceRunsHref(source.id, 'failed'), active: status === 'failed' },
          ]}
        />
        <Mixed text={`最近 50 次 · 保留 30 天 · ${runs.length} 条`} />
      </div>
      {operations.errors.map((error) => <p key={error.key} role="alert" className="form-feedback">{error.text}</p>)}
      <Table headers={HEADERS} widths={WIDTHS} rows={rows} empty="还没有抓取记录" />
      <Dialog open={confirm} text={`确认重抓最新一期 ${latest_issue?.period_key ?? ''} 的 ${source.name}？`} cancel="取消" confirm="确认重抓" busy={busy} onCancel={() => setConfirm(false)} onConfirm={() => {
        if (latest_issue) operations.post('refetch', `${latest_issue.period_key} · ${source.name}`, adminIssueRefetchHref(latest_issue.period_key), { source_id: source.id })
        setConfirm(false)
      }} />
    </AdminPage>
  )
}

Runs.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
