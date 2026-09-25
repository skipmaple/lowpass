import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { focusMain, focusMainOnNavigate } from '@/lib/navigationFocus'
import { emitRouterEvent } from '../support/inertia'

// 换页后焦点落到新页的一级标题（PRD 6.4）：不然按下的链接随旧页卸载，焦点掉到 body，读屏也不播报

function navigate(url: string) {
  window.history.replaceState({}, '', url)
  emitRouterEvent('navigate', new CustomEvent('navigate', { detail: { page: { url } } }))
}

let stop: () => void

beforeEach(() => {
  vi.spyOn(window, 'requestAnimationFrame').mockImplementation((callback) => { callback(0); return 0 })
  window.history.replaceState({}, '', '/daily/2026-09-24')
  document.body.innerHTML = '<a href="/daily/2026-09-23">前一期</a><main id="main-content" tabindex="-1"><h1>9月23日</h1><li id="item-1">条目</li></main>'
  stop = focusMainOnNavigate()
})

afterEach(() => {
  stop()
  vi.restoreAllMocks()
  document.body.innerHTML = ''
})

describe('focusMainOnNavigate', () => {
  it('换到另一个路径：焦点落到新页的 h1', () => {
    navigate('/daily/2026-09-23')

    const heading = document.querySelector('h1')!
    expect(document.activeElement).toBe(heading)
    expect(heading).toHaveAttribute('tabindex', '-1')
  })

  it('带锚点：焦点落到锚点', () => {
    navigate('/daily/2026-09-23#item-1')

    expect(document.activeElement).toBe(document.getElementById('item-1'))
  })

  // 筛选、翻页码、切来源都在同一路径里：读者还在原来的位置上，不动焦点
  it('同一路径内的访问不动焦点', () => {
    const link = document.querySelector('a')!
    link.focus()

    navigate('/daily/2026-09-24?source=src-gh')

    expect(document.activeElement).toBe(link)
  })
})

describe('focusMain', () => {
  it('没有 h1 时落到正文', () => {
    document.querySelector('h1')!.remove()

    focusMain()

    expect(document.activeElement).toBe(document.getElementById('main-content'))
  })
})
