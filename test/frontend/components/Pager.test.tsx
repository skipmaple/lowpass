import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Pager from '@/components/Pager'

// 分页「上一页 · n / m · 下一页」：搜索页与收藏页共用，地址由调用方给

describe('Pager', () => {
  it('两头都有地址时是两个链接，中间是「n / m」', () => {
    render(<Pager prevHref="/favorites" nextHref="/favorites?page=3" page={2} pages={3} />)
    const pager = within(screen.getByRole('navigation', { name: '分页' }))

    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('href', '/favorites')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/favorites?page=3')
    expect(screen.getByRole('navigation', { name: '分页' })).toHaveTextContent('2 / 3')
  })

  it('没有地址的那一头退成不可点态', () => {
    render(<Pager prevHref={null} nextHref={null} page={1} pages={1} />)
    const pager = within(screen.getByRole('navigation', { name: '分页' }))

    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('aria-disabled', 'true')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('aria-disabled', 'true')
  })
})
