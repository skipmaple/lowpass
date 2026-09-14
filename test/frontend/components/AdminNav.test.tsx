import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import AdminNav from '@/components/AdminNav'

describe('AdminNav', () => {
  it('四个分页，当前项标 aria-current', () => {
    render(<AdminNav active="issues" />)

    expect(screen.getByRole('navigation', { name: '后台' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: '信息源' })).toHaveAttribute('href', '/admin/sources')
    expect(screen.getByRole('link', { name: '期' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '用户' })).toHaveAttribute('href', '/admin/users')
    expect(screen.getByRole('link', { name: '设置' })).toHaveAttribute('href', '/admin/settings')
    expect(screen.getByRole('link', { name: '信息源' })).not.toHaveAttribute('aria-current')
  })
})
