import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'

import Show from '@/pages/Admin/Settings/Show'
import type { AlertChannels, InterestArea, ReasonsStatus } from '@/types/lowpass'
import { formPatch, router, setPageProps } from '../support/inertia'
import { interestArea, reasonsStatus } from '../support/props'

// 设置（5.6，画布 admin_settings()）：调度时间可改，白名单只读；告警渠道状态与「发送测试告警」（P2-③）；
// 兴趣画像与推荐理由（④）往这一页加节（Task 5）

type ShowOverrides = {
  errors?: Record<string, string[]>
  whitelist?: string[]
  alerts?: AlertChannels
  reasons?: ReasonsStatus
  interest_areas?: InterestArea[]
}

function showProps(overrides: ShowOverrides = {}) {
  return {
    schedule: { daily_time: '06:00', weekly_time: '09:00' },
    whitelist: overrides.whitelist ?? ['drew@example.com'],
    alerts: overrides.alerts ?? { email: { configured: false, label: '未配置' }, webhook: { configured: false, label: '未配置' } },
    reasons: overrides.reasons ?? reasonsStatus(),
    interest_areas: overrides.interest_areas ?? [interestArea(), interestArea({ id: 'ia-2', name: '前端开发', keywords: 'React', sort_order: 2, enabled: false })],
    daily_time: '06:00',
    latest_weekly_key: null,
  }
}

function show(overrides: ShowOverrides = {}) {
  const props = showProps(overrides)
  setPageProps({ ...props, flash: {}, errors: overrides.errors ?? {} })
  return render(<Show {...props} />)
}

afterEach(() => {
  formPatch.mockClear()
  router.post.mockClear()
  router.patch.mockClear()
  router.delete.mockClear()
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
    await userEvent.click(within(screen.getByRole('heading', { level: 2, name: '调度' }).parentElement!).getByRole('button', { name: '保存' }))
    expect(formPatch).toHaveBeenCalledWith('/admin/settings')

    expect(screen.getByRole('heading', { level: 2, name: '管理员白名单（只读）' })).toBeInTheDocument()
    expect(screen.getByText('drew@example.com')).toBeInTheDocument()
    expect(screen.getByText('白名单由环境配置，改动在下次登录生效。')).toBeInTheDocument()
  })

  it('错误按字段；白名单为空写「未配置」', () => {
    show({ errors: { daily_time: ['格式是 HH:MM'] }, whitelist: [] })

    expect(screen.getByText('格式是 HH:MM')).toBeInTheDocument()
    expect(screen.getByLabelText('日刊生成时间')).toHaveAttribute('aria-invalid', 'true')
    expect(within(screen.getByRole('heading', { level: 2, name: '管理员白名单（只读）' }).parentElement!).getByText('未配置')).toBeInTheDocument()
  })

  it('告警：两渠道状态、按钮与 POST', async () => {
    show({ whitelist: ['drew@example.com'], alerts: { email: { configured: true, label: 'd***@example.com' }, webhook: { configured: false, label: '未配置' } } })

    expect(screen.getByRole('heading', { level: 2, name: '告警' })).toBeInTheDocument()
    expect(screen.getByText('d***@example.com')).toBeInTheDocument()
    // 「未配置」这一节只有 webhook 那一行有（密钥行在「推荐理由」那一节，另算）
    expect(within(screen.getByRole('heading', { level: 2, name: '告警' }).parentElement!).getAllByText('未配置')).toHaveLength(1)
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

  it('兴趣画像：每行可改、可删，末行新增', async () => {
    show()

    expect(screen.getByRole('heading', { level: 2, name: '兴趣画像' })).toBeInTheDocument()
    const rows = within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row')
    expect(rows).toHaveLength(4) // 表头 + 2 行 + 新增行
    const first = rows[1]
    expect(within(first).getByLabelText('名称')).toHaveValue('AI / LLM')
    await userEvent.clear(within(first).getByLabelText('关键词'))
    await userEvent.type(within(first).getByLabelText('关键词'), 'RAG')
    await userEvent.click(within(first).getByRole('button', { name: '保存' }))
    expect(router.patch).toHaveBeenCalledWith('/admin/interest_areas/ia-1', { interest_area: { name: 'AI / LLM', keywords: 'RAG', sort_order: 1, enabled: true } })

    await userEvent.click(within(rows[2]).getByRole('button', { name: '删除' }))
    expect(router.delete).toHaveBeenCalledWith('/admin/interest_areas/ia-2')

    const last = rows[3]
    await userEvent.type(within(last).getByLabelText('名称'), 'Rust')
    await userEvent.click(within(last).getByRole('button', { name: '新增' }))
    expect(router.post).toHaveBeenCalledWith('/admin/interest_areas', { interest_area: { name: 'Rust', keywords: '', sort_order: 0, enabled: true } })
  })

  it('兴趣画像：新增成功后空白行清空', async () => {
    const areas = [interestArea(), interestArea({ id: 'ia-2', name: '前端开发', keywords: 'React', sort_order: 2, enabled: false })]
    const { rerender } = show({ interest_areas: areas })
    const rows = () => within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row')

    await userEvent.type(within(rows()[3]).getByLabelText('名称'), 'Rust')
    expect(within(rows()[3]).getByLabelText('名称')).toHaveValue('Rust')

    // 新增成功后 Inertia 把多一个领域的 props 送回来：空白行要重新挂一遍，刚打的字不能留在里面
    const grown = [...areas, interestArea({ id: 'ia-3', name: 'Rust', keywords: '所有权', sort_order: 3 })]
    rerender(<Show {...showProps({ interest_areas: grown })} />)
    expect(rows()).toHaveLength(5)
    expect(within(rows()[4]).getByLabelText('名称')).toHaveValue('')
  })

  it('兴趣画像表在自己的容器里横向滚', () => {
    const { container } = show()

    expect(container.querySelector('.admin-table-wrap')).toContainElement(screen.getByRole('table', { name: '兴趣画像' }))
  })

  it('推荐理由：未配置时一句说明与密钥状态；配置表单 PATCH model 组', async () => {
    show()
    expect(screen.getByRole('heading', { level: 2, name: '推荐理由' })).toBeInTheDocument()
    expect(screen.getByText('未配置模型供应商')).toBeInTheDocument()
    // 键是「密钥」，值只放状态（其余 kv-row 也是这个形状）
    expect(within(screen.getByText('密钥').closest('.kv-row')!).getByText('未配置')).toBeInTheDocument()

    await userEvent.type(screen.getByLabelText('接口地址'), 'https://model.example/v1')
    await userEvent.type(screen.getByLabelText('模型名'), 'gpt-x')
    // .at(-1) 在这个仓库的 tsconfig（lib: ES2020）下没有类型，改用下标取最后一个
    const buttons = screen.getAllByRole('button', { name: '保存' })
    await userEvent.click(buttons[buttons.length - 1])
    expect(formPatch).toHaveBeenCalledWith('/admin/settings')
  })

  it('推荐理由：配置好后显示用量', () => {
    show({ reasons: reasonsStatus({ configured: true, key_configured: true, base_url: 'https://model.example/v1', model_name: 'gpt-x', month_calls: 12, month_cost: '0.35', monthly_cap: '10', today_calls: 3 }) })
    expect(within(screen.getByText('密钥').closest('.kv-row')!).getByText('已配置')).toBeInTheDocument()
    expect(document.querySelector('.reasons-usage')!.textContent).toContain('本月 12 次 · 费用 0.35 / 上限 10')
    expect(document.querySelector('.reasons-usage')!.textContent).toContain('今日 3 次')
  })
})
