import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Masthead from '@/components/Masthead'

// 报头黑带。搜索入口指向 /search（D21）；账户（F-1）是 P2 的路由，之前是占位。

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
  // D21：搜索入口是链接与图标，搜索框只在搜索页
  it('搜索图标默认指向 /search', () => {
    render(<Masthead />)

    expect(screen.getByRole('link', { name: '搜索' })).toHaveAttribute('href', '/search')
  })

  it('P2 之前没有账户路由：占位不是链接，也不进 tab 序', () => {
    const { container } = render(<Masthead />)

    const placeholders = container.querySelectorAll('.masthead-actions [aria-disabled="true"]')
    expect(placeholders).toHaveLength(1)
    expect(placeholders[0].tagName.toLowerCase()).toBe('span')
    expect(placeholders[0]).not.toHaveAttribute('href')
    expect(placeholders[0]).not.toHaveAttribute('tabindex')
    expect(screen.queryByRole('link', { name: '账户' })).toBeNull()
  })

  it('P2 把 accountHref 传进来就还是链接', () => {
    const { container } = render(<Masthead accountHref="/account" />)

    expect(screen.getByRole('link', { name: '账户' })).toHaveAttribute('href', '/account')
    expect(container.querySelectorAll('.masthead-actions [aria-disabled="true"]')).toHaveLength(0)
  })

  it('两个位置外观一样（占位与链接同一份行内样式）', () => {
    const { container: off } = render(<Masthead />)
    const placeholder = off.querySelector('.masthead-actions [aria-disabled="true"]')

    const { container: on } = render(<Masthead accountHref="/account" />)
    const link = on.querySelector('.masthead-actions a[aria-label="账户"]')

    expect(link?.getAttribute('style')).toBe(placeholder?.getAttribute('style'))
  })
})
