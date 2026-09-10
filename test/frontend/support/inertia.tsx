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

// 页面本身不发访问（切来源是本地状态），留个 spy 好断言「没有回服务端」
export const router = { visit: vi.fn(), get: vi.fn(), reload: vi.fn() }

export function Link({ href, children, ...rest }: React.ComponentProps<'a'>) {
  return (
    <a href={href} {...rest}>
      {children}
    </a>
  )
}
