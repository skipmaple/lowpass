import { render } from '@testing-library/react'
import { StrictMode } from 'react'
import type { Page } from '@inertiajs/core'
import { expect, it, vi } from 'vitest'
import Layout from '@/components/Layout'
import Login from '@/pages/Login/Show'
import { pageTurn } from '@/lib/pageTurn'
import { emitRouterEvent, setPage } from '../support/inertia'

it('真实 Layout 与 Login 在首次挂载及跨祖先重挂同步提交；StrictMode cleanup 不删除 token', async () => {
  for (const screen of [<Layout footer={false}>正文</Layout>, <Login providers={[]} next={null} />]) {
    const page = { component: 'Test', url: '/test', props: {}, version: null } as Page
    setPage(page)
    emitRouterEvent('beforeUpdate', new CustomEvent('beforeUpdate', { detail: { page } }))
    let finish!: () => void
    const transition = {
      ready: new Promise(() => {}), updateCallbackDone: new Promise(() => {}),
      finished: new Promise<void>((resolve) => { finish = resolve }), skipTransition: vi.fn(),
    } as unknown as ViewTransition
    ;(pageTurn('forward') as (t: ViewTransition) => void)(transition)
    const view = render(<StrictMode>{screen}</StrictMode>)
    expect(document.documentElement.dataset.vt).toBe('new')
    view.unmount()
    expect(document.documentElement.dataset.vt).toBe('new')
    finish()
    await transition.finished
    expect(document.documentElement.dataset.vt).toBeUndefined()
  }
})
