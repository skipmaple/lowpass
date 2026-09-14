import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'

import SegButtons from '@/components/SegButtons'

describe('SegButtons', () => {
  it('当前项 aria-pressed，点别的项回调', async () => {
    const onChange = vi.fn()
    render(<SegButtons label="刊物" options={[{ value: 'daily', label: '日刊' }, { value: 'weekly', label: '周刊' }]} value="daily" onChange={onChange} />)

    expect(screen.getByRole('group', { name: '刊物' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '日刊' })).toHaveAttribute('aria-pressed', 'true')
    await userEvent.click(screen.getByRole('button', { name: '周刊' }))
    expect(onChange).toHaveBeenCalledWith('weekly')
  })

  it('disabled 的项不可点', () => {
    render(<SegButtons label="刊物" options={[{ value: 'daily', label: '日刊', disabled: true }]} value="daily" onChange={() => {}} />)

    expect(screen.getByRole('button', { name: '日刊' })).toBeDisabled()
  })
})
