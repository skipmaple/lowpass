import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Footer from '@/components/Footer'
import { latestWeeklyHref } from '@/lib/paths'

// 页脚：邮戳、「每天 06:00 · 下期日刊」、最新周刊、前后期按钮。
// 中文走文楷、时间走 Maple，这一行是手写的两种角色，不是 Mixed。

describe('Footer 出刊节奏', () => {
  it('显示真实设置中的出刊时间', () => {
    render(<Footer nextAt="07:30" />)
    expect(screen.getByText('每天 07:30 · 技术日刊')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: '日刊归档' })).toHaveAttribute('href', '/daily')
  })
})

describe('Footer 最新周刊', () => {
  it('有周刊就指向最新那一期', () => {
    render(<Footer latestWeeklyHref={latestWeeklyHref('2026-W36')} />)

    expect(screen.getByRole('link', { name: '最新周刊' })).toHaveAttribute('href', '/weekly/2026-W36')
  })

  // R51：一期都还没有时落到归档
  it('一期都没有就落到归档', () => {
    render(<Footer latestWeeklyHref={latestWeeklyHref(null)} />)

    expect(screen.getByRole('link', { name: '最新周刊' })).toHaveAttribute('href', '/weekly')
  })
})

describe('Footer 前后期按钮', () => {
  it('归档页没有前后期可去，两个按钮就不占位', () => {
    render(<Footer />)

    expect(screen.queryByRole('link', { name: '上一期' })).toBeNull()
    expect(screen.queryByRole('link', { name: '下一期' })).toBeNull()
  })

  it('有地址的是链接，没有的退成不可点', () => {
    render(<Footer prevHref="/daily/2026-09-07" nextHref={null} />)

    expect(screen.getByRole('link', { name: '上一期' })).toHaveAttribute('href', '/daily/2026-09-07')

    const next = screen.getByRole('link', { name: '下一期' })
    expect(next).toHaveAttribute('aria-disabled', 'true')
    expect(next).not.toHaveAttribute('href')
  })

  it('只有下一期时也把这一组摆出来', () => {
    render(<Footer prevHref={null} nextHref="/daily/2026-09-09" />)

    expect(screen.getByRole('link', { name: '下一期' })).toHaveAttribute('href', '/daily/2026-09-09')
    expect(screen.getByRole('link', { name: '上一期' })).toHaveAttribute('aria-disabled', 'true')
  })
})
