import Layout from '@/components/Layout'

// 占位：Task 17 用日刊页替换这里的内容，报头与页脚保持不动。
export default function Home() {
  return (
    <Layout masthead={{ active: 'daily' }}>
      <p className="cjk" style={{ padding: '32px 0', color: 'var(--ink2)', fontSize: 'var(--fs-15)' }}>
        占位页，Task 17 替换
      </p>
    </Layout>
  )
}
