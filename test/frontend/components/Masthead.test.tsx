import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'

import Masthead from '@/components/Masthead'
import { router, setPageProps } from '../support/inertia'
import { currentUser } from '../support/props'

// 报头黑带。搜索入口指向 /search（D21）；账户（F-1）读 inertia_share 的 current_user（P2-①）。

afterEach(() => {
  setPageProps({})
  router.delete.mockClear()
})

describe('Masthead 导航', () => {
  it('刊名与两条导航指向日刊最新一期与周刊归档', () => {
    setPageProps({})
    render(<Masthead />)

    expect(screen.getByRole('link', { name: 'lowpass' })).toHaveAttribute('href', '/')
    expect(screen.getByRole('link', { name: '日刊' })).toHaveAttribute('href', '/')
    expect(screen.getByRole('link', { name: '周刊' })).toHaveAttribute('href', '/weekly')
  })

  it('当前栏目标 aria-current', () => {
    setPageProps({})
    const { unmount } = render(<Masthead active="daily" />)
    expect(screen.getByRole('link', { name: '日刊' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '周刊' })).not.toHaveAttribute('aria-current')
    unmount()

    render(<Masthead active="weekly" />)
    expect(screen.getByRole('link', { name: '周刊' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: '日刊' })).not.toHaveAttribute('aria-current')
  })

  it('哪一栏都不高亮时两条都不带 aria-current', () => {
    setPageProps({})
    render(<Masthead />)

    expect(screen.getByRole('link', { name: '日刊' })).not.toHaveAttribute('aria-current')
    expect(screen.getByRole('link', { name: '周刊' })).not.toHaveAttribute('aria-current')
  })
})

