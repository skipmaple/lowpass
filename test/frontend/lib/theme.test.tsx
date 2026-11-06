import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import ThemePicker from '@/components/ThemePicker'
import { setTheme, THEME_KEY } from '@/lib/theme'

const fonts = vi.hoisted(() => vi.fn().mockResolvedValue(undefined))
vi.mock('@/lib/contentFonts', () => ({ loadContentFonts: fonts }))

beforeEach(() => {
  document.documentElement.dataset.theme = 'daybreak'
  document.head.innerHTML = '<meta name="theme-color" content="#FCFAF2">'
  localStorage.clear()
  fonts.mockClear()
  vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback) => { callback(0); return 1 })
})

afterEach(() => {
  document.head.innerHTML = ''
  document.documentElement.removeAttribute('data-theme')
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('theme preference', () => {
  it('两个选择入口同步，持久化主题和浏览器颜色，不重建表单', async () => {
    render(<><ThemePicker /><ThemePicker /><input aria-label="未保存输入" defaultValue="保留我的内容" /></>)
    const input = screen.getByRole('textbox')
    await userEvent.click(screen.getAllByRole('radio', { name: /展开阅读/ })[0])
    expect(screen.getAllByRole('radio', { name: /展开阅读/ }).every((node) => (node as HTMLInputElement).checked)).toBe(true)
    expect(localStorage.getItem(THEME_KEY)).toBe('unfold')
    expect(document.querySelector('meta[name="theme-color"]')).toHaveAttribute('content', '#111515')
    expect(screen.getByRole('textbox')).toBe(input)
    expect(input).toHaveValue('保留我的内容')
  })

  it('跨标签同步有效主题；非法值回退 A，存储被禁用仍能切换', async () => {
    render(<ThemePicker />)
    act(() => window.dispatchEvent(new StorageEvent('storage', { key: THEME_KEY, newValue: 'duet' })))
    expect(screen.getByRole('radio', { name: /双声部/ })).toBeChecked()
    act(() => window.dispatchEvent(new StorageEvent('storage', { key: THEME_KEY, newValue: 'invalid' })))
    expect(screen.getByRole('radio', { name: /层叠清晨/ })).toBeChecked()
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => { throw new DOMException('Blocked') })
    await userEvent.click(screen.getByRole('radio', { name: /展开阅读/ }))
    expect(screen.getByRole('radio', { name: /展开阅读/ })).toBeChecked()
  })

  it('长正文按当前文章而不是父来源定位，字体完成后再校准一次', async () => {
    render(<section id="source"><article id="article">当前文章</article></section>)
    vi.stubGlobal('scrollY', 1500)
    vi.stubGlobal('scrollBy', vi.fn())
    const article = document.getElementById('article')!
    const section = document.getElementById('source')!
    vi.spyOn(article, 'getBoundingClientRect').mockImplementation(() => ({ top: document.documentElement.dataset.theme === 'daybreak' ? 120 : 180, bottom: 600 } as DOMRect))
    const parentRect = vi.spyOn(section, 'getBoundingClientRect')
    await act(async () => { setTheme('duet') })
    expect(window.scrollBy).toHaveBeenCalledWith(0, 60)
    expect(parentRect).not.toHaveBeenCalled()
    expect(fonts).toHaveBeenCalledWith('duet')
  })

  it('字体晚到时不把已经继续滚动的读者拉回原处', async () => {
    let loaded: () => void = () => undefined
    fonts.mockReturnValueOnce(new Promise<void>((resolve) => { loaded = resolve }))
    render(<article id="late-font-article">正在阅读</article>)
    vi.stubGlobal('scrollY', 1500)
    vi.stubGlobal('scrollBy', vi.fn())
    vi.spyOn(document.getElementById('late-font-article')!, 'getBoundingClientRect').mockReturnValue({ top: 120, bottom: 600 } as DOMRect)
    act(() => setTheme('unfold'))
    act(() => window.dispatchEvent(new WheelEvent('wheel')))
    await act(async () => { loaded() })
    expect(window.scrollBy).toHaveBeenCalledTimes(1)
  })
})
