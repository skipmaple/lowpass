import { Link, router, usePage } from '@inertiajs/react'
import { useEffect, useId, useRef, useState } from 'react'
import type * as React from 'react'

import Icon from '@/components/Icon'
import { ADMIN_SOURCES, DAILY_LATEST, SEARCH, SESSION, SETTINGS, WEEKLY_ARCHIVE } from '@/lib/paths'
import { Mixed } from '@/lib/typeset'
import type { CurrentUser, SharedProps } from '@/types/lowpass'

// 报头黑带：80px 墨底，LOWPASS 用品牌字 40px 纸色，导航文楷 15，右侧搜索图标与账户位。
// 尺寸（高度、边距、品牌字号、间距）在 tokens.css 的 .masthead* 里，手机版由那里的 @media 收窄。
// 图标由 Lucide + Morphicons 渲染（在黑带上用纸色描边），开合时在原位变形。
//
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
      style={{
        fontFamily: 'var(--font-cjk)',
        fontSize: 'var(--fs-15)',
        color: 'var(--paper)',
        lineHeight: 1,
        paddingBottom: 2,
        whiteSpace: 'nowrap',
        opacity: current ? 1 : 0.72,
        borderBottom: current ? '1px solid var(--paper)' : '1px solid transparent',
      }}
    >
      {label}
    </Link>
  )
}

// 头像菜单（R-8.2，画布 pages_front3.py 的 menu_sheet()）：32px 圆是按钮，点开右对齐 220px 纸卡，
// 顶部等宽邮箱（没邮箱用显示名），「设置」「管理」（仅 admin，指向后台的信息源页）「登出」。
// Escape、点卡外、选中任一项都关闭；打开时焦点进第一项。画布那张卡带阴影，这里不取：
// 设计规则说纸面里不许有阴影，1px 墨线足够分层（设计 L1）。
function AccountMenu({ user }: { user: CurrentUser }) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)
  const buttonRef = useRef<HTMLButtonElement>(null)
  const menuId = useId()

  useEffect(() => {
    if (!open) return
    rootRef.current?.querySelector<HTMLElement>('[role="menuitem"]')?.focus()

    // WAI-ARIA menu button 模式：Escape 关掉的是键盘用户自己进来的菜单，得把焦点还给触发它的按钮，
    // 不然聚焦的菜单项一卸载，焦点就掉回 <body>，键盘用户在页面上的位置就丢了。点卡外关闭不这样——
    // 读者点哪儿是读者的选择，不该抢焦点；选中某一项关闭则是导航/登出接管，也不用管。
    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setOpen(false)
        buttonRef.current?.focus()
      }
    }
    function onPointer(event: MouseEvent) {
      if (rootRef.current && !rootRef.current.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('keydown', onKey)
    document.addEventListener('mousedown', onPointer)
    return () => {
      document.removeEventListener('keydown', onKey)
      document.removeEventListener('mousedown', onPointer)
    }
  }, [open])

  function close() {
    setOpen(false)
  }

  return (
    <div className="account" ref={rootRef}>
      <button
        ref={buttonRef}
        type="button"
        className="account-button"
        aria-label="账户"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => setOpen((value) => !value)}
      >
        <Icon name={open ? 'x' : 'user'} size={15} color="var(--paper)" />
        {/* 头像覆盖人像占位，展开时淡出以露出关闭图标；SVG 始终挂载，才能连续变形。
            provider 头像用 referrerPolicy 拦住 Referer，避免泄露读者正在看的页面。 */}
        {user.avatar_url ? (
          <img src={user.avatar_url} alt="" className={`account-avatar${open ? ' account-avatar--open' : ''}`} referrerPolicy="no-referrer" />
        ) : null}
      </button>
      {open ? (
        <div className="menu-card" role="menu" id={menuId}>
          {/* role="menu" 的孩子只能是 menuitem，顶部这行邮箱不是；role="none" 把它从菜单结构里摘出去 */}
          <div className="menu-head" role="none">
            <Mixed text={user.email ?? user.display_name} size="var(--fs-12)" color="var(--ink2)" />
          </div>
          <Link role="menuitem" className="menu-item" href={SETTINGS} onClick={close}>
            设置
          </Link>
          {user.admin ? (
            <Link role="menuitem" className="menu-item" href={ADMIN_SOURCES} onClick={close}>
              管理
            </Link>
          ) : null}
          <button
            type="button"
            role="menuitem"
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

const SEARCH_STYLE: React.CSSProperties = { display: 'inline-flex' }
const ACCOUNT_STYLE: React.CSSProperties = {
  width: 32,
  height: 32,
  flex: 'none',
  borderRadius: '50%',
  border: '1px solid var(--paper)',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
}

export default function Masthead({ active, dailyHref = DAILY_LATEST, weeklyHref = WEEKLY_ARCHIVE, searchHref = SEARCH }: MastheadProps) {
  const user = usePage<Partial<SharedProps>>().props.current_user ?? null

  return (
    <header className="masthead">
      <div className="masthead-left">
        <Link href={dailyHref} className="masthead-brand">
          lowpass
        </Link>
        <nav className="masthead-nav">
          <Nav href={dailyHref} label="日刊" current={active === 'daily'} />
          <Nav href={weeklyHref} label="周刊" current={active === 'weekly'} />
        </nav>
      </div>

      <div className="masthead-actions">
        <Link href={searchHref} aria-label="搜索" style={SEARCH_STYLE}>
          <Icon name="search" size={20} color="var(--paper)" />
        </Link>
        {user ? (
          <AccountMenu user={user} />
        ) : (
          <span aria-disabled="true" style={ACCOUNT_STYLE}>
            <Icon name="user" size={15} color="var(--paper)" />
          </span>
        )}
      </div>
    </header>
  )
}
