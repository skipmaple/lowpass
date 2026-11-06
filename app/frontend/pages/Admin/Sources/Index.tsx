import { Link } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Dialog from '@/components/Dialog'
import Icon from '@/components/Icon'
import PendingLabel from '@/components/PendingLabel'
import Table, { type TableRow } from '@/components/Table'
import { useToasts } from '@/components/Toast'
import { TEST_FETCH_FAILED, testFetch } from '@/lib/admin'
import { useAdminOperations } from '@/lib/operations'
import { ADMIN_SOURCES_NEW, adminSourceEditHref, adminSourceEnablementHref, adminSourceRunsHref } from '@/lib/paths'
import { normalizeDateLabel } from '@/lib/displayDate'
import { Mixed } from '@/lib/typeset'
import type { AdminSourceRow } from '@/types/lowpass'

// 信息源列表（R-3.1，画布 admin_sources()）：排序、名称、适配器、刊物、状态、健康度、上次抓取、下次计划、操作。
// 停用走附录 B 的确认对话框；列表里的「测试抓取」只弹一条提示（设计 A3），预览在表单页。
export type AdminSourcesIndexProps = { sources: AdminSourceRow[]; summary: string }

const HEADERS = ['名称 / 来源类型', '刊物 / 状态', '健康度', '操作', '抓取计划']
const WIDTHS = ['minmax(0, 1.6fr)', 'minmax(0, .75fr)', 'minmax(0, .9fr)', 'minmax(0, 1.1fr)', 'minmax(0, 1.4fr)']

function Health({ row }: { row: AdminSourceRow }) {
  return (
    <span className="admin-health" data-health={row.health}>
      <Icon name={row.health === 'ok' ? 'check' : row.health === 'disabled' ? 'clock' : 'triangle-alert'} size={17} color="currentColor" />
      <span>{row.health_label}</span>
    </span>
  )
}

export default function Index({ sources, summary }: AdminSourcesIndexProps) {
  const operations = useAdminOperations(['sources', 'summary'])
  const [disabling, setDisabling] = useState<AdminSourceRow | null>(null)
  // 各行独立跟踪测试请求，后返回的结果仍保留明确的来源名。
  const [testingIds, setTestingIds] = useState<Set<string>>(new Set())
  const { toasts, push, dismiss } = useToasts()
  const attention = sources.filter((row) => row.health === 'recent_failure' || row.health === 'consecutive_failures')

  async function test(row: AdminSourceRow) {
    setTestingIds((current) => new Set(current).add(row.id))
    try {
      const result = await testFetch({ id: row.id, name: row.name, adapter: row.adapter, publication: row.publication, config: row.config })
      if (result.ok) push('ok', `${row.name} · 解析 ${result.parsed} 条 · 丢弃 ${result.dropped} 条 · 用时 ${(result.duration_ms / 1000).toFixed(1)} 秒`)
      else push('fail', `${row.name} · ${result.error ?? TEST_FETCH_FAILED}`)
    } catch (error) {
      push('fail', `${row.name} · ${error instanceof Error ? error.message : TEST_FETCH_FAILED}`)
    } finally {
      setTestingIds((current) => { const next = new Set(current); next.delete(row.id); return next })
    }
  }

  const rows: TableRow[] = sources.map((row) => ({
    key: row.id,
    tone: row.health === 'recent_failure' || row.health === 'consecutive_failures' ? 'attention' : row.enabled ? undefined : 'muted',
    cells: [
      <div className="admin-cell-stack"><span className="admin-source-name"><Mixed text={row.name} font="latin" size="inherit" color="var(--ink)" /></span>{row.adapter_label !== row.name ? <Mixed text={row.adapter_label} font="latin" /> : null}</div>,
      <div className="admin-cell-stack"><span className="chip-outline">{row.publication === 'daily' ? '日刊' : '周刊'}</span><span className="cjk">{row.enabled ? '启用' : '停用'}</span></div>,
      <Health row={row} />,
      <div className="admin-actions">
        <Link data-table-focus="edit" className="link-button" href={adminSourceEditHref(row.id)}>编辑</Link>
        <Link data-table-focus="runs" className="link-button" href={adminSourceRunsHref(row.id)}>记录</Link>
        <details className="admin-details"><summary data-table-focus="more">更多操作</summary><div className="admin-actions">
        <button data-table-focus="test" type="button" className="link-button" disabled={testingIds.has(row.id)} aria-busy={testingIds.has(row.id)} onClick={() => test(row)}><PendingLabel idle="测试抓取" pending="测试中…" busy={testingIds.has(row.id)} /></button>
        {row.enabled ? (
          <button data-table-focus="enablement" type="button" className="link-button" disabled={operations.busy(row.id)} aria-busy={operations.busy(row.id)} onClick={() => setDisabling(row)}><PendingLabel idle="停用" pending="正在停用…" busy={operations.busy(row.id)} /></button>
        ) : (
          <button data-table-focus="enablement" type="button" className="link-button" disabled={operations.busy(row.id)} aria-busy={operations.busy(row.id)} onClick={() => operations.post(row.id, row.name, adminSourceEnablementHref(row.id))}><PendingLabel idle="启用" pending="正在启用…" busy={operations.busy(row.id)} /></button>
        )}
        </div></details>
      </div>,
      <dl className="admin-run-metrics"><dt>排序</dt><dd className="data">{row.sort_order}</dd><dt>上次抓取</dt><dd><Mixed text={normalizeDateLabel(row.last_fetch_label || '—')} /></dd><dt>下次计划</dt><dd><Mixed text={normalizeDateLabel(row.next_run_label || '—')} /></dd></dl>,
    ],
  }))

  return (
    <AdminPage
      section="sources"
      bottom="信息源"
      toasts={toasts}
      onDismissToast={dismiss}
      controls={
        <Link className="btn-primary" href={ADMIN_SOURCES_NEW}>
          <Icon name="plus" color="currentColor" />
          <span>新建来源</span>
        </Link>
      }
    >
      {operations.errors.map((error) => <p key={error.key} role="alert" className="form-feedback">{error.text}</p>)}
      {attention.length > 0 ? (
        <aside className="admin-attention" aria-label="需要关注的信息源">
          <Icon name="triangle-alert" size={20} color="currentColor" />
          <ul>
            {attention.map((row) => (
              <li key={row.id}>
                <span>{row.name} · {row.health_label}</span>
                <Link data-table-focus="runs" className="link-button" href={adminSourceRunsHref(row.id)} aria-label={`查看记录 · ${row.name}`}>查看记录</Link>
              </li>
            ))}
          </ul>
        </aside>
      ) : null}
      <Table className="sources-table" headers={HEADERS} widths={WIDTHS} rows={rows} mobile={{ primary: [0, 2, 1, 4, 3], detailsLabel: '抓取计划' }} empty="还没有来源" />
      <div className="admin-summary">
        <Mixed text={summary} />
      </div>
      <Dialog
        tone="danger"
        open={disabling !== null}
        text={`停用后不再抓取，历史内容保留。确认停用 ${disabling?.name ?? ''}？`}
        cancel="取消"
        confirm="停用"
        onCancel={() => setDisabling(null)}
        onConfirm={() => {
          if (disabling) operations.remove(disabling.id, disabling.name, adminSourceEnablementHref(disabling.id))
          setDisabling(null)
        }}
      />
    </AdminPage>
  )
}

Index.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
