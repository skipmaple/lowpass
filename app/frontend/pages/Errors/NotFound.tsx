import { Head, Link, usePage } from '@inertiajs/react'
import type * as React from 'react'

import { MissingPage } from '@/components/Illustration'
import Layout from '@/components/Layout'
import { DAILY_LATEST, latestWeeklyHref } from '@/lib/paths'
import type { FooterData } from '@/types/lowpass'

// 404（附录 B「这一页不存在。回到首页」）。空态只有一句原因加一个动作（PRD 6.3），
// 不放大字号码、不写安抚句：版面就是列表区那条 1px 墨线加文楷 20 的事实句，
// 与栏级状态（SourceState）同一套装置。左边 1px 框里一幅木刻「缺页」（设计说明 2026-10-14 C2）。

export type NotFoundProps = FooterData

export default function NotFound() {
  return (
    <div className="issue-body" style={{ marginTop: 32 }}>
      <Head title="页面不存在" />
      <div className="source-state error-state">
        <div className="error-art"><MissingPage /></div>
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
