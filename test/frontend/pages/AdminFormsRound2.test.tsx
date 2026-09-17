import { act, fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, expect, it, vi } from 'vitest'

import Show from '@/pages/Admin/Settings/Show'
import SourceForm from '@/pages/Admin/Sources/Form'
import Dialog from '@/components/Dialog'
import { emitRouterEvent, formPatch, router, setPageProps } from '../support/inertia'
import { ADAPTER_OPTIONS, adminSourceForm, interestArea, reasonsStatus } from '../support/props'

const props = {
  schedule: { daily_time: '06:00', weekly_time: '09:00' }, whitelist: [],
  alerts: { email: { configured: true, label: 'mail' }, webhook: { configured: false, label: '未配置' } },
  reasons: reasonsStatus(), interest_areas: [interestArea(), interestArea({ id: 'ia-2', name: '前端开发' })],
}
function settings(email = 'one@example.com') {
  setPageProps({ current_user: { email }, errors: {}, flash: {} })
  return render(<Show {...props} />)
}
async function editRows() {
  for (const button of screen.getAllByRole('button', { name: '编辑' })) await userEvent.click(button)
  return within(screen.getByRole('table', { name: '兴趣画像' })).getAllByRole('row').slice(1)
}
afterEach(() => {
  sessionStorage.clear()
  formPatch.mockReset()
  router.patch.mockReset()
  router.post.mockReset()
  router.delete.mockReset()
  router.reload.mockReset()
  vi.restoreAllMocks()
})

it('兴趣画像先显示摘要，编辑入口展开字段', async () => {
  settings()
  expect(screen.queryByDisplayValue('AI / LLM')).not.toBeInTheDocument()
  const row = screen.getByText('AI / LLM').closest('tr')!
  expect(within(row).getByText(/已启用/)).toBeInTheDocument()
  await userEvent.click(within(row).getByRole('button', { name: '编辑' }))
  expect(within(row).getByLabelText('名称')).toHaveValue('AI / LLM')
})

it('所有设置草稿共用一次离开确认，内部保存和刷新不触发确认', async () => {
  const confirm = vi.spyOn(window, 'confirm').mockReturnValue(false)
  settings()
  const rows = await editRows()
  fireEvent.change(screen.getByLabelText('日刊生成时间'), { target: { value: '07:00' } })
  await userEvent.type(screen.getByLabelText('模型名'), 'draft')
  await userEvent.type(within(rows[0]).getByLabelText('关键词'), ' A')
  await userEvent.type(within(rows[1]).getByLabelText('关键词'), ' B')
  const leave = new CustomEvent('inertia:before', { cancelable: true })
  emitRouterEvent('before', leave)
  expect(leave.defaultPrevented).toBe(true)
  expect(confirm).toHaveBeenCalledTimes(1)
  const unload = new Event('beforeunload', { cancelable: true })
  window.dispatchEvent(unload)
  expect(unload.defaultPrevented).toBe(true)
  formPatch.mockImplementation(() => emitRouterEvent('before', new CustomEvent('inertia:before', { cancelable: true })))
  await userEvent.click(screen.getByRole('button', { name: '保存调度' }))
  expect(confirm).toHaveBeenCalledTimes(1)
})

it('设置草稿可重新挂载恢复并按账号隔离', async () => {
  const view = settings()
  fireEvent.change(screen.getByLabelText('日刊生成时间'), { target: { value: '07:00' } })
  await userEvent.type(screen.getByLabelText('模型名'), 'draft model')
  const rows = await editRows()
  await userEvent.type(within(rows[0]).getByLabelText('关键词'), ' remembered')
  view.unmount()
  const restored = settings()
  expect(screen.getByLabelText('日刊生成时间')).toHaveValue('07:00')
  expect(screen.getByLabelText('模型名')).toHaveValue('draft model')
  expect(screen.getByDisplayValue(/remembered/)).toBeInTheDocument()
  restored.unmount()
  settings('two@example.com')
  expect(screen.getByLabelText('日刊生成时间')).toHaveValue('06:00')
  expect(screen.getByLabelText('模型名')).toHaveValue('')
  expect(screen.queryByDisplayValue(/remembered/)).not.toBeInTheDocument()
})

it('保存调度后新修改不继续显示已保存，提交保留滚动且锁定字段', async () => {
  settings()
  fireEvent.change(screen.getByLabelText('日刊生成时间'), { target: { value: '07:00' } })
  await userEvent.click(screen.getByRole('button', { name: '保存调度' }))
  const options = formPatch.mock.calls[0][1]
  expect(options.preserveScroll).toBe(true)
  expect(screen.getByLabelText('日刊生成时间')).toBeDisabled()
  act(() => { options.onSuccess({ props: {} }); options.onFinish() })
  expect(screen.getByText('调度已保存')).toBeInTheDocument()
  const clean = new Event('beforeunload', { cancelable: true })
  window.dispatchEvent(clean)
  expect(clean.defaultPrevented).toBe(false)
  fireEvent.change(screen.getByLabelText('日刊生成时间'), { target: { value: '08:00' } })
  expect(screen.queryByText('调度已保存')).not.toBeInTheDocument()
  expect(screen.getByText('调度有未保存的更改')).toBeInTheDocument()
})

