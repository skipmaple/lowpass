import { act, render } from '@testing-library/react'
import { useLayoutEffect } from 'react'
import type { Page } from '@inertiajs/core'
import { expect, it, vi } from 'vitest'

vi.unmock('@inertiajs/react')
import { App, router, usePage } from '@inertiajs/react'
import Layout from '@/components/Layout'
import Login from '@/pages/Login/Show'
import { pageTurn } from '@/lib/pageTurn'

it('锁定 adapter 的真实 swap 将同一个 Page 交给首次挂载的 layout effect，早于 swap promise 完成', async () => {
  let swap!: Parameters<typeof router.init>[0]['swapComponent']
  vi.spyOn(router, 'init').mockImplementation((options) => { swap = options.swapComponent })
  const seen: Page[] = []
  function Probe() {
    const page = usePage()
    useLayoutEffect(() => { seen.push(page) }, [page])
    return <Layout footer={false}>正文</Layout>
  }
  function OtherAncestor() { return <section><Probe /></section> }
  const initial = { component: 'Probe', url: '/', props: {}, version: null } as Page
  render(<App initialPage={initial} initialComponent={Probe} resolveComponent={() => Probe} />)
  for (const component of [OtherAncestor, () => <Login providers={[]} next={null} />]) {
    const targetPage = { ...initial, url: '/changed' }
    document.dispatchEvent(new CustomEvent('inertia:beforeUpdate', { detail: { page: targetPage } }))
    let finish!: () => void
    const transition = { ready: new Promise(() => {}), updateCallbackDone: new Promise(() => {}),
      finished: new Promise<void>((resolve) => { finish = resolve }), skipTransition: vi.fn() } as unknown as ViewTransition
    ;(pageTurn('back') as (t: ViewTransition) => void)(transition)
    let settled = false
    await act(async () => {
      const promise = swap({ component, page: targetPage, preserveState: false, initialRender: false })
      expect(document.documentElement.dataset.vt).toBe('new')
      if (component === OtherAncestor) expect(seen[seen.length - 1]).toBe(targetPage)
      expect(settled).toBe(false)
      await promise.then(() => { settled = true })
    })
    finish()
    await transition.finished
  }
  vi.restoreAllMocks()
})
