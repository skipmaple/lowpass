import { Link } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Dialog from '@/components/Dialog'
import Icon from '@/components/Icon'
import Mark from '@/components/Mark'
import Table from '@/components/Table'
import { useToasts } from '@/components/Toast'
import { testFetch } from '@/lib/admin'
import { useAdminOperations } from '@/lib/operations'
import { ADMIN_SOURCES_NEW, adminSourceEditHref, adminSourceEnablementHref, adminSourceRunsHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { AdminSourceRow } from '@/types/lowpass'

// 信息源列表（R-3.1，画布 admin_sources()）：排序、名称、适配器、刊物、状态、健康度、上次抓取、下次计划、操作。
// 停用走附录 B 的确认对话框；列表里的「测试抓取」只弹一条提示（设计 A3），预览在表单页。
export type AdminSourcesIndexProps = { sources: AdminSourceRow[]; summary: string }

const HEADERS = ['名称 / 来源类型', '刊物 / 状态', '健康度', '操作', '抓取计划']
const WIDTHS = ['minmax(0, 1.4fr)', 'minmax(0, .8fr)', 'minmax(0, 1fr)', 'minmax(0, 1.5fr)', 'minmax(0, 1.4fr)']

function Health({ row }: { row: AdminSourceRow }) {
  return (
    <>
      <Mark state={row.health === 'ok' ? 'published' : 'empty'} label={row.health_label} />
      <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: row.health === 'ok' ? 'var(--ink)' : 'var(--ink2)' }}>
        {row.health_label}
      </span>
    </>
  )
}

export default function Index({ sources, summary }: AdminSourcesIndexProps) {
  const operations = useAdminOperations()
  const [disabling, setDisabling] = useState<AdminSourceRow | null>(null)
  // 各行独立跟踪测试请求，后返回的结果仍保留明确的来源名。
  const [testingIds, setTestingIds] = useState<Set<string>>(new Set())
  const { toasts, push, dismiss } = useToasts()

  async function test(row: AdminSourceRow) {
    setTestingIds((current) => new Set(current).add(row.id))
    try {
      const result = await testFetch({ id: row.id, name: row.name, adapter: row.adapter, publication: row.publication, config: row.config })
      if (result.ok) push('ok', `${row.name} · 解析 ${result.parsed} 条 · 丢弃 ${result.dropped} 条 · 用时 ${(result.duration_ms / 1000).toFixed(1)} 秒`)
      else push('fail', `${row.name} · ${result.error ?? '抓取失败'}`)
    } catch (error) {
      push('fail', `${row.name} · ${error instanceof Error ? error.message : '请求失败'}`)
    } finally {
      setTestingIds((current) => { const next = new Set(current); next.delete(row.id); return next })
    }
  }

  const rows = sources.map((row) => ({
    key: row.id,
    cells: [
      <div className="admin-cell-stack"><Mixed text={row.name} font="latin" size="var(--fs-15)" color="var(--ink)" />{row.adapter_label !== row.name ? <Mixed text={row.adapter_label} font="latin" /> : null}</div>,
      <div className="admin-cell-stack"><span className="chip-outline">{row.publication === 'daily' ? '日刊' : '周刊'}</span><span className="cjk">{row.enabled ? '启用' : '停用'}</span></div>,
      <Health row={row} />,
      <div className="admin-actions">
        <Link className="link-button" href={adminSourceEditHref(row.id)}>编辑</Link>
        <Link className="link-button" href={adminSourceRunsHref(row.id)}>记录</Link>
        <details className="admin-details"><summary>更多操作</summary><div className="admin-actions">
        <button type="button" className="link-button" disabled={testingIds.has(row.id)} onClick={() => test(row)}>{testingIds.has(row.id) ? '测试中…' : '测试抓取'}</button>
        {row.enabled ? (
          <button type="button" className="link-button" disabled={operations.busy(row.id)} onClick={() => setDisabling(row)}>{operations.busy(row.id) ? '正在停用…' : '停用'}</button>
        ) : (
          <button type="button" className="link-button" disabled={operations.busy(row.id)} onClick={() => operations.post(row.id, row.name, adminSourceEnablementHref(row.id))}>{operations.busy(row.id) ? '正在启用…' : '启用'}</button>
        )}
        </div></details>
      </div>,
      <details className="admin-details"><summary>上次抓取 / 下次计划</summary><div className="admin-cell-stack"><span className="cjk">排序 <span className="data">{row.sort_order}</span></span><span className="cjk">上次抓取</span><Mixed text={row.last_fetch_label || '—'} /><span className="cjk">下次计划</span><Mixed text={row.next_run_label || '—'} /></div></details>,
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
      <Table className="sources-table" headers={HEADERS} widths={WIDTHS} rows={rows} empty="还没有来源" />
      <div className="admin-summary">
        <Mixed text={summary} />
      </div>
      <Dialog
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
