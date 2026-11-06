import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'

import Field from '@/components/Field'

describe('Field', () => {
  it('标签、说明、值与变更', async () => {
    const onChange = vi.fn()
    render(<Field label="条数上限" name="count" value="10" onChange={onChange} note="1 到 50" mono />)

    const input = screen.getByLabelText('条数上限')
    expect(input).toHaveValue('10')
    expect(input).toHaveAttribute('name', 'count')
    expect(screen.getByText('1 到 50')).toBeInTheDocument()
    await userEvent.type(input, '2')
    expect(onChange).toHaveBeenCalledWith('102')
  })

  it('错误行与 aria-invalid', () => {
    render(<Field label="feed 地址" name="feed_url" value="" onChange={() => {}} error="必填" />)

    expect(screen.getByLabelText('feed 地址')).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByText('必填')).toBeInTheDocument()
    expect(screen.getByLabelText('feed 地址')).toHaveAccessibleDescription('必填')
  })

  it('只读字段可聚焦和选择，不被当成禁用或发送编辑', async () => {
    const onChange = vi.fn()
    render(<Field label="模型地址" name="endpoint" value="https://example.com" onChange={onChange} readOnly note="由环境配置" />)

    const input = screen.getByRole('textbox', { name: '模型地址' })
    expect(input).not.toBeDisabled()
    expect(input).toHaveAccessibleDescription('由环境配置')
    await userEvent.click(input)
    expect(input).toHaveFocus()
    await userEvent.type(input, '/v1')
    expect(input).toHaveValue('https://example.com')
    expect(onChange).not.toHaveBeenCalled()
  })
})
