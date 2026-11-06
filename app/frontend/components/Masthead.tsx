import { Link, router, usePage } from '@inertiajs/react'
import { useCallback, useEffect, useId, useRef, useState } from 'react'

import Icon from '@/components/Icon'
import IssueDate from '@/components/IssueDate'
import ThemePicker from '@/components/ThemePicker'
import { ADMIN_SOURCES, DAILY_LATEST, FAVORITES, SEARCH, SESSION, SETTINGS, latestWeeklyHref } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { CurrentUser, DailyIssue, SharedProps } from '@/types/lowpass'

// 三主题共用品牌、主导航与账户行为；构图和响应式边界由 themes.css 负责。
// 账户位读 inertia_share 的 current_user（P2-①）：有人就是头像菜单按钮（R-8.2），没有（类型上允许，
// 实际登录墙后每页都有）就是同样外观的非交互占位。
export type MastheadProps = {
  active?: 'daily' | 'weekly'
  dailyHref?: string
  weeklyHref?: string
  searchHref?: string
}

function Nav({ href, label, current }: { href: string; label: string; current: boolean }) {
  return (
    <Link
      href={href}
      aria-current={current ? 'page' : undefined}
      className="primary-nav-link"
    >
      {label}
    </Link>
  )
}

function AccountAvatar({ url, open }: { url: string; open: boolean }) {
  const [failed, setFailed] = useState(false)

  return failed ? null : (
    <img src={url} alt="" className={`account-avatar${open ? ' account-avatar--open' : ''}`} referrerPolicy="no-referrer" onError={() => setFailed(true)} />
  )
}

// 账户菜单保留真实权限入口。Escape、点卡外、选中项目关闭；打开时焦点进入菜单。
function AccountMenu({ user, open, onOpenChange }: { user: CurrentUser; open: boolean; onOpenChange: (open: boolean) => void }) {
  const rootRef = useRef<HTMLDivElement>(null)
  const menuId = useId()
  const focusLast = useRef(false)

  useEffect(() => {
    if (!open) return
    const items = rootRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]')
    if (items?.length) items[focusLast.current ? items.length - 1 : 0].focus()
    focusLast.current = false

    let tabClose: ReturnType<typeof setTimeout> | undefined
    function onKey(event: KeyboardEvent) {
      const items = Array.from(rootRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? [])
      const index = items.indexOf(document.activeElement as HTMLElement)
      if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
        event.preventDefault()
        const next = event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1 : (index + (event.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length
        items[next]?.focus()
      }
      // 菜单项由方向键遍历；先让原生 Tab 把焦点送到菜单外，再卸载面板。
      if (event.key === 'Tab') tabClose = setTimeout(() => onOpenChange(false), 0)
    }
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('keydown', onKey)
      clearTimeout(tabClose)
    }
  }, [open, onOpenChange])

  function close() {
    onOpenChange(false)
  }

  return (
    <div className="account" ref={rootRef}>
      <button
        type="button"
        className="account-button"
        aria-label="账户"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => onOpenChange(!open)}
        onKeyDown={(event) => {
          if (!open && (event.key === 'ArrowDown' || event.key === 'ArrowUp')) {
            event.preventDefault()
            // 打开后可能立即挂上 document 监听；本次按键已处理，不能再冒泡过去移动一次。
            event.stopPropagation()
            focusLast.current = event.key === 'ArrowUp'
            onOpenChange(true)
          }
        }}
      >
        <Icon name={open ? 'x' : 'user'} size={15} color="currentColor" />
        {/* 头像覆盖人像占位，展开时淡出以露出关闭图标。
            provider 头像用 referrerPolicy 拦住 Referer，避免泄露读者正在看的页面。 */}
        {user.avatar_url ? (
          <AccountAvatar key={user.avatar_url} url={user.avatar_url} open={open} />
        ) : null}
      </button>
      {open ? (
        <div className="menu-card" role="menu" id={menuId}>
          {/* role="menu" 的孩子只能是 menuitem，顶部这行邮箱不是；role="none" 把它从菜单结构里摘出去 */}
          <div className="menu-head" role="none">
            <Mixed text={user.email ?? user.display_name} size="var(--fs-12)" color="var(--ink2)" />
          </div>
          <Link role="menuitem" tabIndex={-1} className="menu-item" href={SETTINGS} onClick={close}>
            账户信息
          </Link>
          <Link role="menuitem" tabIndex={-1} className="menu-item" href={FAVORITES} onClick={close}>
            收藏
          </Link>
          {user.admin ? (
            <Link role="menuitem" tabIndex={-1} className="menu-item" href={ADMIN_SOURCES} onClick={close}>
              管理
            </Link>
          ) : null}
          <button
            type="button"
            role="menuitem"
            tabIndex={-1}
            className="menu-item"
            onClick={() => {
              close()
              router.delete(SESSION)
            }}
          >
            登出
          </button>
        </div>
      ) : null}
    </div>
  )
}

