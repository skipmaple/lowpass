import { ADMIN_TEST_FETCH } from '@/lib/paths'
import type { TestFetchPayload, TestFetchResult } from '@/types/lowpass'

// R-3.3 测试抓取：JSON 端点，表单不离开；CSRF 令牌从布局的 meta 读（与 lib/search.ts 一样）
export async function testFetch(payload: TestFetchPayload): Promise<TestFetchResult> {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
  const response = await fetch(ADMIN_TEST_FETCH, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': token },
    body: JSON.stringify(payload),
  })
  if (response.status === 429) throw new Error('操作过于频繁，请稍后再试。')
  if (!response.ok) throw new Error('请求失败')
  return (await response.json()) as TestFetchResult
}
