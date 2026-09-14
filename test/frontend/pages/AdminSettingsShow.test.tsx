import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'

import Show from '@/pages/Admin/Settings/Show'
import { formPatch, setPageProps } from '../support/inertia'

// 设置（5.6，画布 admin_settings()）：调度时间可改，白名单只读

function show(errors: Record<string, string[]> = {}, whitelist = ['drew@example.com']) {
  const props = { schedule: { daily_time: '06:00', weekly_time: '09:00' }, whitelist, daily_time: '06:00', latest_weekly_key: null }
  setPageProps({ ...props, flash: {}, errors })
  return render(<Show {...props} />)
}

afterEach(() => formPatch.mockClear())

describe('Admin/Settings/Show', () => {
  it('调度字段、保存 PATCH，白名单与说明', async () => {
    show()

    expect(screen.getByRole('link', { name: '设置' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('heading', { level: 2, name: '调度' })).toBeInTheDocument()
    const daily = screen.getByLabelText('日刊生成时间')
    expect(daily).toHaveValue('06:00')
    await userEvent.clear(daily)
    await userEvent.type(daily, '06:30')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))
    expect(formPatch).toHaveBeenCalledWith('/admin/settings')

    expect(screen.getByRole('heading', { level: 2, name: '管理员白名单（只读）' })).toBeInTheDocument()
    expect(screen.getByText('drew@example.com')).toBeInTheDocument()
    expect(screen.getByText('白名单由环境配置，改动在下次登录生效。')).toBeInTheDocument()
  })

  it('错误按字段；白名单为空写「未配置」', () => {
    show({ daily_time: ['格式是 HH:MM'] }, [])

    expect(screen.getByText('格式是 HH:MM')).toBeInTheDocument()
    expect(screen.getByLabelText('日刊生成时间')).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByText('未配置')).toBeInTheDocument()
  })
})
