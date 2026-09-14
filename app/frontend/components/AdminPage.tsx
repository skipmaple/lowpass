import { usePage } from '@inertiajs/react'
import type * as React from 'react'

import AdminNav, { type AdminSection } from '@/components/AdminNav'
import Layout from '@/components/Layout'
import PageHead from '@/components/PageHead'
import { Toasts, type ToastItem } from '@/components/Toast'
import type { SharedProps } from '@/types/lowpass'

// 后台页的骨架（画布 admin_*()）：期头「管理后台」+ Maple「admin」+ 分页名 + 右端按钮，然后是四格索引条。
// flash 的提示画在期头上方；页面自己推的提示（重抓结束、测试抓取）也从这里进。后台页不要页脚（设计 A8）。
export type AdminPageProps = React.PropsWithChildren<{
  section: AdminSection
  big?: string
  top?: React.ReactNode
  bottom: string
  controls?: React.ReactNode
  toasts?: ToastItem[]
  onDismissToast?: (id: string) => void
}>

export default function AdminPage({ section, big = '管理后台', top, bottom, controls, toasts, onDismissToast, children }: AdminPageProps) {
  const { flash } = usePage<SharedProps>().props

  return (
    <>
      <Toasts flash={flash} items={toasts} onDismiss={onDismissToast} />
      <PageHead big={big} top={top ?? <span className="data">admin</span>} bottom={bottom} controls={controls} />
      <AdminNav active={section} />
      <div className="admin-body">{children}</div>
    </>
  )
}

export function AdminLayout({ children }: React.PropsWithChildren) {
  return <Layout footer={false}>{children}</Layout>
}
