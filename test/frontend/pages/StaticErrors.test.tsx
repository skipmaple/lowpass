/// <reference types="vite/client" />

import { expect, it } from 'vitest'
import notFound from '../../../public/404.html?raw'
import rejected from '../../../public/422.html?raw'
import unsupported from '../../../public/406-unsupported-browser.html?raw'

it.each([
  ['404', notFound, '找不到这个页面'],
  ['422', rejected, '请求未被接受'],
  ['406', unsupported, '浏览器版本过旧'],
])('静态 %s 提供中文恢复入口，拒绝的请求不会自动重新提交', (_status, html, message) => {
  const document = new DOMParser().parseFromString(html, 'text/html')

  expect(document.documentElement.lang).toBe('zh-CN')
  expect(document.title).toContain('Lowpass')
  expect(document.querySelector('h1')?.textContent).toContain(message)
  expect(document.querySelector('nav[aria-label="恢复操作"] a')?.getAttribute('href')).toBe('/')
  expect(document.querySelectorAll('form, script, button, meta[http-equiv="refresh"], [onclick]')).toHaveLength(0)
})