it('兴趣画像只锁定提交行，字段错误关联并聚焦，重新编辑清除旧成功', async () => {
  settings()
  const rows = await editRows()
  await userEvent.type(within(rows[0]).getByLabelText('关键词'), ' draft')
  await userEvent.click(within(rows[0]).getByRole('button', { name: '保存' }))
  expect(within(rows[0]).getByLabelText('关键词')).toBeDisabled()
  expect(within(rows[1]).getByLabelText('关键词')).toBeEnabled()
  const options = router.patch.mock.calls[0][2]
  act(() => { options.onError({ name: ['名称已存在'], keywords: ['最多 200 字'] }); options.onFinish() })
  expect(within(rows[0]).getByLabelText('名称')).toHaveAttribute('aria-invalid', 'true')
  expect(within(rows[0]).getByLabelText('名称')).toHaveAccessibleDescription('名称已存在')
  expect(within(rows[0]).getByLabelText('名称')).toHaveFocus()
  await userEvent.click(within(rows[0]).getByRole('button', { name: '保存' }))
  const success = router.patch.mock.calls[1][2]
  act(() => { success.onSuccess({ props: { flash: {} } }); success.onFinish() })
  expect(within(rows[0]).getByText('已保存')).toBeInTheDocument()
  await userEvent.type(within(rows[0]).getByLabelText('关键词'), ' next')
  expect(within(rows[0]).queryByText('已保存')).not.toBeInTheDocument()
  expect(within(rows[0]).getByText('有未保存的更改')).toBeInTheDocument()
})

it('删除成功把焦点放回兴趣画像标题', async () => {
  settings()
  const row = screen.getByText('AI / LLM').closest('tr')!
  await userEvent.click(within(row).getByRole('button', { name: '删除' }))
  await userEvent.click(screen.getByRole('button', { name: '确认删除' }))
  const options = router.delete.mock.calls[0][1]
  expect(screen.getByRole('button', { name: '取消' })).toBeDisabled()
  act(() => { options.onSuccess({ props: { flash: {} } }); options.onFinish() })
  expect(screen.getByRole('heading', { name: '兴趣画像' })).toHaveFocus()
})

it('忙碌的确认框不允许取消或 Escape，Tab 留在框内', async () => {
  const cancel = vi.fn()
  render(<Dialog open busy text="删除中" cancel="取消" confirm="正在删除…" onCancel={cancel} onConfirm={() => {}} />)
  expect(screen.getByRole('button', { name: '取消' })).toBeDisabled()
  await userEvent.keyboard('{Escape}{Tab}')
  expect(cancel).not.toHaveBeenCalled()
  expect(screen.getByRole('dialog')).toHaveFocus()
})

it('RSS 和 GitHub 切换分别恢复配置与刊物草稿', async () => {
  setPageProps({ current_user: { email: 'one@example.com' }, errors: {}, flash: {} })
  render(<SourceForm source={adminSourceForm()} adapters={ADAPTER_OPTIONS} />)
  await userEvent.type(screen.getByLabelText('feed 地址'), 'https://example.com/feed')
  fireEvent.change(screen.getByLabelText('条数上限'), { target: { value: '17' } })
  fireEvent.change(screen.getByLabelText('时间窗口（小时）'), { target: { value: '48' } })
  await userEvent.click(screen.getByRole('button', { name: '周刊' }))
  await userEvent.click(screen.getByRole('button', { name: 'GitHub Trending' }))
  await userEvent.type(screen.getByLabelText('语言列表'), 'Ruby')
  await userEvent.click(screen.getByRole('button', { name: 'RSS/Atom' }))
  expect(screen.getByLabelText('feed 地址')).toHaveValue('https://example.com/feed')
  expect(screen.getByLabelText('条数上限')).toHaveValue(17)
  expect(screen.getByRole('button', { name: '周刊' })).toHaveAttribute('aria-pressed', 'true')
  await userEvent.click(screen.getByRole('button', { name: '日刊' }))
  expect(screen.getByLabelText('时间窗口（小时）')).toHaveValue(48)
  await userEvent.click(screen.getByRole('button', { name: 'GitHub Trending' }))
  expect(screen.getByLabelText('语言列表')).toHaveValue('Ruby')
})

