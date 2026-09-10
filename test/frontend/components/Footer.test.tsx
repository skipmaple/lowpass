import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Footer from '@/components/Footer'
import { latestWeeklyHref } from '@/lib/paths'

// 页脚：邮戳、「明早 06:00 · 下一期」、最新周刊、前后期按钮。
// 中文走文楷、时间走 Maple，这一行是手写的两种角色，不是 Mixed。

function nextLine() {
  return screen.getByText('明早').parentElement as HTMLElement
}

describe('Footer 下一期那一行', () => {
  it('中文与时间分成两个字体角色', () => {
    render(<Footer nextAt="06:00" />)

    const runs = Array.from(nextLine().children).map((el) => [el.textContent, (el as HTMLElement).style.fontFamily])
    expect(runs).toEqual([
      ['明早 ', 'var(--font-cjk)'],
      ['06:00', 'var(--font-data)'],
      [' · ', 'var(--font-data)'],
      ['下一期', 'var(--font-cjk)'],
    ])
  })

  // 生成时间读的是 Setting，不是写死的 06:00
  it('时间来自 props', () => {
    render(<Footer nextAt="07:30" />)

    expect(nextLine()).toHaveTextContent('明早 07:30 · 下一期')
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

    expect(screen.queryByRole('link', { name: '前一期' })).toBeNull()
    expect(screen.queryByRole('link', { name: '后一期' })).toBeNull()
  })

  it('有地址的是链接，没有的退成不可点', () => {
    render(<Footer prevHref="/daily/2026-09-07" nextHref={null} />)

    expect(screen.getByRole('link', { name: '前一期' })).toHaveAttribute('href', '/daily/2026-09-07')

    const next = screen.getByRole('link', { name: '后一期' })
    expect(next).toHaveAttribute('aria-disabled', 'true')
    expect(next).not.toHaveAttribute('href')
  })

  it('只有后一期时也把这一组摆出来', () => {
    render(<Footer prevHref={null} nextHref="/daily/2026-09-09" />)

    expect(screen.getByRole('link', { name: '后一期' })).toHaveAttribute('href', '/daily/2026-09-09')
    expect(screen.getByRole('link', { name: '前一期' })).toHaveAttribute('aria-disabled', 'true')
  })
})
