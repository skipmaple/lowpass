import { act, fireEvent, render, screen, within } from '@testing-library/react'
import type { ActiveVisit, Page, VisitOptions } from '@inertiajs/core'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import SearchFilters, { hrefWith, useFilterDraft } from '@/components/SearchFilters'
import type { SearchFiltersProps } from '@/components/SearchFilters'
import type { SearchFilters as Filters } from '@/types/lowpass'
import { router, visitRouterEvent } from '../support/inertia'
import { searchFilters } from '../support/props'

// 筛选栏（R-4.4、AC-4.7）：每个控件都落到一条地址，页码归 1

const sourceOptions = [
  { id: 'src-hn', name: 'Hacker News', enabled: true },
  { id: 'src-ruanyf', name: '阮一峰科技爱好者周刊', enabled: false },
]
const datePresets = { '7d': { from: '2026-09-05', to: '2026-09-11' }, '30d': { from: '2026-08-13', to: '2026-09-11' } }

// 跟页面一样只创建一份真实 controller，不在测试里复制目标合并或确认逻辑。
function FilterHarness({ q, filters, ...props }: Omit<SearchFiltersProps, 'draft'> & { filters: Filters }) {
  const draft = useFilterDraft(q, filters)
  return <SearchFilters q={q} draft={draft} {...props} />
}

function filters(overrides: Partial<Filters> = {}) {
  return render(<FilterHarness q="kuber" filters={searchFilters(overrides)} sourceOptions={sourceOptions} datePresets={datePresets} />)
}

function visit(index = router.get.mock.calls.length - 1): VisitOptions {
  return router.get.mock.calls[index][2] ?? {}
}

function response(filters: Filters): Page<{ filters: Filters }> {
  return { component: 'Search/Show', props: { filters, errors: {} }, url: window.location.pathname + window.location.search, version: null, flash: {}, rescuedProps: [], rememberedState: {} }
}

afterEach(() => {
  router.get.mockClear()
  vi.unstubAllGlobals()
  vi.useRealTimers()
  window.history.replaceState({}, '', '/')
})

function mobileViewport() {
  vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() }))
}

