import { Head, Link, usePage } from '@inertiajs/react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import Layout from '@/components/Layout'
import { DAILY_LATEST, latestWeeklyHref } from '@/lib/paths'
import type { FooterData } from '@/types/lowpass'

// 403: state the permission boundary and offer a safe return to reading.

export type ForbiddenProps = FooterData

export default function Forbidden() {
  return (
    <div className="issue-body" style={{ marginTop: 32 }}>
      <Head title="无权访问" />
      <div className="source-state error-state">
        <div className="error-art"><Icon name="triangle-alert" size={32} color="currentColor" /></div>
        <div className="error-copy">
          <h1 className="state-line">你没有权限访问这个页面。</h1>
          <Link href={DAILY_LATEST} className="ctrl cjk" style={{ fontSize: 'var(--fs-15)' }}>
            回到首页
          </Link>
        </div>
      </div>
    </div>
  )
}

function ForbiddenLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<ForbiddenProps>().props

  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}

Forbidden.layout = (page: React.ReactNode) => <ForbiddenLayout>{page}</ForbiddenLayout>
