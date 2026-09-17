import { Head, Link, usePage } from '@inertiajs/react'
import type * as React from 'react'

import Layout from '@/components/Layout'
import { DAILY_LATEST, latestWeeklyHref } from '@/lib/paths'
import type { FooterData } from '@/types/lowpass'

// 403（附录 B「你没有权限访问这个页面。」，AC-3.5）：与 404 页同一装置（设计 L3）——
// 1px 墨线加文楷 20 的事实句，一个动作；不放大字号码、不写安抚句。

export type ForbiddenProps = FooterData

export default function Forbidden() {
  return (
    <div className="issue-body" style={{ marginTop: 32 }}>
      <Head title="无权访问" />
      <div className="source-state" style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 12 }}>
        <h1 className="state-line">你没有权限访问这个页面。</h1>
        <Link href={DAILY_LATEST} className="ctrl cjk" style={{ fontSize: 'var(--fs-15)' }}>
          回到首页
        </Link>
      </div>
    </div>
  )
}

function ForbiddenLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<ForbiddenProps>().props

  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}

Forbidden.layout = (page: React.ReactNode) => <ForbiddenLayout>{page}</ForbiddenLayout>