it('模型保存反馈随新编辑更新，测试告警保留滚动且不会丢其它草稿', async () => {
  const confirm = vi.spyOn(window, 'confirm').mockReturnValue(false)
  settings()
  await userEvent.type(screen.getByLabelText('模型名'), 'model-name')
  await userEvent.click(screen.getByRole('button', { name: '保存模型设置' }))
  const options = formPatch.mock.calls[0][1]
  expect(options.preserveScroll).toBe(true)
  expect(screen.getByLabelText('模型名')).toBeDisabled()
  act(() => { options.onSuccess({ props: {} }); options.onFinish() })
  expect(screen.getByText('模型设置已保存；尚未测试连接')).toBeInTheDocument()
  await userEvent.type(screen.getByLabelText('模型名'), '-draft')
  expect(screen.queryByText('模型设置已保存；尚未测试连接')).not.toBeInTheDocument()
  expect(screen.getByText('模型设置有未保存的更改')).toBeInTheDocument()
  router.post.mockImplementation(() => emitRouterEvent('before', new CustomEvent('inertia:before', { cancelable: true })))
  await userEvent.click(screen.getByRole('button', { name: '发送测试告警' }))
  expect(router.post.mock.calls[0][2].preserveScroll).toBe(true)
  expect(confirm).not.toHaveBeenCalled()
  expect(screen.getByLabelText('模型名')).toHaveValue('model-name-draft')
})

it('新增等待期间输入不能改变；成功只清除当前行，列表刷新不询问离开', async () => {
  const confirm = vi.spyOn(window, 'confirm').mockReturnValue(false)
  settings()
  const rows = await editRows()
  await userEvent.type(within(rows[0]).getByLabelText('关键词'), ' other draft')
  const name = within(rows[2]).getByLabelText('名称')
  await userEvent.type(name, 'Rust')
  router.post.mockImplementation((_url, _data, options) => {
    emitRouterEvent('before', new CustomEvent('inertia:before', { cancelable: true }))
    options.onStart()
  })
  router.reload.mockImplementation(() => emitRouterEvent('before', new CustomEvent('inertia:before', { cancelable: true })))
  await userEvent.click(within(rows[2]).getByRole('button', { name: '新增' }))
  expect(name).toBeDisabled()
  await userEvent.type(name, ' overwritten')
  expect(name).toHaveValue('Rust')
  const options = router.post.mock.calls[0][2]
  act(() => { options.onSuccess({ props: { flash: {} } }); options.onFinish() })
  expect(name).toHaveValue('')
  expect((within(rows[0]).getByLabelText('关键词') as HTMLInputElement).value).toContain('other draft')
  expect(confirm).not.toHaveBeenCalled()
  const leave = new CustomEvent('inertia:before', { cancelable: true })
  emitRouterEvent('before', leave)
  expect(confirm).toHaveBeenCalledTimes(1)
  expect(leave.defaultPrevented).toBe(true)
})

it('未保存来源草稿跨挂载恢复，另一个来源记录不串值', async () => {
  setPageProps({ current_user: { email: 'one@example.com' }, errors: {}, flash: {} })
  const source = adminSourceForm({ id: 'source-a', name: 'A' })
  const view = render(<SourceForm source={source} adapters={ADAPTER_OPTIONS} />)
  await userEvent.type(screen.getByLabelText('feed 地址'), 'https://a.example/feed')
  view.unmount()
  const restored = render(<SourceForm source={source} adapters={ADAPTER_OPTIONS} />)
  expect(screen.getByLabelText('feed 地址')).toHaveValue('https://a.example/feed')
  restored.rerender(<SourceForm source={adminSourceForm({ id: 'source-b', name: 'B' })} adapters={ADAPTER_OPTIONS} />)
  expect(screen.getByLabelText('feed 地址')).toHaveValue('')
  expect(screen.getByLabelText('名称')).toHaveValue('B')
})

it('成功保存的草稿不在重新挂载后复活；长模型名能展开读取完整内容', async () => {
  const view = settings()
  const longName = 'provider/' + 'a-long-model-name-'.repeat(5)
  await userEvent.type(screen.getByLabelText('模型名'), longName)
  const details = screen.getByText('查看完整模型名').closest('details')!
  await userEvent.click(screen.getByText('查看完整模型名'))
  expect(details).toHaveAttribute('open')
  expect(within(details).getByText(longName)).toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: '保存模型设置' }))
  const options = formPatch.mock.calls[0][1]
  act(() => { options.onSuccess({ props: {} }); options.onFinish() })
  expect(sessionStorage.length).toBe(0)
  view.unmount()
  settings()
  expect(screen.getByLabelText('模型名')).toHaveValue('')
})

it('服务端基线变化也保留未提交的草稿并提示核对', async () => {
  const view = settings()
  await userEvent.type(screen.getByLabelText('模型名'), 'my unsaved model')
  view.unmount()
  render(<Show {...props} reasons={reasonsStatus({ model_name: 'another saved model' })} />)
  expect(screen.getByLabelText('模型名')).toHaveValue('my unsaved model')
  expect(screen.getByText('服务端设置已有变化，请核对恢复的草稿后保存。')).toBeInTheDocument()
})
