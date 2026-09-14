import { Link, router } from '@inertiajs/react'
import { useState } from 'react'
import type * as React from 'react'

import AdminPage, { AdminLayout } from '@/components/AdminPage'
import Dialog from '@/components/Dialog'
import Icon from '@/components/Icon'
import Mark from '@/components/Mark'
import Table from '@/components/Table'
import { useToasts } from '@/components/Toast'
import { testFetch } from '@/lib/admin'
import { ADMIN_SOURCES_NEW, adminSourceEditHref, adminSourceEnablementHref, adminSourceRunsHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { AdminSourceRow } from '@/types/lowpass'

// 信息源列表（R-3.1，画布 admin_sources()）：排序、名称、适配器、刊物、状态、健康度、上次抓取、下次计划、操作。
// 停用走附录 B 的确认对话框；列表里的「测试抓取」只弹一条提示（设计 A3），预览在表单页。
export type AdminSourcesIndexProps = { sources: AdminSourceRow[]; summary: string }

const HEADERS = ['排序', '名称', '适配器', '刊物', '状态', '健康度', '上次抓取', '下次计划', '操作']
const WIDTHS = ['40px', '170px', '120px', '60px', '44px', '110px', 'minmax(0, 1fr)', '120px', '200px']

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
  const [disabling, setDisabling] = useState<AdminSourceRow | null>(null)
  // 一次只可能有一行在测试抓取（每行的按钮各自控自己的禁用态，不是全表一把锁）
  const [testingId, setTestingId] = useState<string | null>(null)
  const { toasts, push, dismiss } = useToasts()

  async function test(row: AdminSourceRow) {
    setTestingId(row.id)
    try {
      const result = await testFetch({ id: row.id, name: row.name, adapter: row.adapter, publication: row.publication, config: row.config })
      if (result.ok) push('ok', `解析 ${result.parsed} 条 · 丢弃 ${result.dropped} 条 · 用时 ${(result.duration_ms / 1000).toFixed(1)} 秒`)
      else push('fail', result.error ?? '抓取失败')
    } catch (error) {
      push('fail', error instanceof Error ? error.message : '请求失败')
    } finally {
      setTestingId(null)
    }
  }

  const rows = sources.map((row) => ({
    key: row.id,
    cells: [
      <span className="data" style={{ color: 'var(--ink)' }}>{row.sort_order}</span>,
      <Mixed text={row.name} font="latin" size="var(--fs-15)" color="var(--ink)" />,
      <Mixed text={row.adapter_label} font="latin" size="var(--fs-15)" color="var(--ink)" />,
      <span className="chip-outline">{row.publication === 'daily' ? '日刊' : '周刊'}</span>,
      <span className="cjk" style={{ fontSize: 'var(--fs-15)' }}>{row.enabled ? '启用' : '停用'}</span>,
      <Health row={row} />,
      <Mixed text={row.last_fetch_label} />,
      row.next_run_label ? <Mixed text={row.next_run_label} /> : null,
      <span className="admin-actions">
        <Link className="link-button" href={adminSourceEditHref(row.id)}>编辑</Link>
        <button type="button" className="link-button" disabled={testingId === row.id} onClick={() => test(row)}>测试抓取</button>
        <Link className="link-button" href={adminSourceRunsHref(row.id)}>记录</Link>
        {row.enabled ? (
          <button type="button" className="link-button" onClick={() => setDisabling(row)}>停用</button>
        ) : (
          <button type="button" className="link-button" onClick={() => router.post(adminSourceEnablementHref(row.id))}>启用</button>
        )}
      </span>,
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
      <Table headers={HEADERS} widths={WIDTHS} rows={rows} empty="还没有来源" />
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
          if (disabling) router.delete(adminSourceEnablementHref(disabling.id))
          setDisabling(null)
        }}
      />
    </AdminPage>
  )
}

Index.layout = (page: React.ReactNode) => <AdminLayout>{page}</AdminLayout>
