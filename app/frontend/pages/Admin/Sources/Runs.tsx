import { router } from '@inertiajs/react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import { Ctrl } from '@/components/Ctrl'
import Icon from '@/components/Icon'
import Mark from '@/components/Mark'
import Seg from '@/components/Seg'
import Table from '@/components/Table'
import { ADMIN_SOURCES, adminIssueRefetchHref, adminSourceRunsHref } from '@/lib/paths'
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

const HEADERS = ['开始时间', '耗时', '状态', '尝试', '条目', '丢弃', '错误摘要', '触发']
const WIDTHS = ['150px', '80px', '110px', '70px', '60px', '60px', 'minmax(0, 1fr)', '60px']

export default function Runs({ source, status, runs, latest_issue, active_runs, finished_runs }: AdminSourcesRunsProps) {
  const manual = useManualRuns({ active: active_runs, finished: finished_runs, only: ['runs', 'active_runs', 'finished_runs'] })
  const busy = latest_issue !== null && manual.running(latest_issue.period_key, source.name)

  const rows = runs.map((run) => ({
    key: run.id,
    cells: [
      run.started_label ? <Mixed text={run.started_label} color="var(--ink)" /> : null,
      run.duration_label ? <Mixed text={run.duration_label} /> : null,
      <>
        <Mark state={run.status === 'succeeded' ? 'published' : run.status === 'queued' || run.status === 'running' ? 'generating' : 'empty'} label={run.status_label} />
        <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: run.status === 'succeeded' ? 'var(--ink)' : 'var(--ink2)' }}>{run.status_label}</span>
      </>,
      <span className="data">{run.attempt_label}</span>,
      run.item_count === null ? null : <span className="data">{run.item_count}</span>,
      run.dropped_count === null ? null : <span className="data">{run.dropped_count}</span>,
      run.error_summary ? <Mixed text={run.error_summary} /> : null,
      <span className="cjk" style={{ fontSize: 'var(--fs-13)', color: 'var(--ink2)' }}>{run.trigger_label}</span>,
    ],
  }))

  return (
    <AdminPage
      section="sources"
      big={source.name}
      top={<Mixed text={source.adapter_label} font="latin" />}
      bottom="抓取记录"
      toasts={manual.toasts}
      onDismissToast={manual.dismiss}
      controls={
        <>
          <Ctrl href={ADMIN_SOURCES} label="返回列表" icon="chevron-left" side="left" />
          {latest_issue ? (
            <button type="button" className="btn-primary" disabled={busy} onClick={() => router.post(adminIssueRefetchHref(latest_issue.period_key), { source_id: source.id })}>
              <Icon name={busy ? 'clock' : 'refresh-cw'} color="currentColor" />
              <span>{busy ? '进行中' : `重抓 ${latest_issue.label}`}</span>
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
      <Table headers={HEADERS} widths={WIDTHS} rows={rows} empty="还没有抓取记录" />
    </AdminPage>
  )
}

Runs.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