describe('Masthead 搜索与账户', () => {
  it('账户菜单开合时在原位置变为关闭图标，再恢复人像', async () => {
    setPageProps({ current_user: currentUser({ avatar_url: null }) })
    render(<Masthead />)
    const button = screen.getByRole('button', { name: '账户' })
    const path = button.querySelector('path')!
    const initial = path.getAttribute('d')

    await userEvent.click(button)
    await waitFor(() => expect(path).toHaveAttribute('d', 'M18 6C14 10 10 14 6 18M6 6C10 10 14 14 18 18'))
    await userEvent.keyboard('{Escape}')
    await waitFor(() => expect(path).toHaveAttribute('d', initial!))
    expect(button).toHaveFocus()
  })

  // D21：搜索入口是链接与图标，搜索框只在搜索页
  it('搜索图标默认指向 /search', () => {
    setPageProps({})
    render(<Masthead />)

    expect(screen.getByRole('link', { name: '搜索' })).toHaveAttribute('href', '/search')
  })

  it('没有当前用户时账户位是占位，不是按钮', () => {
    setPageProps({})
    const { container } = render(<Masthead />)

    expect(container.querySelectorAll('.masthead-actions [aria-disabled="true"]')).toHaveLength(1)
    expect(screen.queryByRole('button', { name: '账户' })).toBeNull()
  })

  it('有当前用户时账户位是按钮，点开菜单：邮箱、设置、登出；成员没有管理', async () => {
    setPageProps({ current_user: currentUser() })
    render(<Masthead />)

    const button = screen.getByRole('button', { name: '账户' })
    expect(button).toHaveAttribute('aria-expanded', 'false')
    expect(screen.queryByRole('menu')).toBeNull()

    await userEvent.click(button)

    expect(button).toHaveAttribute('aria-expanded', 'true')
    const menu = screen.getByRole('menu')
    expect(within(menu).getByText('drew@example.com')).toBeInTheDocument()
    expect(within(menu).getByRole('menuitem', { name: '账户信息' })).toHaveAttribute('href', '/settings')
    expect(within(menu).queryByRole('menuitem', { name: '管理' })).toBeNull()
    expect(within(menu).getByRole('menuitem', { name: '登出' })).toBeInTheDocument()
  })

  it('admin 多一项管理，指向 /admin/sources', async () => {
    setPageProps({ current_user: currentUser({ admin: true }) })
    render(<Masthead />)

    await userEvent.click(screen.getByRole('button', { name: '账户' }))

    expect(screen.getByRole('menuitem', { name: '管理' })).toHaveAttribute('href', '/admin/sources')
  })

  it('登出走 DELETE /session', async () => {
    setPageProps({ current_user: currentUser() })
    render(<Masthead />)

    await userEvent.click(screen.getByRole('button', { name: '账户' }))
    await userEvent.click(screen.getByRole('menuitem', { name: '登出' }))

    expect(router.delete).toHaveBeenCalledWith('/session')
    expect(screen.queryByRole('menu')).toBeNull()
  })

  it('Escape 与点卡外都关闭菜单', async () => {
    setPageProps({ current_user: currentUser() })
    render(<Masthead />)
    const button = screen.getByRole('button', { name: '账户' })

    await userEvent.click(button)
    await userEvent.keyboard('{Escape}')
    expect(screen.queryByRole('menu')).toBeNull()

    await userEvent.click(button)
    await userEvent.click(document.body)
    expect(screen.queryByRole('menu')).toBeNull()
  })

  it('Escape 关闭后焦点回到头像按钮；打开时焦点进第一项', async () => {
    setPageProps({ current_user: currentUser() })
    render(<Masthead />)
    const button = screen.getByRole('button', { name: '账户' })

    await userEvent.click(button)
    expect(screen.getByRole('menuitem', { name: '账户信息' })).toHaveFocus()

    await userEvent.keyboard('{Escape}')
    expect(button).toHaveFocus()
  })

  // 头像是 provider 的外链图：加载它别把读者在看哪一页捎给 Google / GitHub
  it('没有邮箱时菜单顶部写显示名；有头像时圆里是图片，且不带 Referer', async () => {
    setPageProps({ current_user: currentUser({ email: null, display_name: '客人', avatar_url: 'https://avatars.example/a.png' }) })
    const { container } = render(<Masthead />)

    expect(container.querySelector('.account-avatar')).toHaveAttribute('src', 'https://avatars.example/a.png')
    expect(container.querySelector('.account-avatar')).toHaveAttribute('referrerpolicy', 'no-referrer')
    await userEvent.click(screen.getByRole('button', { name: '账户' }))
    expect(within(screen.getByRole('menu')).getByText('客人')).toBeInTheDocument()
  })

  // role="menu" 的孩子只能是 menuitem：顶部那行邮箱不是，得标 role="none" 摘出去
  it('菜单顶部那行邮箱标 role="none"，不冒充菜单项', async () => {
    setPageProps({ current_user: currentUser() })
    render(<Masthead />)

    await userEvent.click(screen.getByRole('button', { name: '账户' }))
    const menu = screen.getByRole('menu')

    expect(menu.querySelector('.menu-head')).toHaveAttribute('role', 'none')
    expect(within(menu).getAllByRole('menuitem').map((item) => item.textContent)).toEqual(['账户信息', '登出'])
  })

  it('菜单卡没有阴影（设计 L1）', async () => {
    setPageProps({ current_user: currentUser() })
    render(<Masthead />)

    await userEvent.click(screen.getByRole('button', { name: '账户' }))

    expect(screen.getByRole('menu').getAttribute('style') ?? '').not.toMatch(/box-shadow/)
  })
})

 it('菜单支持方向键与 Home/End，Escape 返回账户按钮', async () => {
   setPageProps({ current_user: currentUser({ admin: true }) })
   render(<Masthead />)
   const button = screen.getByRole('button', { name: '账户' })
   await userEvent.click(button)
   await userEvent.keyboard('{ArrowDown}')
   expect(screen.getByRole('menuitem', { name: '管理' })).toHaveFocus()
   await userEvent.keyboard('{End}')
   expect(screen.getByRole('menuitem', { name: '登出' })).toHaveFocus()
   await userEvent.keyboard('{ArrowDown}')
   expect(screen.getByRole('menuitem', { name: '账户信息' })).toHaveFocus()
   await userEvent.keyboard('{ArrowUp}')
   expect(screen.getByRole('menuitem', { name: '登出' })).toHaveFocus()
   await userEvent.keyboard('{Home}{Escape}')
   expect(button).toHaveFocus()
 })
 it('周刊导航直接进入最新可读周刊', () => {
   setPageProps({ latest_weekly_key: '2026-W36' })
   render(<Masthead />)
   expect(screen.getByRole('link', { name: '周刊' })).toHaveAttribute('href', '/weekly/2026-W36')
 })
it('账户按钮的上下方向键打开首尾菜单项', async () => {
 setPageProps({ current_user: currentUser({ admin: true }) })
 render(<Masthead />)
 const button = screen.getByRole('button', { name: '账户' })
 button.focus()
 await userEvent.keyboard('{ArrowUp}')
 expect(screen.getByRole('menuitem', { name: '登出' })).toHaveFocus()
 await userEvent.keyboard('{Escape}{ArrowDown}')
 expect(screen.getByRole('menuitem', { name: '账户信息' })).toHaveFocus()
})
