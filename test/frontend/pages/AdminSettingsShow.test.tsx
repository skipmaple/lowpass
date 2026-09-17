import { act, render, screen, within } from '@testing-library/react'
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
  router.patch.mockReset()
  router.delete.mockClear()
  router.reload.mockReset()
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
    await userEvent.click(within(screen.getByRole('heading', { level: 2, name: '调度' }).parentElement!).getByRole('button', { name: '保存调度' }))
    expect(formPatch).toHaveBeenCalledWith('/admin/settings', expect.any(Object))

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
    expect(screen.getByText('未配置告警渠道，无法发送测试。')).toBeInTheDocument()
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
    expect(router.patch).toHaveBeenCalledWith('/admin/interest_areas/ia-1', { interest_area: { name: 'AI / LLM', keywords: 'RAG', sort_order: 1, enabled: true } }, expect.any(Object))

    await userEvent.click(within(rows[2]).getByRole('button', { name: '删除' }))
    expect(router.delete).not.toHaveBeenCalled()
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: '确认删除' }))
    expect(router.delete).toHaveBeenCalledWith('/admin/interest_areas/ia-2', expect.any(Object))

    const last = rows[3]
    await userEvent.type(within(last).getByLabelText('名称'), 'Rust')
    await userEvent.click(within(last).getByRole('button', { name: '新增' }))
    expect(router.post).toHaveBeenCalledWith('/admin/interest_areas', { interest_area: { name: 'Rust', keywords: '', sort_order: 0, enabled: true } }, expect.any(Object))
  })

  it('兴趣画像：新增成功后空白行清空', async () => {
    const areas = [interestArea(), interestArea({ id: 'ia-2', name: '前端开发', keywords: 'React', sort_order: 2, enabled: false })]
    const { rerender } = show({ interest_areas: areas })
    const rows = () => within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row')

    await userEvent.type(within(rows()[3]).getByLabelText('名称'), 'Rust')
    expect(within(rows()[3]).getByLabelText('名称')).toHaveValue('Rust')

    await userEvent.click(within(rows()[3]).getByRole('button', { name: '新增' }))
    act(() => { router.post.mock.calls[0][2].onSuccess({ props: { flash: {} } }); router.post.mock.calls[0][2].onFinish() })
    // 成功回调清空自己的草稿，刷新列表不重挂新增行。
    const grown = [...areas, interestArea({ id: 'ia-3', name: 'Rust', keywords: '所有权', sort_order: 3 })]
    rerender(<Show {...showProps({ interest_areas: grown })} />)
    expect(rows()).toHaveLength(5)
    expect(within(rows()[4]).getByLabelText('名称')).toHaveValue('')
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
    await userEvent.click(screen.getByRole('button', { name: '保存模型设置' }))
    expect(formPatch).toHaveBeenCalledWith('/admin/settings', expect.any(Object))
  })

  it('推荐理由：配置好后显示用量', () => {
    show({ reasons: reasonsStatus({ configured: true, key_configured: true, base_url: 'https://model.example/v1', model_name: 'gpt-x', month_calls: 12, month_cost: '0.35', monthly_cap: '10', today_calls: 3 }) })
    expect(within(screen.getByText('密钥').closest('.kv-row')!).getByText('已配置')).toBeInTheDocument()
    expect(document.querySelector('.reasons-usage')!.textContent).toContain('本月 12 次 · 费用 0.35 未指定币种 / 上限 10 未指定币种')
    expect(document.querySelector('.reasons-usage')!.textContent).toContain('今日 3 次')
  })
  it('兴趣画像行独立等待，失败保留数据，删除先确认', async () => {
    show()
    const rows = within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row')
    await userEvent.type(within(rows[1]).getByLabelText('关键词'), ' draft')
    await userEvent.click(within(rows[1]).getByRole('button', { name: '保存' }))
    expect(within(rows[1]).getByRole('button', { name: '正在保存…' })).toBeDisabled()
    expect(within(rows[2]).getByRole('button', { name: '保存' })).toBeEnabled()
    const callbacks = router.patch.mock.calls[0][2]
    act(() => { callbacks.onSuccess({ props: { flash: { alert: '名称已存在' } } }); callbacks.onFinish() })
    expect(within(rows[1]).getByText('名称已存在')).toBeInTheDocument()
    expect((within(rows[1]).getByLabelText('关键词') as HTMLInputElement).value).toContain('draft')
    await userEvent.click(within(rows[2]).getByRole('button', { name: '删除' }))
    expect(router.delete).not.toHaveBeenCalled()
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: '确认删除' }))
    expect(router.delete).toHaveBeenCalledWith('/admin/interest_areas/ia-2', expect.any(Object))
  })

  it.each([true, false])('重叠保存不会中断另一行，逆序完成=%s，各自行保留错误和草稿', async (reverse) => {
    type Pending = { async: boolean; canceled: boolean; finish: () => void; complete: (alert?: string) => void }
    const pending: Pending[] = []
    // Model the installed Inertia stream contract: a new synchronous visit interrupts
    // earlier synchronous visits; asynchronous visits retain their completion callbacks.
    router.patch.mockImplementation((_url, _payload, options) => {
      if (!options.async) pending.filter((request) => !request.async && !request.canceled).forEach((request) => { request.canceled = true; request.finish() })
      options.onStart()
      const request: Pending = {
        async: options.async === true,
        canceled: false,
        finish: options.onFinish,
        complete: (alert) => {
          if (!request.canceled) { options.onSuccess({ props: { flash: alert ? { alert } : {} } }); options.onFinish() }
        },
      }
      pending.push(request)
    })
    const { rerender } = show()
    const rows = within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row')
    await userEvent.type(within(rows[1]).getByLabelText('关键词'), ' draft A')
    await userEvent.type(within(rows[2]).getByLabelText('关键词'), ' draft B')
    await userEvent.click(within(rows[1]).getByRole('button', { name: '保存' }))
    await userEvent.click(within(rows[2]).getByRole('button', { name: '保存' }))
    expect(pending.every((request) => !request.canceled)).toBe(true)
    expect(router.reload).not.toHaveBeenCalled()
    expect(within(rows[1]).getByRole('button', { name: '正在保存…' })).toBeDisabled()
    expect(within(rows[2]).getByRole('button', { name: '正在保存…' })).toBeDisabled()
    act(() => {
      if (reverse) { pending[1].complete(); pending[0].complete('名称已存在') }
      else { pending[0].complete('名称已存在'); pending[1].complete() }
    })
    expect(router.reload).toHaveBeenCalledTimes(1)
    expect(router.reload).toHaveBeenCalledWith(expect.objectContaining({ only: ['interest_areas'] }))
    expect(router.patch.mock.calls.every((call) => call[2].only.join(',') === 'flash,errors')).toBe(true)
    // A response may still contain a prior snapshot of the other row; stable row
    // identities preserve the local edits and each request's own outcome.
    rerender(<Show {...showProps()} />)
    expect(within(rows[1]).getByText('名称已存在')).toBeInTheDocument()
    expect(within(rows[2]).getByText('已保存')).toBeInTheDocument()
    expect((within(rows[1]).getByLabelText('关键词') as HTMLInputElement).value).toContain('draft A')
    expect((within(rows[2]).getByLabelText('关键词') as HTMLInputElement).value).toContain('draft B')
  })

  it('重叠删除与保存只在全部完成后刷新列表，晚到的保存不恢复已删除行', async () => {
    const { rerender } = show()
    const rows = within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row')
    await userEvent.click(within(rows[1]).getByRole('button', { name: '保存' }))
    const save = router.patch.mock.calls[0][2]
    act(() => save.onStart())
    await userEvent.click(within(rows[2]).getByRole('button', { name: '删除' }))
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: '确认删除' }))
    const remove = router.delete.mock.calls[0][1]
    expect(remove).toMatchObject({ async: true, only: ['flash', 'errors'] })
    act(() => { remove.onStart(); remove.onSuccess({ props: { flash: {} } }); remove.onFinish() })
    expect(screen.queryByDisplayValue('前端开发')).not.toBeInTheDocument()
    expect(router.reload).not.toHaveBeenCalled()
    act(() => { save.onSuccess({ props: { flash: {} } }); save.onFinish() })
    expect(router.reload).toHaveBeenCalledTimes(1)
    // Even if the next render carries the earlier snapshot, the completed delete
    // stays hidden until the authoritative, settled-list response removes it.
    rerender(<Show {...showProps()} />)
    expect(screen.queryByDisplayValue('前端开发')).not.toBeInTheDocument()
    rerender(<Show {...showProps({ interest_areas: [interestArea()] })} />)
    expect(screen.queryByDisplayValue('前端开发')).not.toBeInTheDocument()
    expect(within(rows[1]).getByText('已保存')).toBeInTheDocument()
  })

  it('列表变化保留新增草稿；新写入和离开页面取消过期列表刷新', async () => {
    let cancellations = 0
    router.reload.mockImplementation((options) => options.onCancelToken({ cancel: () => { cancellations += 1 } }))
    const { rerender, unmount } = show()
    const rows = () => within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row')
    await userEvent.type(within(rows()[3]).getByLabelText('名称'), '新增草稿')
    await userEvent.click(within(rows()[1]).getByRole('button', { name: '保存' }))
    const first = router.patch.mock.calls[0][2]
    act(() => { first.onStart(); first.onSuccess({ props: { flash: {} } }); first.onFinish() })
    expect(router.reload).toHaveBeenCalledTimes(1)
    await userEvent.click(within(rows()[1]).getByRole('button', { name: '保存' }))
    const second = router.patch.mock.calls[1][2]
    act(() => second.onStart())
    expect(cancellations).toBe(1)
    act(() => { second.onSuccess({ props: { flash: {} } }); second.onFinish() })
    rerender(<Show {...showProps({ interest_areas: [interestArea()] })} />)
    expect(within(rows()[2]).getByLabelText('名称')).toHaveValue('新增草稿')
    await userEvent.click(within(rows()[1]).getByRole('button', { name: '保存' }))
    const third = router.patch.mock.calls[2][2]
    act(() => third.onStart())
    unmount()
    act(() => third.onFinish())
    expect(router.reload).toHaveBeenCalledTimes(2)
    expect(cancellations).toBe(2)
  })

  it('选择币种不重标未保存的历史费用，旧账确认随币种变化清除', async () => {
    show({ reasons: reasonsStatus({ has_nonzero_costs: true, month_cost: '1.25' }) })
    await userEvent.selectOptions(screen.getByLabelText('记账币种'), 'USD')
    expect(document.querySelector('.reasons-usage')!.textContent).toContain('1.25 未指定币种')
    const confirmation = screen.getByRole('checkbox', { name: /确认现有单价、上限和历史费用均使用 USD/ })
    await userEvent.click(confirmation)
    expect(confirmation).toBeChecked()
    await userEvent.selectOptions(screen.getByLabelText('记账币种'), 'CNY')
    expect(screen.getByRole('checkbox', { name: /确认现有单价、上限和历史费用均使用 CNY/ })).not.toBeChecked()
  })

  it('有已指定币种的非零旧账时，不能改币种', () => {
    show({ reasons: reasonsStatus({ currency: 'USD', has_nonzero_costs: true, month_cost: '1.25' }) })
    expect(screen.getByLabelText('记账币种')).toBeDisabled()
    expect(document.querySelector('.reasons-usage')!.textContent).toContain('1.25 USD')
  })

})
