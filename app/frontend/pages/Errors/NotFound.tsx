import { Head, Link, usePage } from '@inertiajs/react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import Layout from '@/components/Layout'
import { DAILY_LATEST, latestWeeklyHref } from '@/lib/paths'
import type { FooterData } from '@/types/lowpass'

// 404: one factual explanation and a working route back to reading.

export type NotFoundProps = FooterData

export default function NotFound() {
  return (
    <div className="issue-body" style={{ marginTop: 32 }}>
      <Head title="页面不存在" />
      <div className="source-state error-state">
        <div className="error-art"><Icon name="search" size={32} color="currentColor" /></div>
        <div className="error-copy">
          <h1 className="state-line">这一页不存在。</h1>
          <Link href={DAILY_LATEST} className="ctrl cjk" style={{ fontSize: 'var(--fs-15)' }}>
            回到首页
          </Link>
        </div>
      </div>
    </div>
  )
}

function NotFoundLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<NotFoundProps>().props

  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}

NotFound.layout = (page: React.ReactNode) => <NotFoundLayout>{page}</NotFoundLayout>
