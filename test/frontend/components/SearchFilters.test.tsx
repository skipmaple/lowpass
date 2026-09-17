import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import SearchFilters, { hrefWith } from '@/components/SearchFilters'
import type { SearchFilters as Filters } from '@/types/lowpass'
import { router } from '../support/inertia'
import { searchFilters } from '../support/props'

// 筛选栏（R-4.4、AC-4.7）：每个控件都落到一条地址，页码归 1

const sourceOptions = [
  { id: 'src-hn', name: 'Hacker News', enabled: true },
  { id: 'src-ruanyf', name: '阮一峰科技爱好者周刊', enabled: false },
]
const datePresets = { '7d': { from: '2026-09-05', to: '2026-09-11' }, '30d': { from: '2026-08-13', to: '2026-09-11' } }

function filters(overrides: Partial<Filters> = {}) {
  return render(<SearchFilters q="kuber" filters={searchFilters(overrides)} sourceOptions={sourceOptions} datePresets={datePresets} />)
}

afterEach(() => {
  router.get.mockClear()
  vi.unstubAllGlobals()
})

function mobileViewport() {
  vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() }))
}

describe('手机版筛选', () => {
  it('收起高级筛选并在摘要中说明生效条件，展开前控件不可访问', async () => {
    mobileViewport()
    const user = userEvent.setup()
    filters({ type: 'daily', sources: ['src-hn'], range: '7d', from: '2026-09-05', to: '2026-09-11' })

    // Mixed 按字体角色拆开中英文与数字，jsdom 可能吃掉 run 边界空格；可见文本仍保留原串。
    const toggle = screen.getByRole('button', { name: /筛选：日刊\s*·\s*Hacker News\s*·\s*近\s*7\s*天/ })
    expect(toggle).toHaveAttribute('aria-expanded', 'false')
    expect(screen.queryByRole('navigation', { name: '刊物' })).toBeNull()

    await user.click(toggle)
    expect(toggle).toHaveAttribute('aria-expanded', 'true')
    expect(screen.getByRole('navigation', { name: '刊物' })).toBeInTheDocument()
  })

  it('焦点在筛选项内时收起会回到展开按钮', async () => {
    mobileViewport()
    const user = userEvent.setup()
    filters()
    const toggle = screen.getByRole('button', { name: '筛选：全部' })

    await user.click(toggle)
    const source = screen.getByRole('button', { name: 'Hacker News' })
    source.focus()
    await user.click(toggle)

    expect(toggle).toHaveFocus()
    expect(screen.queryByRole('button', { name: 'Hacker News' })).toBeNull()
  })
})

describe('刊物', () => {
  it('三段各自一条地址，当前项 aria-current', () => {
    filters({ type: 'daily' })
    const seg = within(screen.getByRole('navigation', { name: '刊物' }))

    expect(seg.getByRole('link', { name: '全部' })).toHaveAttribute('href', '/search?q=kuber')
    expect(seg.getByRole('link', { name: '日刊' })).toHaveAttribute('aria-current', 'true')
    expect(seg.getByRole('link', { name: '周刊' })).toHaveAttribute('href', '/search?q=kuber&type=weekly')
  })
})

describe('来源', () => {
  it('小签列出所有源含停用的；点一下加进筛选，再点一下去掉', async () => {
    const user = userEvent.setup()
    const { unmount } = filters()

    const chip = screen.getByRole('button', { name: 'Hacker News' })
    expect(chip).toHaveAttribute('aria-pressed', 'false')
    expect(screen.getByRole('button', { name: '阮一峰科技爱好者周刊' })).toBeInTheDocument()
    await user.click(chip)
    expect(router.get).toHaveBeenCalledWith('/search?q=kuber&source=src-hn', {}, { preserveState: true })
    unmount()

    filters({ sources: ['src-hn', 'src-ruanyf'] })
    expect(screen.getByRole('button', { name: 'Hacker News' })).toHaveAttribute('aria-pressed', 'true')
    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&source=src-ruanyf', {}, { preserveState: true })
  })
})

describe('日期', () => {
  it('预设带上服务端算好的首尾；全部清掉日期；自定义显示两个日期框', () => {
    filters({ range: 'custom', from: '2026-08-01', to: null })
    const seg = within(screen.getByRole('navigation', { name: '日期' }))

    // 「近 7 天」经 Mixed 按字符段拆成「近」/「7」/「天」三个相邻 <span>，jsdom 的可访问名计算
    // 会把落在段边界上的空格吃掉（近7天），可见渲染与 textContent 都不受影响；用正则容忍空格差异。
    expect(seg.getByRole('link', { name: /^近\s*7\s*天$/ })).toHaveAttribute('href', '/search?q=kuber&from=2026-09-05&to=2026-09-11&range=7d')
    expect(seg.getByRole('link', { name: /^近\s*30\s*天$/ })).toHaveAttribute('href', '/search?q=kuber&from=2026-08-13&to=2026-09-11&range=30d')
    expect(seg.getByRole('link', { name: '全部' })).toHaveAttribute('href', '/search?q=kuber')
    expect(seg.getByRole('link', { name: '自定义' })).toHaveAttribute('aria-current', 'true')
    expect(screen.getByLabelText('起始日期')).toHaveValue('2026-08-01')
    expect(screen.getByLabelText('结束日期')).toHaveValue('')
  })

  it('不是自定义时没有日期框', () => {
    filters({ range: '7d', from: '2026-09-05', to: '2026-09-11' })

    expect(screen.queryByLabelText('起始日期')).toBeNull()
  })

  it('改日期框发一次访问', () => {
    filters({ range: 'custom', from: '2026-08-01', to: null })

    fireEvent.change(screen.getByLabelText('结束日期'), { target: { value: '2026-09-08' } })

    expect(router.get).toHaveBeenCalledWith('/search?q=kuber&from=2026-08-01&to=2026-09-08&range=custom', {}, { preserveState: true })
  })

  // Inertia 前进后退不重挂页面：日期框必须跟着 props 走，不能停在读者上一次输入的值
  it('日期框随 props 更新', () => {
    const { rerender } = render(
      <SearchFilters q="kuber" filters={searchFilters({ range: 'custom', from: '2026-08-01', to: null })} sourceOptions={sourceOptions} datePresets={datePresets} />,
    )
    expect(screen.getByLabelText('起始日期')).toHaveValue('2026-08-01')

    rerender(
      <SearchFilters q="kuber" filters={searchFilters({ range: 'custom', from: '2026-09-01', to: null })} sourceOptions={sourceOptions} datePresets={datePresets} />,
    )

    expect(screen.getByLabelText('起始日期')).toHaveValue('2026-09-01')
  })
})

describe('hrefWith', () => {
  it('换掉几项，其余照旧，sort 保留', () => {
    expect(hrefWith('kuber', searchFilters({ sort: 'date', sources: ['src-hn'] }), { type: 'weekly' })).toBe('/search?q=kuber&type=weekly&source=src-hn&sort=date')
  })
})
