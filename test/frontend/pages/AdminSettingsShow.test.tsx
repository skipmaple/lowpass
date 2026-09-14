import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'

import Show from '@/pages/Admin/Settings/Show'
import { formPatch, router, setPageProps } from '../support/inertia'

// 设置（5.6，画布 admin_settings()）：调度时间可改，白名单只读；告警渠道状态与「发送测试告警」（P2-③）

function show(
  errors: Record<string, string[]> = {},
  whitelist = ['drew@example.com'],
  alerts = { email: { configured: false, label: '未配置' }, webhook: { configured: false, label: '未配置' } },
) {
  const props = { schedule: { daily_time: '06:00', weekly_time: '09:00' }, whitelist, alerts, daily_time: '06:00', latest_weekly_key: null }
  setPageProps({ ...props, flash: {}, errors })
  return render(<Show {...props} />)
}

afterEach(() => {
  formPatch.mockClear()
  router.post.mockClear()
})

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
    expect(within(screen.getByRole('heading', { level: 2, name: '管理员白名单（只读）' }).parentElement!).getByText('未配置')).toBeInTheDocument()
  })

  it('告警：两渠道状态、按钮与 POST', async () => {
    show({}, ['drew@example.com'], { email: { configured: true, label: 'd***@example.com' }, webhook: { configured: false, label: '未配置' } })

    expect(screen.getByRole('heading', { level: 2, name: '告警' })).toBeInTheDocument()
    expect(screen.getByText('d***@example.com')).toBeInTheDocument()
    expect(screen.getAllByText('未配置')).toHaveLength(1)
    const button = screen.getByRole('button', { name: '发送测试告警' })
    expect(button).toBeEnabled()
    await userEvent.click(button)
    expect(router.post).toHaveBeenCalledWith('/admin/test_alert', {}, expect.objectContaining({ onFinish: expect.any(Function) }))
    // 一次点击一封：请求回来之前按钮就该禁着（限流是后一道门，不是第一道）
    expect(button).toBeDisabled()
  })

  it('告警：都没配时按钮禁用并说明', () => {
    show()

    expect(screen.getByRole('button', { name: '发送测试告警' })).toBeDisabled()
    expect(screen.getByText('渠道由环境配置，见 docs/development.md')).toBeInTheDocument()
  })
})
