import { act, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'

import Form from '@/pages/Admin/Sources/Form'
import * as admin from '@/lib/admin'
import * as inertia from '../support/inertia'
import { formPatch, formPost, setPageProps } from '../support/inertia'
import { ADAPTER_OPTIONS, adminSourceForm, testFetchResult } from '../support/props'

// 新建 / 编辑来源（R-3.2、R-3.3，画布 admin_source_form() 与 admin_source_forms()）

function show(source = adminSourceForm(), errors: Record<string, string[]> = {}) {
  const props = { source, adapters: ADAPTER_OPTIONS, daily_time: '06:00', latest_weekly_key: null }
  setPageProps({ ...props, flash: {}, errors })
  return render(<Form {...props} />)
}

afterEach(() => {
  formPost.mockClear()
  formPatch.mockClear()
  vi.restoreAllMocks()
})

describe('Admin/Sources/Form', () => {
  it('测试抓取时图标显示等待状态，成功后变为确认图形并恢复按钮', async () => {
    let resolve!: (result: ReturnType<typeof testFetchResult>) => void
    const response = new Promise<ReturnType<typeof testFetchResult>>((done) => { resolve = done })
    vi.spyOn(admin, 'testFetch').mockReturnValue(response)
    show()
    const button = screen.getByRole('button', { name: '测试抓取' })
    const path = button.querySelector('path')!
    const initial = path.getAttribute('d')

    await userEvent.click(button)
    expect(button).toBeDisabled()
    expect(button).toHaveAttribute('aria-busy', 'true')
    expect(button).toHaveTextContent('测试中…')
    await waitFor(() => expect(path.getAttribute('d')).not.toBe(initial))

    await act(async () => resolve(testFetchResult()))
    expect(button).toBeEnabled()
    expect(button).toHaveAttribute('aria-busy', 'false')
    expect(button).toHaveTextContent('测试抓取')
    await waitFor(() => expect(path).toHaveAttribute('d', 'M20 6C16.3333 9.6667 12.6667 13.3333 9 17C7.3333 15.3333 5.6667 13.6667 4 12'))
  })

  it('新建：适配器分段、RSS 字段、保存 POST', async () => {
    show()

    expect(screen.getByRole('heading', { level: 1, name: '新建来源' })).toBeInTheDocument()
    expect(screen.getByRole('group', { name: '来源类型' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'RSS/Atom' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByLabelText('feed 地址')).toBeInTheDocument()
    expect(screen.getByLabelText('时间窗口（小时）')).toBeInTheDocument()

    await userEvent.type(screen.getByLabelText('feed 地址'), 'https://hackaday.com/feed/')
    await userEvent.type(screen.getByLabelText('名称'), 'Hackaday')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(formPost).toHaveBeenCalledWith('/admin/sources', expect.any(Object))
  })

  it('周刊 RSS 没有时间窗口；HN 有榜单与分数；GitHub 有语言列表', async () => {
    show()

    await userEvent.click(screen.getByRole('button', { name: '周刊' }))
    expect(screen.queryByLabelText('时间窗口（小时）')).toBeNull()

    await userEvent.click(screen.getByRole('button', { name: 'Hacker News' }))
    expect(screen.getByRole('group', { name: '榜单' })).toBeInTheDocument()
    expect(screen.getByLabelText('最低分数')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '周刊' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'GitHub Trending' }))
    expect(screen.getByLabelText('语言列表')).toBeInTheDocument()
  })

  it('切换适配器不丢已经填好的名称与排序值', async () => {
    show()

    await userEvent.type(screen.getByLabelText('名称'), 'Hackaday')
    await userEvent.clear(screen.getByLabelText('排序值'))
    await userEvent.type(screen.getByLabelText('排序值'), '9')

    await userEvent.click(screen.getByRole('button', { name: 'Hacker News' }))

    // 断言读 lastFormData（真实 data 快照）而不是 <input> 的 DOM 值：一个受控字段的 value 一旦从
    // 字符串变成 undefined，React 不会把输入框里已经打出的字清空，toHaveValue 测不出「setData 传
    // 对象把 name/sort_order 丢了」这类缺陷（已用最小复现验证过），必须直接看真正的表单数据。
    expect(inertia.lastFormData).toMatchObject({ name: 'Hackaday', sort_order: '9', adapter: 'hacker_news' })
    expect(screen.getByLabelText('名称')).toHaveValue('Hackaday')
    expect(screen.getByLabelText('排序值')).toHaveValue(9)
  })

  it('编辑：适配器是文字，保存 PATCH', async () => {
    const { container } = show(adminSourceForm({ id: 'src-had', name: 'Hackaday', config: { feed_url: 'https://hackaday.com/feed/', count: 10, window_hours: 24 } }))

    expect(screen.getByRole('heading', { level: 1, name: '编辑来源 · Hackaday' })).toBeInTheDocument()
    expect(screen.queryByRole('group', { name: '来源类型' })).toBeNull()
    // 期头的 bottom 也是「RSS/Atom」（option.label）：限定在表单容器内找，避免撞上期头那一份
    expect(within(container.querySelector('.admin-form') as HTMLElement).getByText('RSS/Atom')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    expect(formPatch).toHaveBeenCalledWith('/admin/sources/src-had', expect.any(Object))
  })

  it('错误按字段显示', () => {
    show(adminSourceForm({ name: 'Hacker News' }), { name: ['名称已存在'], 'config.feed_url': ['必填'] })

    expect(screen.getByText('名称已存在')).toBeInTheDocument()
    expect(screen.getByText('必填')).toBeInTheDocument()
    expect(screen.getByLabelText('feed 地址')).toHaveAttribute('aria-invalid', 'true')
  })

  it('测试抓取：预览、警告、用时，名称为空时用 feed 标题', async () => {
    vi.spyOn(admin, 'testFetch').mockResolvedValue(testFetchResult())
    const { container } = show()

    await userEvent.type(screen.getByLabelText('feed 地址'), 'https://hackaday.com/feed/')
    await userEvent.click(screen.getByRole('button', { name: '测试抓取' }))

    expect(await screen.findByText('测试抓取 · 前 5 条')).toBeInTheDocument()
    // 用时/解析/丢弃这句走 Mixed（中文夹数字），文字被拆进多个 span：断言 textContent 而不是 getByText 整句
    expect(container.querySelector('.preview-head')?.textContent).toContain('用时 1.8 秒 · 解析 24 条 · 丢弃 0 条')
    expect(screen.getByText('A Mechanical Keyboard Built From Scrap Relays')).toBeInTheDocument()
    expect(screen.getByText('1 条无发布时间，已用抓取时间代替')).toBeInTheDocument()
    expect(screen.getByLabelText('名称')).toHaveValue('Hackaday')
    expect(screen.queryByText('尚未通过测试，仍可保存。')).toBeNull()
  })

  it('测试失败：错误句与「尚未通过测试，仍可保存。」', async () => {
    vi.spyOn(admin, 'testFetch').mockResolvedValue(testFetchResult({ ok: false, error: '不是有效的 RSS/Atom，请检查地址。', entries: [], parsed: 0, warnings: [] }))
    show()

    await userEvent.click(screen.getByRole('button', { name: '测试抓取' }))

    expect(await screen.findByText('不是有效的 RSS/Atom，请检查地址。')).toBeInTheDocument()
    expect(screen.getByText('尚未通过测试，仍可保存。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '保存' })).toBeEnabled()
  })
  it('编辑配置使预览失效，进行中的旧结果不会覆盖新配置', async () => {
    let resolve!: (value: ReturnType<typeof testFetchResult>) => void
    vi.spyOn(admin, 'testFetch').mockImplementation(() => new Promise((done) => { resolve = done }))
    show()
    await userEvent.click(screen.getByRole('button', { name: '测试抓取' }))
    await userEvent.type(screen.getByLabelText('名称'), '新名称')
    await act(async () => resolve(testFetchResult()))
    expect(screen.queryByText('测试抓取 · 前 5 条')).toBeNull()
    expect(screen.getByText('配置已变化，请重新测试')).toBeInTheDocument()
    expect(screen.getByLabelText('名称')).toHaveValue('新名称')
    vi.spyOn(admin, 'testFetch').mockResolvedValue(testFetchResult())
    await userEvent.click(screen.getByRole('button', { name: '测试抓取' }))
    expect(await screen.findByText('测试抓取 · 前 5 条')).toBeInTheDocument()
    await userEvent.clear(screen.getByLabelText('条数上限'))
    expect(screen.queryByText('测试抓取 · 前 5 条')).toBeNull()
  })

  it('固定仓库可复制但不能编辑', async () => {
    show()
    await userEvent.click(screen.getByRole('button', { name: '阮一峰周刊' }))
    const repo = screen.getByLabelText('仓库')
    expect(repo).toHaveAttribute('readonly')
    expect(repo).not.toBeDisabled()
  })

  it('仅脏表单拦截离开，取消离开保留内容，保存不二次询问', async () => {
    const confirm = vi.spyOn(window, 'confirm').mockReturnValue(false)
    show(adminSourceForm({ id: 'src-had', name: 'Hackaday', config: { feed_url: 'https://hackaday.com/feed/', count: 10, window_hours: 24 } }))
    const clean = new Event('beforeunload', { cancelable: true })
    window.dispatchEvent(clean)
    expect(clean.defaultPrevented).toBe(false)
    await userEvent.type(screen.getByLabelText('名称'), ' draft')
    const dirty = new Event('beforeunload', { cancelable: true })
    window.dispatchEvent(dirty)
    expect(dirty.defaultPrevented).toBe(true)
    const before = new CustomEvent('inertia:before', { cancelable: true })
    inertia.emitRouterEvent('before', before)
    expect(before.defaultPrevented).toBe(true)
    expect(confirm).toHaveBeenCalledTimes(1)
    formPatch.mockImplementationOnce(() => inertia.emitRouterEvent('before', new CustomEvent('inertia:before', { cancelable: true })))
    await userEvent.click(screen.getByRole('button', { name: '保存' }))
    expect(confirm).toHaveBeenCalledTimes(1)
  })

})