function MastheadActions({ user }: { user: CurrentUser | null }) {
  const [openMenu, setOpenMenu] = useState<'theme' | 'account' | null>(null)
  const rootRef = useRef<HTMLDivElement>(null)
  const themePanelId = useId()
  const changeAccountOpen = useCallback((open: boolean) => setOpenMenu(open ? 'account' : null), [])

  useEffect(() => {
    if (!openMenu) return
    const menuRoot = rootRef.current?.querySelector(openMenu === 'theme' ? '.theme-menu' : '.account')
    const trigger = menuRoot?.querySelector<HTMLElement>(openMenu === 'theme' ? 'summary' : '.account-button')

    function closeOutside(event: PointerEvent | FocusEvent) {
      if (event.target instanceof Node && !menuRoot?.contains(event.target)) setOpenMenu(null)
    }
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        event.preventDefault()
        setOpenMenu(null)
        trigger?.focus()
      }
    }
    // 一个开合状态同时服务鼠标、触屏和键盘；点外关闭不抢走用户刚选的焦点。
    document.addEventListener('pointerdown', closeOutside)
    document.addEventListener('focusin', closeOutside)
    document.addEventListener('keydown', closeOnEscape)
    return () => {
      document.removeEventListener('pointerdown', closeOutside)
      document.removeEventListener('focusin', closeOutside)
      document.removeEventListener('keydown', closeOnEscape)
    }
  }, [openMenu])

  return (
    <div className="masthead-actions" ref={rootRef}>
      <details className="theme-menu" open={openMenu === 'theme'}>
        <summary
          aria-label="切换阅读主题"
          aria-expanded={openMenu === 'theme'}
          aria-controls={themePanelId}
          onClick={(event) => {
            event.preventDefault()
            setOpenMenu((current) => current === 'theme' ? null : 'theme')
          }}
        >
          <Icon name="sun" size={18} />
        </summary>
        <div className="theme-menu-panel" id={themePanelId}><ThemePicker /></div>
      </details>
      {user ? <AccountMenu user={user} open={openMenu === 'account'} onOpenChange={changeAccountOpen} /> : <span className="account-placeholder" aria-disabled="true" aria-label="未登录"><Icon name="user" size={18} /></span>}
    </div>
  )
}

export default function Masthead({ active, dailyHref = DAILY_LATEST, weeklyHref, searchHref = SEARCH }: MastheadProps) {
  const page = usePage<Partial<SharedProps> & { latest_weekly_key?: string | null; issue?: DailyIssue }>()
  const props = page.props
  const user = props.current_user ?? null
  const admin = page.component.startsWith('Admin/')
  const daily = page.component === 'Daily/Show'
  const moduleName = admin ? '管理' : page.component.startsWith('Favorites/') ? '收藏' : page.component.startsWith('Search/') ? '搜索' : page.component.startsWith('Settings/') ? '账户' : page.component.startsWith('Weekly/') ? '周刊' : '日刊'
  const selected = active ?? (page.component.startsWith('Daily/') ? 'daily' : page.component.startsWith('Weekly/') ? 'weekly' : undefined)

  return (
    <header className={`site-header${admin ? ' site-header--admin' : ''}`}>
      <div className="publication-mast">
        <Link href={dailyHref} className="publication-brand" aria-label="Lowpass 首页">LOWPASS</Link>
        <div className="publication-context">
          {daily && props.issue ? <IssueDate issue={props.issue} /> : <span className="publication-module">{moduleName}</span>}
        </div>
      </div>
      <div className="masthead">
        <Link href={dailyHref} className="masthead-monogram" aria-label="Lowpass 首页">LP</Link>
        {admin ? <Link className="return-reading" href={dailyHref}>返回阅读 <Icon name="arrow-up-right" size={14} /></Link> : (
          <nav className="masthead-nav" aria-label="主导航">
            <Nav href={dailyHref} label="日刊" current={selected === 'daily'} />
            <Nav href={weeklyHref ?? latestWeeklyHref(props.latest_weekly_key ?? null)} label="周刊" current={selected === 'weekly'} />
            <Nav href={FAVORITES} label="收藏" current={page.component.startsWith('Favorites/')} />
            <Nav href={searchHref} label="搜索" current={page.component.startsWith('Search/')} />
          </nav>
        )}
        <MastheadActions user={user} />
      </div>
    </header>
  )
}