function responsiveViewport(matches: boolean) {
  const media = Object.assign(new EventTarget(), { matches })
  vi.stubGlobal('matchMedia', () => media)
  return {
    media,
    resize(matches: boolean) {
      act(() => {
        media.matches = matches
        media.dispatchEvent(Object.assign(new Event('change'), { matches }))
      })
    },
  }
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

describe('筛选跨屏宽焦点', () => {
  it.each(['来源', '起始日期'])('桌面%s收起时把焦点交给新出现的展开按钮', (field) => {
    const viewport = responsiveViewport(false)
    filters({ range: 'custom', from: '2026-08-01' })
    const control = field === '来源' ? screen.getByRole('button', { name: 'Hacker News' }) : screen.getByLabelText('起始日期')
    control.focus()

    viewport.resize(true)

    expect(screen.getByRole('button', { name: '筛选：自定义日期' })).toHaveFocus()
    expect(screen.queryByRole('button', { name: 'Hacker News' })).toBeNull()
  })

  it('手机展开按钮在桌面消失时把焦点交给第一个筛选控件', () => {
    const viewport = responsiveViewport(true)
    filters()
    screen.getByRole('button', { name: '筛选：全部' }).focus()

    viewport.resize(false)

    expect(within(screen.getByRole('navigation', { name: '刊物' })).getByRole('link', { name: '全部' })).toHaveFocus()
    expect(screen.queryByRole('button', { name: '筛选：全部' })).toBeNull()
  })

  it('已展开时往返保持原控件、日期草稿与查询，不重置展开状态', async () => {
    const viewport = responsiveViewport(true)
    const user = userEvent.setup()
    filters({ range: 'custom', from: '2026-08-01' })
    await user.click(screen.getByRole('button', { name: '筛选：自定义日期' }))
    const from = screen.getByLabelText('起始日期')
    from.focus()
    fireEvent.change(from, { target: { value: '0202-08-01' } })

    for (let turn = 0; turn < 2; turn++) {
      viewport.resize(false)
      expect(from).toHaveFocus()
      viewport.resize(true)
      expect(from).toHaveFocus()
      expect(screen.getByRole('button', { name: '筛选：自定义日期' })).toHaveAttribute('aria-expanded', 'true')
    }

    expect(screen.getByLabelText('起始日期')).toBe(from)
    expect(from).toHaveValue('0202-08-01')
    expect(within(screen.getByRole('navigation', { name: '刊物' })).getByRole('link', { name: '日刊' })).toHaveAttribute('href', '/search?q=kuber&type=daily&from=2026-08-01&range=custom')
    expect(router.get).not.toHaveBeenCalled()
  })

  it('反复往返不抢区外控件的焦点', () => {
    const viewport = responsiveViewport(false)
    render(<><button>其他操作</button><FilterHarness q="kuber" filters={searchFilters()} sourceOptions={sourceOptions} datePresets={datePresets} /></>)
    const outside = screen.getByRole('button', { name: '其他操作' })
    outside.focus()

    for (const mobile of [true, false, true, false]) {
      viewport.resize(mobile)
      expect(outside).toHaveFocus()
    }
  })

  it('断点变化后读者新聚焦区外时不再恢复旧位置', () => {
    const { media } = responsiveViewport(false)
    render(<><button>其他操作</button><FilterHarness q="kuber" filters={searchFilters()} sourceOptions={sourceOptions} datePresets={datePresets} /></>)
    screen.getByRole('button', { name: 'Hacker News' }).focus()
    const outside = screen.getByRole('button', { name: '其他操作' })

    act(() => {
      media.matches = true
      media.dispatchEvent(Object.assign(new Event('change'), { matches: true }))
      outside.focus()
    })

    expect(outside).toHaveFocus()
  })

  it('卸载时移除自己的媒体监听，不积累下一次挂载的响应', () => {
    const viewport = responsiveViewport(false)
    const add = vi.spyOn(viewport.media, 'addEventListener')
    const remove = vi.spyOn(viewport.media, 'removeEventListener')
    const first = filters()
    const firstListener = add.mock.calls[0][1]
    first.unmount()
    expect(remove).toHaveBeenCalledWith('change', firstListener)

    filters()
    expect(add).toHaveBeenCalledTimes(2)
    viewport.resize(true)
    expect(screen.getByRole('button', { name: '筛选：全部' })).toBeInTheDocument()
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
  it('前一次访问未返回时连选两个来源仍保留两者，再次点击可取消', async () => {
    const user = userEvent.setup()
    filters()

    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    await user.click(screen.getByRole('button', { name: '阮一峰科技爱好者周刊' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&source=src-hn%2Csrc-ruanyf', {}, expect.objectContaining({ preserveState: true }))

    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&source=src-ruanyf', {}, expect.objectContaining({ preserveState: true }))
  })

  it('小签列出所有源含停用的；点一下加进筛选，再点一下去掉', async () => {
    const user = userEvent.setup()
    const { unmount } = filters()

    const chip = screen.getByRole('button', { name: 'Hacker News' })
    expect(chip).toHaveAttribute('aria-pressed', 'false')
    expect(screen.getByRole('button', { name: '阮一峰科技爱好者周刊' })).toBeInTheDocument()
    await user.click(chip)
    expect(router.get).toHaveBeenCalledWith('/search?q=kuber&source=src-hn', {}, expect.objectContaining({ preserveState: true }))
    unmount()

    filters({ sources: ['src-hn', 'src-ruanyf'] })
    expect(screen.getByRole('button', { name: 'Hacker News' })).toHaveAttribute('aria-pressed', 'true')
    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&source=src-ruanyf', {}, expect.objectContaining({ preserveState: true }))
  })
})

describe('筛选提交与确认', () => {
  it('来源、日期和刊物分段合并同一份待确认条件，链接仍可复制', async () => {
    const user = userEvent.setup()
    filters({ range: 'custom' })
    await user.click(screen.getByRole('button', { name: 'Hacker News' }))
    const from = screen.getByLabelText('起始日期')
    fireEvent.change(from, { target: { value: '2026-08-02' } })
    fireEvent.blur(from)

    const weekly = screen.getByRole('link', { name: '周刊' })
    expect(weekly).toHaveAttribute('href', '/search?q=kuber&type=weekly&source=src-hn&from=2026-08-02&range=custom')
    expect(within(screen.getByRole('navigation', { name: '日期' })).getByRole('link', { name: '全部' })).toHaveAttribute('href', '/search?q=kuber&source=src-hn')
    await user.click(weekly)
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&type=weekly&source=src-hn&from=2026-08-02&range=custom', {}, expect.objectContaining({ preserveState: true }))
    expect(router.get).toHaveBeenCalledTimes(3)
  })

  it('同一在途日期不因回车后失焦重复提交，失败结束后可重试', () => {
    filters({ range: 'custom', from: '2026-08-01' })
    const from = screen.getByLabelText('起始日期')
    fireEvent.change(from, { target: { value: '2026-08-02' } })
    fireEvent.keyDown(from, { key: 'Enter' })
    const pending = visit()
    fireEvent.blur(from)
    expect(router.get).toHaveBeenCalledTimes(1)

    act(() => pending.onFinish?.(visitRouterEvent('finish').detail.visit as ActiveVisit))
    fireEvent.keyDown(from, { key: 'Enter' })
    expect(router.get).toHaveBeenCalledTimes(2)
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-08-02&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('旧请求取消结束不会解除新请求去重或清掉它的另一端日期', () => {
    filters({ range: 'custom' })
    const from = screen.getByLabelText('起始日期')
    const to = screen.getByLabelText('结束日期')
    fireEvent.change(from, { target: { value: '2026-08-02' } })
    fireEvent.blur(from)
    const first = visit()
    fireEvent.change(to, { target: { value: '2026-09-08' } })
    fireEvent.blur(to)
    act(() => first.onFinish?.(visitRouterEvent('finish').detail.visit as ActiveVisit))
    fireEvent.blur(to)

    expect(router.get).toHaveBeenCalledTimes(2)
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-08-02&to=2026-09-08&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('成功响应即使回到原 canonical 值也确认并清掉待确认日期', async () => {
    const canonical = searchFilters({ range: 'custom', from: '2026-08-01' })
    filters(canonical)
    const from = screen.getByLabelText('起始日期')
    fireEvent.change(from, { target: { value: '2026-08-02' } })
    fireEvent.blur(from)
    act(() => visit().onSuccess?.(response(canonical)))

    expect(from).toHaveValue('2026-08-01')
    await userEvent.setup().click(screen.getByRole('button', { name: 'Hacker News' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&source=src-hn&from=2026-08-01&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('会话过期跳转登录时不把其他页面的 props 当作搜索条件读取', () => {
    const canonical = searchFilters({ range: 'custom', from: '2026-08-01' })
    filters(canonical)
    const from = screen.getByLabelText('起始日期')
    fireEvent.change(from, { target: { value: '2026-08-02' } })
    fireEvent.blur(from)
    const login = { ...response(canonical), component: 'Login/Show', props: { errors: {} } }

    expect(() => act(() => visit().onSuccess?.(login))).not.toThrow()
    expect(from).toHaveValue('2026-08-02')
  })

  it('日期预设还未返回就切回自定义时，两个日期框和下一次提交都使用该预设', async () => {
    const user = userEvent.setup()
    filters({ range: 'custom', from: '2026-08-01' })
    const dates = within(screen.getByRole('navigation', { name: '日期' }))
    await user.click(dates.getByRole('link', { name: /^近\s*7\s*天$/ }))
    await user.click(dates.getByRole('link', { name: '自定义' }))

    expect(screen.getByLabelText('起始日期')).toHaveValue('2026-09-05')
    expect(screen.getByLabelText('结束日期')).toHaveValue('2026-09-11')
    fireEvent.change(screen.getByLabelText('起始日期'), { target: { value: '2026-09-06' } })
    fireEvent.blur(screen.getByLabelText('起始日期'))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-09-06&to=2026-09-11&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('canonical 交换日期时确认旧提交，保留提交以后新输入的日期并以新条件提交', () => {
    vi.useFakeTimers()
    const { rerender } = filters({ range: 'custom', from: '2026-08-01', to: '2026-08-31' })
    const from = screen.getByLabelText('起始日期')
    const to = screen.getByLabelText('结束日期')
    from.focus()
    fireEvent.change(from, { target: { value: '2026-09-08' } })
    fireEvent.keyDown(from, { key: 'Enter' })
    const pending = visit()
    fireEvent.change(to, { target: { value: '2026-09-10' } })
    const canonical = searchFilters({ range: 'custom', from: '2026-08-31', to: '2026-09-08' })
    rerender(<FilterHarness q="kuber" filters={canonical} sourceOptions={sourceOptions} datePresets={datePresets} />)
    act(() => pending.onSuccess?.(response(canonical)))

    expect(from).toHaveFocus()
    expect(from).toHaveValue('2026-08-31')
    expect(to).toHaveValue('2026-09-10')
    act(() => vi.advanceTimersByTime(600))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-08-31&to=2026-09-10&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('普通 rerender 保留待确认条件，日期停手提交使用最新查询词', () => {
    vi.useFakeTimers()
    const { rerender } = filters({ range: 'custom' })
    fireEvent.click(screen.getByRole('button', { name: 'Hacker News' }))
    fireEvent.change(screen.getByLabelText('起始日期'), { target: { value: '2026-08-02' } })
    rerender(<FilterHarness q="fresh" filters={searchFilters({ range: 'custom' })} sourceOptions={sourceOptions} datePresets={datePresets} />)
    act(() => vi.advanceTimersByTime(600))

    expect(router.get).toHaveBeenLastCalledWith('/search?q=fresh&source=src-hn&from=2026-08-02&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('查询词草稿改变后点击当前刊物也会提交，但未改日期失焦不额外提交', async () => {
    const canonical = searchFilters({ type: 'daily', range: 'custom', from: '2026-08-01' })
    const { rerender } = filters(canonical)
    rerender(<FilterHarness q="fresh" filters={canonical} sourceOptions={sourceOptions} datePresets={datePresets} />)
    fireEvent.blur(screen.getByLabelText('起始日期'))
    expect(router.get).not.toHaveBeenCalled()

    await userEvent.setup().click(screen.getByRole('link', { name: '日刊' }))
    expect(router.get).toHaveBeenLastCalledWith('/search?q=fresh&type=daily&from=2026-08-01&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('外部导航即使日期值相同也恢复 canonical 草稿并取消旧计时器', () => {
    vi.useFakeTimers()
    const canonical = searchFilters({ range: 'custom', from: '2026-08-01' })
    const { rerender } = filters(canonical)
    fireEvent.change(screen.getByLabelText('起始日期'), { target: { value: '2026-08-02' } })
    window.history.replaceState({}, '', '/search?q=kuber&page=2')
    rerender(<FilterHarness q="kuber" filters={canonical} sourceOptions={sourceOptions} datePresets={datePresets} />)

    expect(screen.getByLabelText('起始日期')).toHaveValue('2026-08-01')
    act(() => vi.advanceTimersByTime(600))
    expect(router.get).not.toHaveBeenCalled()
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

  it('改日期框停手后发一次访问', () => {
    vi.useFakeTimers()
    filters({ range: 'custom', from: '2026-08-01', to: null })

    fireEvent.change(screen.getByLabelText('结束日期'), { target: { value: '2026-09-08' } })
    expect(router.get).not.toHaveBeenCalled()
    vi.advanceTimersByTime(600)

    expect(router.get).toHaveBeenCalledTimes(1)
    expect(router.get).toHaveBeenCalledWith('/search?q=kuber&from=2026-08-01&to=2026-09-08&range=custom', {}, expect.objectContaining({ preserveState: true }))
    vi.useRealTimers()
  })

  it('失焦或回车立即提交', () => {
    filters({ range: 'custom', from: '2026-08-01', to: null })
    const to = screen.getByLabelText('结束日期')

    fireEvent.change(to, { target: { value: '2026-09-08' } })
    fireEvent.blur(to)
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-08-01&to=2026-09-08&range=custom', {}, expect.objectContaining({ preserveState: true }))

    fireEvent.change(screen.getByLabelText('起始日期'), { target: { value: '2026-08-02' } })
    fireEvent.keyDown(screen.getByLabelText('起始日期'), { key: 'Enter' })
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-08-02&to=2026-09-08&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  it('前一次访问未返回时起止日期合并，清空其中一端仍保留另一端', () => {
    filters({ range: 'custom' })
    const from = screen.getByLabelText('起始日期')
    const to = screen.getByLabelText('结束日期')

    fireEvent.change(from, { target: { value: '2026-08-02' } })
    fireEvent.blur(from)
    fireEvent.change(to, { target: { value: '2026-09-08' } })
    fireEvent.blur(to)
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&from=2026-08-02&to=2026-09-08&range=custom', {}, expect.objectContaining({ preserveState: true }))

    fireEvent.change(from, { target: { value: '' } })
    fireEvent.blur(from)
    expect(router.get).toHaveBeenLastCalledWith('/search?q=kuber&to=2026-09-08&range=custom', {}, expect.objectContaining({ preserveState: true }))
  })

  // 键盘逐位输入年份：2 → 0002、20 → 0020……没打完的年份不发请求
  it('年份没打完不提交', () => {
    vi.useFakeTimers()
    filters({ range: 'custom', from: '2026-08-01', to: null })
    const from = screen.getByLabelText('起始日期')

    for (const value of ['0002-08-01', '0020-08-01', '0202-08-01']) {
      fireEvent.change(from, { target: { value } })
      vi.advanceTimersByTime(600)
    }
    expect(router.get).not.toHaveBeenCalled()

    fireEvent.change(from, { target: { value: '2025-08-01' } })
    vi.advanceTimersByTime(600)
    expect(router.get).toHaveBeenCalledTimes(1)
    expect(router.get).toHaveBeenCalledWith('/search?q=kuber&from=2025-08-01&range=custom', {}, expect.objectContaining({ preserveState: true }))
    vi.useRealTimers()
  })

  // 访问回来 props 变了，输入框还是同一个节点：键盘焦点不丢
  it('提交后日期框不重挂', () => {
    const { rerender } = render(
      <FilterHarness q="kuber" filters={searchFilters({ range: 'custom', from: '2026-08-01', to: null })} sourceOptions={sourceOptions} datePresets={datePresets} />,
    )
    const from = screen.getByLabelText('起始日期')
    from.focus()

    rerender(
      <FilterHarness q="kuber" filters={searchFilters({ range: 'custom', from: '2026-08-02', to: null })} sourceOptions={sourceOptions} datePresets={datePresets} />,
    )

    expect(screen.getByLabelText('起始日期')).toBe(from)
    expect(from).toHaveFocus()
    expect(from).toHaveValue('2026-08-02')
  })

  // canonical props 更新时回显必须跟随；真实前进后退由 Inertia 重挂页面并清理旧计时器。
  it('日期框随 props 更新', () => {
    const { rerender } = render(
      <FilterHarness q="kuber" filters={searchFilters({ range: 'custom', from: '2026-08-01', to: null })} sourceOptions={sourceOptions} datePresets={datePresets} />,
    )
    expect(screen.getByLabelText('起始日期')).toHaveValue('2026-08-01')

    rerender(
      <FilterHarness q="kuber" filters={searchFilters({ range: 'custom', from: '2026-09-01', to: null })} sourceOptions={sourceOptions} datePresets={datePresets} />,
    )

    expect(screen.getByLabelText('起始日期')).toHaveValue('2026-09-01')
  })
})

describe('hrefWith', () => {
  it('换掉几项，其余照旧，sort 保留', () => {
    expect(hrefWith('kuber', searchFilters({ sort: 'date', sources: ['src-hn'] }), { type: 'weekly' })).toBe('/search?q=kuber&type=weekly&source=src-hn&sort=date')
  })
})
