import { afterEach, describe, expect, it, vi } from 'vitest'

import { markSearchResult, searchResultTarget } from '@/lib/searchFocus'

const itemId = '000000000000000000000000d'

// 捕捉身份与原生历史的边界；真实 Back 的滚动与后续 Tab 另由系统浏览器测试覆盖。
afterEach(() => {
  vi.restoreAllMocks()
  window.history.replaceState({}, '', '/')
})

describe('搜索结果原生片段', () => {
  it('标记当前 entry，原样保留 query、opaque state 和历史长度，不触发滚动或 hashchange', () => {
    const state = { page: new Uint8Array([1, 2, 3]).buffer, documentScrollPosition: { top: 3266.5, left: 0 }, other: { keep: true } }
    window.history.replaceState(state, '', '/search?q=rust&type=weekly&page=2')
    const opaqueState = window.history.state
    const length = window.history.length
    const replace = vi.spyOn(window.history, 'replaceState')
    const scroll = vi.spyOn(window, 'scrollTo')
    const hashchange = vi.fn()
    window.addEventListener('hashchange', hashchange)

    markSearchResult(itemId)

    expect(window.location.pathname + window.location.search + window.location.hash).toBe('/search?q=rust&type=weekly&page=2#search-result-000000000000000000000000d')
    expect(window.history.length).toBe(length)
    expect(replace.mock.calls[0][0]).toBe(opaqueState)
    expect(window.history.state).toEqual(state)
    expect(scroll).not.toHaveBeenCalled()
    expect(hashchange).not.toHaveBeenCalled()
    expect(searchResultTarget()).toBe('search-result-000000000000000000000000d')
    window.removeEventListener('hashchange', hashchange)
  })

  it.each(['/daily/2026-09-08', '/searching?q=rust', '/search/'])('不标记非 Search 页面 %s', (url) => {
    window.history.replaceState({}, '', url)
    markSearchResult(itemId)

    expect(window.location.pathname + window.location.search).toBe(url)
    expect(window.location.hash).toBe('')
    expect(searchResultTarget()).toBeNull()
  })

  it.each([
    '',
    '#other-000000000000000000000000d',
    '#search-result-00000000000000000000000d',
    '#search-result-0000000000000000000000000d',
    '#search-result-000000000000000000000000D',
    '#search-result-%3000000000000000000000000d',
  ])('忽略不是严格 25 位小写 base36 身份的片段 %s', (hash) => {
    window.history.replaceState({}, '', `/search?q=rust${hash}`)

    expect(searchResultTarget()).toBeNull()
  })

  it('条目 id 无效时不修改当前地址', () => {
    window.history.replaceState({}, '', '/search?q=rust#keep')
    markSearchResult('invalid-id')

    expect(window.location.hash).toBe('#keep')
  })

  it('浏览器拒绝替换历史时不抛异常，让所在期访问继续', () => {
    window.history.replaceState({}, '', '/search?q=rust')
    vi.spyOn(window.history, 'replaceState').mockImplementation(() => { throw new DOMException('History unavailable', 'SecurityError') })

    expect(() => markSearchResult(itemId)).not.toThrow()
    expect(window.location.hash).toBe('')
  })
})
