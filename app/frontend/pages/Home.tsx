import type * as React from 'react'

import Layout from '@/components/Layout'

// 占位：Task 17 用日刊页替换这里的内容，报头与页脚保持不动。
// 不在这里包 <Layout>——application.tsx 的 createInertiaApp({ layout }) 已经给每个页面
// 套了持久布局，这里只用 Home.layout 覆盖 masthead 的 active 高亮。
function Home() {
  return (
    <p className="cjk" style={{ padding: '32px 0', color: 'var(--ink2)', fontSize: 'var(--fs-15)' }}>
      占位页，Task 17 替换
    </p>
  )
}

Home.layout = (page: React.ReactNode) => <Layout masthead={{ active: 'daily' }}>{page}</Layout>

export default Home
