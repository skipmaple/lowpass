import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import Icon from '@/components/Icon'

describe('Icon', () => {
  it('updates a named control in place without animating or moving the target', () => {
    const { rerender } = render(<Icon name="user" title="账户" size={18} />)
    const icon = screen.getByRole('img', { name: '账户' })
    rerender(<Icon name="x" title="关闭" size={18} />)
    expect(screen.getByRole('img', { name: '关闭' })).toBe(icon)
    expect(icon).toHaveAttribute('width', '18')
    expect(icon.querySelector('path')).toHaveAttribute('d', 'M18 6 6 18')
  })
  it('hides decorative icons from assistive technology', () => {
    const { container } = render(<Icon name="bookmark" />)
    expect(container.querySelector('svg')).toHaveAttribute('aria-hidden', 'true')
    expect(container.querySelector('svg')).toHaveAttribute('focusable', 'false')
  })
})
