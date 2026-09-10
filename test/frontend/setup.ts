import '@testing-library/jest-dom/vitest'

import { cleanup } from '@testing-library/react'
import { afterEach, vi } from 'vitest'

// 整个包换成 support/inertia 里的替身，理由写在那个文件里。
vi.mock('@inertiajs/react', async () => {
  const stub = await import('./support/inertia')
  return { Link: stub.Link, usePage: stub.usePage, router: stub.router }
})

// globals: false 时 Testing Library 装不上自己的自动清理（它认的是全局 afterEach），手动挂一次
afterEach(() => {
  cleanup()
})
