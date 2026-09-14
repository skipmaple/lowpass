import { useState } from 'react'
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
export const router = { visit: vi.fn(), get: vi.fn(), reload: vi.fn(), delete: vi.fn(), post: vi.fn(), patch: vi.fn() }

export function Link({ href, children, ...rest }: React.ComponentProps<'a'>) {
  return (
    <a href={href} {...rest}>
      {children}
    </a>
  )
}

// useForm 的最小替身：data 是本地状态，errors 读页面 props 里的 errors（每字段第一条），提交是 spy
export const formPost = vi.fn()
export const formPatch = vi.fn()

export function useForm<T extends Record<string, unknown>>(initial: T) {
  const [data, setState] = useState<T>(initial)
  const raw = (pageProps.errors as Record<string, string[] | string> | undefined) ?? {}
  const errors: Record<string, string> = {}
  for (const [key, value] of Object.entries(raw)) errors[key] = Array.isArray(value) ? (value[0] ?? '') : value
  function setData(key: keyof T | Partial<T>, value?: T[keyof T]) {
    if (typeof key === 'object') setState((prev) => ({ ...prev, ...key }))
    else setState((prev) => ({ ...prev, [key]: value }))
  }
  // transform 是真 useForm 提交前改一遍 data 的钩子；测试不提交，替身只要能被调用就够（no-op）
  return { data, setData, post: formPost, patch: formPatch, processing: false, errors, transform: () => {} }
}
