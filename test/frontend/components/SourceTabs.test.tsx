import { act, fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import SourceTabs from '@/components/SourceTabs'
import { source } from '../support/props'

const sources = [source(), source({ id: 'src-gh', name: 'GitHub Trending', state: 'failed' }), source({ id: 'src-had', name: 'Hackaday', state: 'empty' })]

function Harness({ initial = 'src-hn', onSelect = vi.fn() }: { initial?: string; onSelect?: (id: string) => void }) {
  const [activeId, setActiveId] = useState(initial)
  return <SourceTabs sources={sources} activeId={activeId} onSelect={(id) => { setActiveId(id); onSelect(id) }}>{(current) => <p>内容 {current.name}</p>}</SourceTabs>
}

function links() { return within(screen.getByRole('navigation', { name: '本期来源' })).getAllByRole('link') }

beforeEach(() => window.history.replaceState({}, '', '/'))
afterEach(() => vi.restoreAllMocks())

describe('连续来源导航', () => {
  it('每个链接有可达的命名章节，所有内容按来源顺序同时存在', () => {
    render(<Harness />)
    expect(links()).toHaveLength(3)
    expect(links().map((link) => link.getAttribute('href'))).toEqual(['#source-src-hn', '#source-src-gh', '#source-src-had'])
    expect(screen.getAllByRole('region').map((section) => section.id)).toEqual(['source-src-hn', 'source-src-gh', 'source-src-had'])
    expect(screen.getByText('内容 Hacker News')).toBeInTheDocument()
    expect(screen.getByText('内容 GitHub Trending')).toBeInTheDocument()
    expect(screen.getByText('内容 Hackaday')).toBeInTheDocument()
  })

  it('深链传入来源决定初始标记', () => {
    render(<Harness initial="src-gh" />)
    expect(links()[1]).toHaveAttribute('aria-current', 'location')
    expect(links()[0]).not.toHaveAttribute('aria-current')
    expect(links()[1]).toHaveAttribute('data-state', 'active')
    expect(links()[0]).toHaveAttribute('data-state', 'inactive')
  })

  it('失败和未收录各有明确说明，不把空来源禁用', () => {
    render(<Harness />)
    expect(links()[1]).toHaveTextContent('抓取失败')
    expect(links()[2]).toHaveTextContent('本期未收录')
    expect(links()[2]).not.toHaveAttribute('aria-disabled')
  })

  it('点击更新当前来源，保留原生锚点跳转和其他章节', async () => {
    const onSelect = vi.fn()
    const scroll = vi.fn()
    Element.prototype.scrollIntoView = scroll
    render(<Harness onSelect={onSelect} />)
    await userEvent.click(links()[2])
    expect(onSelect).toHaveBeenLastCalledWith('src-had')
    expect(links()[2]).toHaveAttribute('aria-current', 'location')
    expect(links()[2]).toHaveAttribute('href', '#source-src-had')
    expect(scroll).not.toHaveBeenCalled()
    expect(screen.getByText('内容 Hacker News')).toBeInTheDocument()
  })

  it('页尾主动选择不被程序滚动覆盖，继续手动滚动才恢复跟踪', async () => {
    const frames: FrameRequestCallback[] = []
    vi.spyOn(window, 'requestAnimationFrame').mockImplementation((callback) => { frames.push(callback); return frames.length })
    Element.prototype.scrollIntoView = vi.fn()
    render(<Harness />)
    const sections = screen.getAllByRole('region')
    sections.forEach((section, index) => vi.spyOn(section, 'getBoundingClientRect').mockReturnValue({ top: index * 400, bottom: index * 400 + 100 } as DOMRect))

    fireEvent.click(links()[1])
    fireEvent.scroll(window)
    act(() => { frames.splice(0).forEach((callback) => callback(0)) })
    expect(links()[1]).toHaveAttribute('aria-current', 'location')

    fireEvent.wheel(window)
    act(() => { frames.splice(0).forEach((callback) => callback(0)) })
    expect(links()[0]).toHaveAttribute('aria-current', 'location')
  })

  it('所有来源都是原生可聚焦链接，Enter 可操作', async () => {
    const onSelect = vi.fn()
    const user = userEvent.setup()
    render(<Harness onSelect={onSelect} />)
    links()[1].focus()
    await user.keyboard('{Enter}')
    expect(onSelect).toHaveBeenCalledWith('src-gh')
  })

  it('修饰键点击保留原生链接行为', () => {
    const onSelect = vi.fn()
    render(<Harness onSelect={onSelect} />)
    fireEvent.click(links()[2], { metaKey: true })
    expect(onSelect).not.toHaveBeenCalled()
  })

  it('hash 改变同步来源标记，不触发服务端或历史页更新', () => {
    const onSelect = vi.fn()
    render(<Harness onSelect={onSelect} />)
    window.history.replaceState(null, '', '#source-src-gh')
    fireEvent(window, new HashChangeEvent('hashchange'))
    expect(links()[1]).toHaveAttribute('aria-current', 'location')
    expect(onSelect).not.toHaveBeenCalled()
    window.history.replaceState(null, '', '/')
  })
})
