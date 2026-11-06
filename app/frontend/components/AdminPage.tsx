import type * as React from 'react'
import { Head } from '@inertiajs/react'

import AdminNav, { type AdminSection } from '@/components/AdminNav'
import Layout from '@/components/Layout'
import { Toasts, type ToastItem } from '@/components/Toast'
import '@/styles/themes-admin-workspace.css'

// 管理导航与工作区共用结构；C 把导航放到页边，A/B 保留横向导航。
// 页面状态和表单只挂载一次，切换外观不会丢失正在编辑的内容。
export type AdminPageProps = React.PropsWithChildren<{
  section: AdminSection
  big?: string
  top?: React.ReactNode
  bottom: string
  controls?: React.ReactNode
  toasts?: ToastItem[]
  onDismissToast?: (id: string) => void
}>

export default function AdminPage({ section, big, top, bottom, controls, toasts, onDismissToast, children }: AdminPageProps) {
  const title = big ?? bottom
  return (
    <div className="admin-workspace">
      <Head title={big ? `${bottom} · ${big}` : `${bottom} · 管理`} />
      <Toasts items={toasts} onDismiss={onDismissToast} />
      <AdminNav active={section} />
      <section className="admin-main" aria-labelledby="admin-page-title">
        <header className="admin-page-head">
          <div className="admin-page-identity">
            <h1 id="admin-page-title">{title}</h1>
            {big || top ? <div className="admin-page-context">{big ? <span>{bottom}</span> : null}{top}</div> : null}
          </div>
          {controls ? <div className="admin-page-controls">{controls}</div> : null}
        </header>
        <div className="admin-body">{children}</div>
      </section>
    </div>
  )
}

export function AdminLayout({ children }: React.PropsWithChildren) {
  return <Layout footer={false}>{children}</Layout>
}
