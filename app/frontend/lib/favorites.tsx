import { router } from '@inertiajs/react'
import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, useState } from 'react'
import type * as React from 'react'

import { Toasts, useToasts } from '@/components/Toast'
import { FAVORITES, favoriteHref, loginHref } from '@/lib/paths'

// 收藏（PRD 5.10）。页面的 props 带着这一页里已收藏链接的 url_hash 列表；书签点一下先改本地状态
// （R-10.5：不整页刷新、成功不出提示），请求走 fetch（同 lib/search.ts，CSRF 令牌从布局的 meta 读）。
// 请求结束后把最新的列表写回 Inertia 当前页（router.replaceProp 只改历史里的 props，不发请求）：
// 离开再按后退，恢复出来的页面与服务端一致。失败回滚并提示附录 B 的句子。
export const COPY = {
  addFailed: '收藏没有保存，请重试。',
  removeFailed: '取消收藏没有保存，请重试。',
  limited: '操作过于频繁，请稍后再试。',
}

export type FavoriteTarget = { urlHash: string; itemId?: string }

export type Favorites = {
  has: (urlHash: string) => boolean
  // 这一次页面停留里取消过、还留在列表里等着「恢复」的（R-10.7）
  removed: (urlHash: string) => boolean
  toggle: (target: FavoriteTarget) => void
  restore: (urlHash: string) => void
}

const Context = createContext<Favorites | null>(null)

// 没有套 FavoritesProvider 的地方（单测里单独渲染的条目行）拿到 null，书签就不画
export function useFavorites(): Favorites | null {
  return useContext(Context)
}

class Rejected extends Error {
  status: number

  constructor(status: number) {
    super(`HTTP ${status}`)
    this.status = status
  }
}

async function send(method: 'POST' | 'DELETE', url: string, body?: Record<string, string>): Promise<Record<string, string>> {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
  const response = await fetch(url, {
    method,
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': token },
    body: body ? JSON.stringify(body) : undefined,
  })
  if (!response.ok) throw new Rejected(response.status)
  return response.status === 204 ? {} : ((await response.json()) as Record<string, string>)
}

function without(record: Record<string, string | null>, key: string): Record<string, string | null> {
  const { [key]: _dropped, ...rest } = record
  return rest
}

export function FavoritesProvider({ favorites, children }: React.PropsWithChildren<{ favorites: string[] }>) {
  // 真相放在 ref 里：连续两次点击读到的都是最新的一份，不会踩到过期的闭包；tick 只负责让界面跟上
  const kept = useRef(new Set(favorites))
  // 这条链接的请求还在路上：不重复发
  const busy = useRef(new Set<string>())
  // 取消的请求还没回来，读者就点了「恢复」：凭据到手后接着恢复
  const waiting = useRef(new Set<string>())
  const mounted = useRef(true)
  const [tick, redraw] = useReducer((count: number) => count + 1, 0)
  // url_hash → 恢复凭据；null 是取消的请求还没回来
  const [undo, setUndo] = useState<Record<string, string | null>>({})
  const { toasts, push, dismiss } = useToasts()

  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])

  // 服务端给了新的列表（换期、生成中的轮询、历史恢复）就以它为准。按内容比：自己刚写回去的那一份内容没变，不算新的
  const given = favorites.join(',')
  useEffect(() => {
    kept.current = new Set(given === '' ? [] : given.split(','))
    redraw()
  }, [given])

  const mark = useCallback((urlHash: string, on: boolean) => {
    if (on) kept.current.add(urlHash)
    else kept.current.delete(urlHash)
    redraw()
  }, [])

  const settle = useCallback((urlHash: string) => {
    busy.current.delete(urlHash)
    // 读者已经离开这一页就不写了：replaceProp 改的是「当前页」，写过去会盖掉别的页面的列表
    if (mounted.current) router.replaceProp('favorites', [...kept.current])
  }, [])

  const fail = useCallback(
    (error: unknown, text: string) => {
      const status = error instanceof Rejected ? error.status : 0
      if (status === 401) {
        // 会话过期：去登录页，登录后回到这一页；这一次不补做（PRD 5.10 边界）
        router.visit(loginHref(window.location.pathname + window.location.search))
      } else {
        const shown = status === 429 ? COPY.limited : text
        push('fail', shown, shown)
      }
    },
    [push],
  )

  // 收藏：书签带着条目 id 来，「恢复」带着取消时拿到的凭据来
  const add = useCallback(
    (urlHash: string, body: Record<string, string>) => {
      if (busy.current.has(urlHash)) return
      busy.current.add(urlHash)
      mark(urlHash, true)

      send('POST', FAVORITES, body)
        .then(() => setUndo((current) => without(current, urlHash)))
        .catch((error: unknown) => {
          mark(urlHash, false)
          fail(error, COPY.addFailed)
        })
        .finally(() => settle(urlHash))
    },
    [mark, fail, settle],
  )

  const remove = useCallback(
    (urlHash: string) => {
      if (busy.current.has(urlHash)) return
      busy.current.add(urlHash)
      mark(urlHash, false)
      setUndo((current) => ({ ...current, [urlHash]: null }))
      let token: string | undefined

      send('DELETE', favoriteHref(urlHash))
        .then((data) => {
          token = data.undo
          // 服务端说这条本来就不在了（204，没有凭据）：没什么可恢复的
          setUndo((current) => (token ? { ...current, [urlHash]: token } : without(current, urlHash)))
        })
        .catch((error: unknown) => {
          mark(urlHash, true)
          setUndo((current) => without(current, urlHash))
          fail(error, COPY.removeFailed)
        })
        .finally(() => {
          settle(urlHash)
          if (waiting.current.delete(urlHash) && token) add(urlHash, { undo: token })
        })
    },
    [mark, fail, settle, add],
  )

  const value = useMemo<Favorites>(
    () => ({
      has: (urlHash) => kept.current.has(urlHash),
      removed: (urlHash) => urlHash in undo && !kept.current.has(urlHash),
      toggle: ({ urlHash, itemId }) => {
        if (kept.current.has(urlHash)) remove(urlHash)
        else if (itemId) add(urlHash, { item_id: itemId })
      },
      restore: (urlHash) => {
        const token = undo[urlHash]
        if (token) add(urlHash, { undo: token })
        else if (urlHash in undo) waiting.current.add(urlHash)
      },
    }),
    // tick 进依赖：收藏集合变了，value 得换一个新的，读它的书签才会重画
    [tick, undo, add, remove],
  )

  return (
    <Context.Provider value={value}>
      {/* 没有提示时不画提示区：单测里它会就地画一个 role="status"，跟页面自己的状态区撞名 */}
      {toasts.length > 0 ? <Toasts items={toasts} onDismiss={dismiss} /> : null}
      {children}
    </Context.Provider>
  )
}
