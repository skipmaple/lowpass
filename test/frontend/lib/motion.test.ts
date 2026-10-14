import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { markFirstLoad } from '@/lib/motion'
import { emitRouterEvent } from '../support/inertia'

// 开场（设计说明 2026-10-14 M5）：每个标签页会话第一次整页加载时播一次

function memoryStorage(): Storage {
  const map = new Map<string, string>()
  return {
    getItem: (key) => map.get(key) ?? null,
    setItem: (key, value) => void map.set(key, value),
    removeItem: (key) => void map.delete(key),
    clear: () => map.clear(),
    key: () => null,
    get length() { return map.size },
  }
}

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
  delete document.documentElement.dataset.firstLoad
})

describe('markFirstLoad', () => {
  it('会话里第一次打上标记，第二次不打', () => {
    const storage = memoryStorage()

    expect(markFirstLoad(storage)).toBe(true)
    expect(document.documentElement.dataset.firstLoad).toBe('')
    delete document.documentElement.dataset.firstLoad

    expect(markFirstLoad(storage)).toBe(false)
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  // 终审：页面组件是按需加载的分片，网慢时要好一会儿才挂上；800ms 从第一页挂上（Inertia 的首个 navigate）算起，
  // 不从脚本开始跑算起，不然动画还没播完标记就没了
  it('第一页挂上之后 800ms 摘掉标记；挂上之前不计时', () => {
    markFirstLoad(memoryStorage())

    vi.advanceTimersByTime(1500)
    expect(document.documentElement.dataset.firstLoad).toBe('')

    emitRouterEvent('navigate')
    vi.advanceTimersByTime(799)
    expect(document.documentElement.dataset.firstLoad).toBe('')
    vi.advanceTimersByTime(1)
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('迟迟没有挂上（加载出错）时，5 秒后也摘掉标记', () => {
    markFirstLoad(memoryStorage())

    vi.advanceTimersByTime(4999)
    expect(document.documentElement.dataset.firstLoad).toBe('')
    vi.advanceTimersByTime(1)
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('站内访问一开始就摘掉，新页面不接着播', () => {
    markFirstLoad(memoryStorage())

    emitRouterEvent('start')
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('减少动态效果时不播', () => {
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() }))

    expect(markFirstLoad(memoryStorage())).toBe(false)
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('sessionStorage 不可用（隐私模式抛错）时不播', () => {
    const broken = { ...memoryStorage(), getItem: () => { throw new Error('denied') } } as Storage

    expect(markFirstLoad(broken)).toBe(false)
    expect(markFirstLoad(null)).toBe(false)
  })
})
