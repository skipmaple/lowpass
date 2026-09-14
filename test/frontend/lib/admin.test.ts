import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { testFetch } from '@/lib/admin'

describe('testFetch', () => {
  beforeEach(() => {
    document.head.innerHTML = '<meta name="csrf-token" content="tok-1">'
  })
  afterEach(() => {
    vi.unstubAllGlobals()
    document.head.innerHTML = ''
  })

  it('POST JSON 带 CSRF 令牌，回解析后的结果', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ ok: true, entries: [], warnings: [], parsed: 3, dropped: 0, duration_ms: 12, feed_title: null, error: null }) })
    vi.stubGlobal('fetch', fetchMock)

    const result = await testFetch({ adapter: 'rss', publication: 'daily', name: 'x', config: { feed_url: 'https://a/b' } })

    expect(result.parsed).toBe(3)
    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe('/admin/test_fetches')
    expect(init.method).toBe('POST')
    expect(init.headers['X-CSRF-Token']).toBe('tok-1')
    expect(JSON.parse(init.body).adapter).toBe('rss')
  })

  it('429 抛「操作过于频繁，请稍后再试。」，其他非 2xx 抛「请求失败」', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 429 }))
    await expect(testFetch({ adapter: 'rss', publication: 'daily', name: '', config: {} })).rejects.toThrow('操作过于频繁，请稍后再试。')

    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }))
    await expect(testFetch({ adapter: 'rss', publication: 'daily', name: '', config: {} })).rejects.toThrow('请求失败')
  })
})
