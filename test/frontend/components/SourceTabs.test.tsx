import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it, vi } from 'vitest'

import SourceTabs from '@/components/SourceTabs'
import type { SourceSummary } from '@/types/lowpass'
import { source } from '../support/props'

// 来源索引条（PRD 6.2）：一次只显示一个来源，栏级状态标在名字下面。
// 切换是本地状态，条目已经全在 props 里，不回服务端。

const sources: SourceSummary[] = [
  source(),
  source({ id: 'src-gh', name: 'GitHub Trending', adapter: 'github_trending', state: 'failed' }),
  source({ id: 'src-had', name: 'Hackaday', adapter: 'rss', state: 'empty' }),
]

function renderTabs(activeId = 'src-hn', onSelect: (id: string) => void = vi.fn()) {
  return render(
    <SourceTabs sources={sources} activeId={activeId} onSelect={onSelect}>
      {(current) => <div>面板 {current.name}</div>}
    </SourceTabs>,
  )
}

// 切换要看到面板真的换了：把 activeId 交给一个有状态的外壳，跟 Daily/Show 的 Sources 一样
function Harness({ onSelect }: { onSelect: (id: string) => void }) {
  const [activeId, setActiveId] = useState('src-hn')

  return (
    <SourceTabs
      sources={sources}
      activeId={activeId}
      onSelect={(id) => {
        onSelect(id)
        setActiveId(id)
      }}
    >
      {(current) => <div>面板 {current.name}</div>}
    </SourceTabs>
  )
}

describe('SourceTabs', () => {
  it('一个源一条索引，带源名', () => {
    renderTabs()

    const tabs = screen.getAllByRole('tab')
    expect(tabs).toHaveLength(3)
    expect(within(tabs[0]).getByText('Hacker News')).toBeInTheDocument()
    expect(within(tabs[1]).getByText('GitHub Trending')).toBeInTheDocument()
    expect(within(tabs[2]).getByText('Hackaday')).toBeInTheDocument()
    expect(screen.getByRole('tablist')).toHaveAccessibleName('来源')
  })

  it('当前源反白，其余不是', () => {
    renderTabs()

    const tabs = screen.getAllByRole('tab')
    expect(tabs[0]).toHaveAttribute('aria-selected', 'true')
    expect(tabs[1]).toHaveAttribute('aria-selected', 'false')
    expect(tabs[2]).toHaveAttribute('aria-selected', 'false')
  })

  // 深链 ?source= 与服务端记住的来源都是这条：种子来自 props，不是永远第一个
  it('当前源认传进来的那个，不是第一个', () => {
    renderTabs('src-gh')

    const tabs = screen.getAllByRole('tab')
    expect(tabs[0]).toHaveAttribute('aria-selected', 'false')
    expect(tabs[1]).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tabpanel')).toHaveTextContent('面板 GitHub Trending')
  })

  it('抓取失败与今日无新内容标在名字下面，正常的源不标', () => {
    renderTabs()

    const tabs = screen.getAllByRole('tab')
    expect(within(tabs[1]).getByText('抓取失败')).toBeInTheDocument()
    expect(within(tabs[2]).getByText('今日无新内容')).toBeInTheDocument()
    expect(tabs[0]).toHaveTextContent('Hacker News')
    expect(within(tabs[0]).queryByText('抓取失败')).toBeNull()
    expect(within(tabs[0]).queryByText('今日无新内容')).toBeNull()
  })

  it('生成中的源在索引条上不说话（期头的标签已经写着）', () => {
    render(
      <SourceTabs sources={[source({ state: 'pending' })]} activeId="src-hn" onSelect={vi.fn()}>
        {(current) => <div>面板 {current.name}</div>}
      </SourceTabs>,
    )

    expect(screen.getByRole('tab')).toHaveTextContent('Hacker News')
  })

  it('只渲染当前源的面板', () => {
    renderTabs()

    expect(screen.getAllByRole('tabpanel')).toHaveLength(1)
    expect(screen.getByRole('tabpanel')).toHaveTextContent('面板 Hacker News')
    expect(screen.queryByText('面板 Hackaday')).toBeNull()
  })

  it('点另一条索引把源的 id 交出去', async () => {
    const user = userEvent.setup()
    const onSelect = vi.fn()
    renderTabs('src-hn', onSelect)

    await user.click(screen.getAllByRole('tab')[2])

    expect(onSelect).toHaveBeenCalledWith('src-had')
  })

  it('点一下换掉面板', async () => {
    const user = userEvent.setup()
    render(<Harness onSelect={vi.fn()} />)

    await user.click(screen.getAllByRole('tab')[1])

    expect(screen.getByRole('tabpanel')).toHaveTextContent('面板 GitHub Trending')
    expect(screen.queryByText('面板 Hacker News')).toBeNull()
  })

  // PRD 6.4：索引条能用键盘走。Radix 的 roving tabindex 把方向键接在整条索引上
  it('方向键往下一个源走', async () => {
    const user = userEvent.setup()
    const onSelect = vi.fn()
    render(<Harness onSelect={onSelect} />)

    screen.getAllByRole('tab')[0].focus()
    await user.keyboard('{ArrowRight}')

    expect(onSelect).toHaveBeenLastCalledWith('src-gh')
    expect(screen.getByRole('tabpanel')).toHaveTextContent('面板 GitHub Trending')

    await user.keyboard('{ArrowRight}')

    expect(onSelect).toHaveBeenLastCalledWith('src-had')
    expect(screen.getByRole('tabpanel')).toHaveTextContent('面板 Hackaday')
  })
})
