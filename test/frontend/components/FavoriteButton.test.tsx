import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import FavoriteButton from '@/components/FavoriteButton'
import { FavoritesProvider } from '@/lib/favorites'
import { router } from '../support/inertia'

// 条目上的书签与它背后的 FavoritesProvider（PRD 5.10、6.3，D30）：点一下立刻换态，请求走 fetch；
// 成功不出提示，失败回滚并提示附录 B 的句子；请求结束把最新的列表写回 Inertia 当前页。

const HASH = 'a'.repeat(64)
const TITLE = 'Show HN: A terminal log viewer written in Rust'
const ADD = `收藏：${TITLE}`
const REMOVE = `取消收藏：${TITLE}`

const ok = (body: Record<string, string> = {}, status = 201) => ({ ok: true, status, json: async () => body })
const rejected = (status: number) => ({ ok: false, status, json: async () => ({}) })

function tree(favorites: string[]) {
  return (
    <FavoritesProvider favorites={favorites}>
      <FavoriteButton itemId="itm-hn-1" urlHash={HASH} title={TITLE} />
    </FavoritesProvider>
  )
}

function mount(favorites: string[] = []) {
  return render(tree(favorites))
}

function stubFetch(response: unknown) {
  const fetchMock = vi.fn().mockResolvedValue(response)
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="tok-123">'
})

afterEach(() => {
  document.head.innerHTML = ''
  vi.unstubAllGlobals()
  router.replaceProp.mockClear()
  router.visit.mockClear()
  window.history.replaceState({}, '', '/')
})

describe('FavoriteButton', () => {
  it('页面没有套 FavoritesProvider 时不渲染', () => {
    const { container } = render(<FavoriteButton itemId="itm-hn-1" urlHash={HASH} title={TITLE} />)

    expect(container).toBeEmptyDOMElement()
  })

  it('未收藏是描线书签，名字带条目标题；已收藏带 data-on（实心）', () => {
    const { unmount } = mount()
    expect(screen.getByRole('button', { name: ADD })).not.toHaveAttribute('data-on')
    expect(screen.getByRole('button', { name: ADD })).toHaveClass('favorite-button')
    unmount()

    mount([HASH])
    expect(screen.getByRole('button', { name: REMOVE })).toHaveAttribute('data-on')
  })

  it('className 追加在 favorite-button 后面', () => {
    render(
      <FavoritesProvider favorites={[]}>
        <FavoriteButton className="item-mark" itemId="itm-hn-1" urlHash={HASH} title={TITLE} />
      </FavoritesProvider>,
    )

    expect(screen.getByRole('button', { name: ADD })).toHaveClass('favorite-button', 'item-mark')
  })

  // AC-10.1：点一下就换态，不等服务端；请求带条目 id 与 CSRF 令牌
  it('点一下收藏：立刻换成已收藏，POST 条目 id，结束后把列表写回当前页', async () => {
    const fetchMock = stubFetch(ok({ url_hash: HASH }))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(screen.getByRole('button', { name: REMOVE })).toHaveAttribute('data-on')
    expect(fetchMock).toHaveBeenCalledTimes(1)
    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe('/favorites')
    expect(init.method).toBe('POST')
    expect(init.body).toBe(JSON.stringify({ item_id: 'itm-hn-1' }))
    expect(init.headers['X-CSRF-Token']).toBe('tok-123')
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', [HASH]))
    // R-10.5 成功不出提示
    expect(screen.queryByRole('status')).toBeNull()
  })

  it('再点一下取消：DELETE /favorites/<url_hash>，列表写回空', async () => {
    const fetchMock = stubFetch(ok({ undo: 'signed-token' }, 200))
    mount([HASH])

    await userEvent.click(screen.getByRole('button', { name: REMOVE }))

    expect(screen.getByRole('button', { name: ADD })).not.toHaveAttribute('data-on')
    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe(`/favorites/${HASH}`)
    expect(init.method).toBe('DELETE')
    expect(init.body).toBeUndefined()
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', []))
  })

  // AC-10.9
  it('收藏没保存上：回到未收藏，提示附录 B 那一句', async () => {
    stubFetch(rejected(500))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(await screen.findByText('收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: ADD })).not.toHaveAttribute('data-on')
    expect(router.replaceProp).toHaveBeenCalledWith('favorites', [])
  })

  it('断网（fetch 直接 reject）同样回滚并提示', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(await screen.findByText('收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
  })

  it('取消没保存上：回到已收藏，提示「取消收藏没有保存，请重试。」', async () => {
    stubFetch(rejected(500))
    mount([HASH])

    await userEvent.click(screen.getByRole('button', { name: REMOVE }))

    expect(await screen.findByText('取消收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: REMOVE })).toHaveAttribute('data-on')
  })

  // AC-10.11
  it('限流 429：回滚并提示限流那一句', async () => {
    stubFetch(rejected(429))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(await screen.findByText('操作过于频繁，请稍后再试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
  })

  it('同一句失败提示不叠两条', async () => {
    stubFetch(rejected(500))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))
    await screen.findByText('收藏没有保存，请重试。')
    await userEvent.click(screen.getByRole('button', { name: ADD }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledTimes(2))

    expect(screen.getAllByText('收藏没有保存，请重试。')).toHaveLength(1)
  })

  // PRD 5.10 边界：会话过期不保存，去登录页并带上当前地址，不提示失败
  it('会话过期 401：回滚，去登录页并带上当前地址', async () => {
    window.history.replaceState({}, '', '/daily/2026-09-08?source=src-hn')
    stubFetch(rejected(401))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    await waitFor(() => expect(router.visit).toHaveBeenCalledWith('/login?next=%2Fdaily%2F2026-09-08%3Fsource%3Dsrc-hn'))
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
    expect(screen.queryByText('收藏没有保存，请重试。')).toBeNull()
  })

  it('请求还在路上时再点不重复发', async () => {
    let settle: (value: unknown) => void = () => undefined
    const fetchMock = vi.fn().mockReturnValue(new Promise((resolve) => { settle = resolve }))
    vi.stubGlobal('fetch', fetchMock)
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))
    await userEvent.click(screen.getByRole('button', { name: REMOVE }))

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(screen.getByRole('button', { name: REMOVE })).toBeInTheDocument()

    settle(ok({ url_hash: HASH }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', [HASH]))
  })

  it('读者已经离开这一页，请求回来后不再写当前页的 props', async () => {
    let settle: (value: unknown) => void = () => undefined
    vi.stubGlobal('fetch', vi.fn().mockReturnValue(new Promise((resolve) => { settle = resolve })))
    const view = mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))
    view.unmount()
    settle(ok({ url_hash: HASH }))
    await new Promise((resolve) => setTimeout(resolve, 0))

    expect(router.replaceProp).not.toHaveBeenCalled()
  })

  // 换期、生成中的轮询、历史恢复都会带来一份新的 favorites
  it('服务端给了新的列表就以它为准', () => {
    const view = mount()
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()

    view.rerender(tree([HASH]))
    expect(screen.getByRole('button', { name: REMOVE })).toBeInTheDocument()

    view.rerender(tree([]))
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
  })
})
