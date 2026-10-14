import { afterEach, describe, expect, it } from 'vitest'

import { loadContentFonts } from '@/lib/contentFonts'

// 正文字体声明（设计说明 2026-10-14 D3）：布局里 preload 的那张表，应用启动时挂成样式表，只挂一次

afterEach(() => {
  document.head.innerHTML = ''
})

describe('loadContentFonts', () => {
  it('把 preload 的那张表挂成样式表', () => {
    document.head.innerHTML = '<link rel="preload" as="style" href="/vite/assets/fonts-content-abc.css" data-content-fonts>'

    loadContentFonts()

    const sheet = document.head.querySelector<HTMLLinkElement>('link[rel="stylesheet"][data-content-fonts-applied]')
    expect(sheet?.getAttribute('href')).toBe('/vite/assets/fonts-content-abc.css')
  })

  it('只挂一次', () => {
    document.head.innerHTML = '<link rel="preload" as="style" href="/a.css" data-content-fonts>'

    loadContentFonts()
    loadContentFonts()

    expect(document.head.querySelectorAll('link[rel="stylesheet"]')).toHaveLength(1)
  })

  it('页面没有 preload（登录页以外的静态页、单测）时什么都不做', () => {
    loadContentFonts()

    expect(document.head.querySelectorAll('link')).toHaveLength(0)
  })
})
