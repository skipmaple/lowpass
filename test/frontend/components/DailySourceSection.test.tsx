import { act, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'

import DailySourceSection from '@/components/DailySourceSection'
import { source } from '../support/props'
import { emitRouterEvent } from '../support/inertia'

let top: number
let motionChanged: (event: { matches: boolean }) => void

beforeEach(() => {
  vi.useFakeTimers()
  window.history.replaceState({}, '', '/')
  top = 1200
  vi.stubGlobal('innerHeight', 1000)
  vi.spyOn(Element.prototype, 'getBoundingClientRect').mockImplementation(() => ({ top }) as DOMRect)
  vi.spyOn(HTMLElement.prototype, 'offsetHeight', 'get').mockReturnValue(1000)
  vi.stubGlobal('matchMedia', vi.fn(() => ({ matches: false, addEventListener: (_: string, callback: typeof motionChanged) => { motionChanged = callback }, removeEventListener: vi.fn() })))
})

afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); vi.useRealTimers() })

function section(animate = true) {
  const rendered = render(<DailySourceSection source={source()} animate={animate}><div className="issue-body"><article className="item-row">First story<button>Save</button></article></div></DailySourceSection>)
  act(() => { vi.advanceTimersToNextFrame(); vi.advanceTimersToNextFrame() })
  return { ...rendered, region: screen.getByRole('region', { name: 'Hacker News' }) }
}

function scroll(nextTop: number) {
  top = nextTop
  fireEvent.scroll(window)
  act(() => vi.advanceTimersToNextFrame())
}

function progress(region: HTMLElement) {
  return Number(region.style.getPropertyValue('--source-progress'))
}

it('来源在视口下方完成整体接入，进入主要阅读区后保持终态', () => {
  const { region } = section()
  expect(region).toHaveAttribute('data-scroll-source')
  expect(region).toHaveAttribute('data-source-opening')
  expect(progress(region)).toBe(0)
  scroll(950)
  expect(progress(region)).toBe(0)
  scroll(800)
  expect(progress(region)).toBeCloseTo(0.5)
  scroll(650)
  expect(progress(region)).toBe(1)
  expect(region).not.toHaveAttribute('data-source-opening')
  scroll(-100)
  expect(progress(region)).toBe(1)
})

it('停下滚动后进度保持原位，时间流逝不会自动完成', () => {
  const { region } = section()
  scroll(800)
  const stopped = progress(region)
  act(() => vi.advanceTimersByTime(2000))
  expect(progress(region)).toBe(stopped)
  expect(stopped).toBeCloseTo(0.5)
  scroll(750)
  expect(progress(region)).toBeGreaterThan(stopped)
})

it('上滑沿原路回退，回到同一滚动位置就得到同一进度', () => {
  const { region } = section()
  scroll(750)
  const forward = progress(region)
  scroll(850)
  expect(region).toHaveAttribute('data-source-opening')
  expect(progress(region)).toBeLessThan(forward)
  scroll(750)
  expect(progress(region)).toBe(forward)
  scroll(650)
  scroll(800)
  expect(progress(region)).toBeCloseTo(0.5)
})

it('首次显示和恢复阅读位置直接取当前进度，不从头播放', () => {
  top = 800
  const { region } = section()
  expect(progress(region)).toBeCloseTo(0.5)
  act(() => vi.advanceTimersByTime(2000))
  expect(progress(region)).toBeCloseTo(0.5)
  scroll(24)
  expect(progress(region)).toBe(1)
})

it('条目深链定位前不带入整栏位移，定位后仍可随滚动回退', () => {
  window.history.replaceState({}, '', '/#item-deep')
  const { container } = render(<DailySourceSection source={source()} animate><article id="item-deep">Deep story</article></DailySourceSection>)
  const region = container.querySelector('section')!
  expect(progress(region)).toBe(1)
  emitRouterEvent('navigate')
  act(() => vi.advanceTimersToNextFrame())
  expect(progress(region)).toBe(1)
  scroll(-200)
  expect(progress(region)).toBe(1)
  scroll(800)
  expect(progress(region)).toBeCloseTo(0.5)
})

it('带条目 hash 的历史恢复仍按保存位置显示过渡进度', () => {
  window.history.replaceState({ documentScrollPosition: { top: 500, left: 0 } }, '', '/#item-deep')
  top = 800
  const { container } = render(<DailySourceSection source={source()} animate><article id="item-deep">Deep story</article></DailySourceSection>)

  expect(progress(container.querySelector('section')!)).toBeCloseTo(0.5)
})

it('Inertia 恢复滚动位置的帧完成后同步进度，不依赖额外滚动事件', () => {
  const { region } = section()
  requestAnimationFrame(() => { top = 800 })
  emitRouterEvent('navigate')
  act(() => vi.advanceTimersToNextFrame())
  expect(progress(region)).toBeCloseTo(0.5)
})

it('聚焦操作不会越过当前滚动进度', () => {
  const { region } = section()
  scroll(800)
  act(() => screen.getByRole('button', { name: 'Save' }).focus())
  expect(progress(region)).toBeCloseTo(0.5)
})

it('首个来源保持静态，正文始终可读', () => {
  const { region } = section(false)
  scroll(800)
  expect(region).not.toHaveAttribute('data-scroll-source')
  expect(region).not.toHaveAttribute('data-source-opening')
  expect(region.style.getPropertyValue('--source-progress')).toBe('')
  expect(screen.getByText('First story')).toBeVisible()
})

it('不足一屏的短栏直接完整呈现，不裁掉正文和栏尾操作', () => {
  vi.spyOn(HTMLElement.prototype, 'offsetHeight', 'get').mockReturnValue(200)
  top = 800
  const { region } = section()
  expect(progress(region)).toBe(1)
  expect(region).not.toHaveAttribute('data-source-opening')
})

it('减少动态效果直接显示终态，关闭后按当前位置继续', () => {
  const { region } = section()
  scroll(800)
  act(() => motionChanged({ matches: true }))
  expect(region).not.toHaveAttribute('data-scroll-source')
  expect(region).not.toHaveAttribute('data-source-opening')
  expect(region.style.getPropertyValue('--source-progress')).toBe('')
  scroll(850)
  expect(region).not.toHaveAttribute('data-scroll-source')
  act(() => motionChanged({ matches: false }))
  expect(progress(region)).toBeGreaterThan(0)
  expect(progress(region)).toBeLessThan(0.5)
})

it('调整视口后按新高度计算进度，不保留旧触发区间', () => {
  const { region } = section()
  scroll(800)
  vi.stubGlobal('innerHeight', 600)
  fireEvent.resize(window)
  act(() => vi.advanceTimersToNextFrame())
  expect(progress(region)).toBe(0)
  scroll(480)
  expect(progress(region)).toBeCloseTo(0.5)
})

it('离开页面后取消排队的测量并清除进度样式', () => {
  const { region, unmount } = section()
  top = 800
  fireEvent.scroll(window)
  unmount()
  act(() => vi.runAllTimers())
  expect(region).not.toHaveAttribute('data-scroll-source')
  expect(region).not.toHaveAttribute('data-source-opening')
  expect(region.style.getPropertyValue('--source-progress')).toBe('')
})
