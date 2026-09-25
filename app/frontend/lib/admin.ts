import { ADMIN_TEST_FETCH } from '@/lib/paths'
import type { TestFetchPayload, TestFetchResult } from '@/types/lowpass'

// 请求本身没走完时的两句（附录 B）：都要说下一步怎么办
export const TEST_FETCH_FAILED = '测试抓取没有完成，请稍后重试。'
export const NETWORK_FAILED = '网络连接失败，请检查网络后重试。'

// R-3.3 测试抓取：JSON 端点，表单不离开；CSRF 令牌从布局的 meta 读（与 lib/search.ts 一样）
export async function testFetch(payload: TestFetchPayload): Promise<TestFetchResult> {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
  let response: Response
  try {
    response = await fetch(ADMIN_TEST_FETCH, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': token },
      body: JSON.stringify(payload),
    })
  } catch {
    // 断网时 fetch 直接 reject，浏览器给的是「Failed to fetch」这种英文原句，不往界面上放
    throw new Error(NETWORK_FAILED)
  }
  if (response.status === 429) throw new Error('操作过于频繁，请稍后再试。')
  if (!response.ok) throw new Error(TEST_FETCH_FAILED)
  return (await response.json()) as TestFetchResult
}
