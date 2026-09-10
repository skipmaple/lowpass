import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Masthead from '@/components/Masthead'

// 报头黑带。P0 没有搜索（F-13）与账户（F-1）那两条路由：不传 href 时右侧两个位置
// 渲染成同样外观的非交互占位，不给读者一个点开就 404 的图标。

describe('Masthead 导航', () => {
  it('刊名与两条导航指向日刊最新一期与周刊归档', () => {
    render(<Masthead />)

    expect(screen.getByRole('link', { name: 'lowpass' })).toHaveAttribute('href', '/')
    expect(screen.getByRole('link', { name: '日刊' })).toHaveAttribute('href', '/')
    expect(screen.getByRole('link', { name: '周刊' })).toHaveAttribute('href', '/weekly')
  })

  it('当前栏目标 aria-current', () => {
    const { unmount } = render(<Masthead active="daily" />)
    expect(screen.getByRole('link', { name: '日刊' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '周刊' })).not.toHaveAttribute('aria-current')
    unmount()

    render(<Masthead active="weekly" />)
    expect(screen.getByRole('link', { name: '周刊' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '日刊' })).not.toHaveAttribute('aria-current')
  })

  it('哪一栏都不高亮时两条都不带 aria-current', () => {
    render(<Masthead />)

    expect(screen.getByRole('link', { name: '日刊' })).not.toHaveAttribute('aria-current')
    expect(screen.getByRole('link', { name: '周刊' })).not.toHaveAttribute('aria-current')
  })
})

describe('Masthead 搜索与账户', () => {
  it('P0 没有那两条路由：占位不是链接，也不进 tab 序', () => {
    const { container } = render(<Masthead />)

    const placeholders = container.querySelectorAll('.masthead-actions [aria-disabled="true"]')
    expect(placeholders).toHaveLength(2)
    for (const placeholder of placeholders) {
      expect(placeholder.tagName.toLowerCase()).toBe('span')
      expect(placeholder).not.toHaveAttribute('href')
      expect(placeholder).not.toHaveAttribute('tabindex')
    }
    expect(screen.queryByRole('link', { name: '搜索' })).toBeNull()
    expect(screen.queryByRole('link', { name: '账户' })).toBeNull()
  })

  it('P1/P2 把 href 传进来就还是链接', () => {
    const { container } = render(<Masthead searchHref="/search" accountHref="/account" />)

    expect(screen.getByRole('link', { name: '搜索' })).toHaveAttribute('href', '/search')
    expect(screen.getByRole('link', { name: '账户' })).toHaveAttribute('href', '/account')
    expect(container.querySelectorAll('.masthead-actions [aria-disabled="true"]')).toHaveLength(0)
  })

  it('两个位置外观一样（占位与链接同一份行内样式）', () => {
    const { container: off } = render(<Masthead />)
    const placeholder = off.querySelectorAll('.masthead-actions [aria-disabled="true"]')[1]

    const { container: on } = render(<Masthead accountHref="/account" />)
    const link = on.querySelector('.masthead-actions a[aria-label="账户"]')

    expect(link?.getAttribute('style')).toBe(placeholder.getAttribute('style'))
  })
})
