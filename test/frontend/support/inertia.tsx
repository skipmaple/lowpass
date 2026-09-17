import { useEffect, useState } from 'react'
import type * as React from 'react'
import { vi } from 'vitest'

// @inertiajs/react 的最小替身（在 setup.ts 里整体替掉这个包）。
// 真的 Inertia 要先有 createInertiaApp 挂出来的应用实例才有 page 上下文，
// 单元测试不启动它：Link 就是一个 <a href>，usePage 读下面这份可写的 props。

type PageProps = Record<string, unknown>

let pageProps: PageProps = {}

// 页面组件的持久布局（Show.layout）从 usePage 拿页脚要的字段，测试渲染前先把整份 props 摆进来
export function setPageProps(props: PageProps) {
  pageProps = props
}

export function usePage<T = PageProps>() {
  return { props: pageProps as T, url: window.location.pathname + window.location.search, component: 'Test', version: null }
}

// 页面本身不发访问（切来源是本地状态），留个 spy 好断言「没有回服务端」；后台表单提交也走 spy（post/patch）
type RouterEvent = 'start' | 'finish' | 'before'
type RouterListener = (event: Event) => void
const routerListeners = new Map<RouterEvent, Set<RouterListener>>()

export function emitRouterEvent(event: RouterEvent, detail = new Event(event)) {
  routerListeners.get(event)?.forEach((listener) => listener(detail))
}

export const router = {
  visit: vi.fn(),
  get: vi.fn(),
  reload: vi.fn(),
  delete: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  replace: vi.fn(),
  on: vi.fn((event: RouterEvent, listener: RouterListener) => {
    const listeners = routerListeners.get(event) ?? new Set<RouterListener>()
    listeners.add(listener)
    routerListeners.set(event, listeners)
    return () => listeners.delete(listener)
  }),
}

export function Head({ title }: { title?: string }) {
  useEffect(() => { if (title) document.title = `${title} · Lowpass` }, [title])
  return null
}

export function Link({ href, children, preserveState: _preserveState, ...rest }: React.ComponentProps<'a'> & { preserveState?: boolean }) {
  return (
    <a href={href} {...rest}>
      {children}
    </a>
  )
}

// useForm 的最小替身：data 是本地状态，errors 读页面 props 里的 errors（每字段第一条），提交是 spy
export const formPost = vi.fn()
export const formPatch = vi.fn()

// 最近一次渲染时的 data 快照：断言「某个操作有没有把字段丢掉」不能靠读 <input> 的 DOM 值——一个受控
// 字段的 value 一旦从字符串变成 undefined，React 不会把输入框里已经打出的字清空（只在 dev 模式报一条
// console.error，且这条 warning 在同一个测试文件里对同一种情况只报一次，后面的用例测不出来），
// toHaveValue 与「没报那条 warning」都靠不住。测试改成直接读这份快照，跳过 DOM 残留与 warning 去重的干扰。
export let lastFormData: Record<string, unknown> | null = null

export function useForm<T extends Record<string, unknown>>(initialOrKey: T | string, remembered?: T) {
  const initial = typeof initialOrKey === 'string' ? remembered! : initialOrKey
  const [data, setState] = useState<T>(initial)
  const [defaults, setDefaults] = useState<T>(initial)
  lastFormData = data
  const raw = (pageProps.errors as Record<string, string[] | string> | undefined) ?? {}
  const errors: Record<string, string> = {}
  for (const [key, value] of Object.entries(raw)) errors[key] = Array.isArray(value) ? (value[0] ?? '') : value
  // 真实 useForm 的 setData（node_modules/@inertiajs/react/dist/index.js 的 setDataFunction/commitData）：
  // 字符串键只改那一个字段（合并）；对象与函数都是整份替换——对象直接顶掉 data，函数用它的返回值顶掉 data，
  // 都不会自动保留没提到的字段。这里曾经对对象也做合并，会掩盖「切换适配器用对象形式漏传别的字段」这类真实缺陷。
  function setData(keyOrData: keyof T | Partial<T> | ((current: T) => T), value?: T[keyof T]) {
    if (typeof keyOrData === 'function') setState(keyOrData as (current: T) => T)
    else if (typeof keyOrData === 'object') setState(keyOrData as T)
    else setState((prev) => ({ ...prev, [keyOrData]: value }))
  }
  // transform 是真 useForm 提交前改一遍 data 的钩子；测试不提交，替身只要能被调用就够（no-op）
  return { data, setData, setDefaults, post: formPost, patch: formPatch, processing: false, isDirty: JSON.stringify(data) !== JSON.stringify(defaults), errors, transform: () => {} }
}
