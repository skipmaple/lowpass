import { render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it } from 'vitest'

import { DAILY_LATEST } from '@/lib/paths'
import Forbidden from '@/pages/Errors/Forbidden'
import NotFound from '@/pages/Errors/NotFound'
import { setPageProps } from '../support/inertia'

// 404 / 403（附录 B）：与栏级失败态同一装置——1px 框里一幅木刻「缺页」，一句事实，一个动作（设计说明 2026-10-14 C2）

beforeEach(() => {
  setPageProps({ daily_time: '06:00', latest_weekly_key: null })
})

describe.each([
  ['404', NotFound, '这一页不存在。'],
  ['403', Forbidden, '你没有权限访问这个页面。'],
])('%s', (_code, Page, sentence) => {
  it('缺页插图在 1px 框里、对读屏隐藏；一句事实；一个回首页的动作', () => {
    const { container } = render(<Page />)

    expect(screen.getByRole('heading', { level: 1, name: sentence })).toBeInTheDocument()
    expect(container.querySelector('.error-art svg')).toHaveAttribute('aria-hidden', 'true')
    expect(screen.getByRole('link', { name: '回到首页' })).toHaveAttribute('href', DAILY_LATEST)
  })
})
