// 正文字体声明（设计说明 2026-10-14 D3）：布局里 preload 的那张表（文楷 97 个分片的 @font-face），
// 应用启动时挂成样式表——不挡首屏渲染，正文里的汉字照旧按 unicode-range 按需下载分片。只挂一次。
export function loadContentFonts(doc: Document = document): void {
  const preload = doc.querySelector<HTMLLinkElement>('link[data-content-fonts]')
  if (!preload || doc.querySelector('link[data-content-fonts-applied]')) return

  const link = doc.createElement('link')
  link.rel = 'stylesheet'
  // 照抄属性原文（不读解析成绝对地址的 .href）：与 preload 是同一个 URL，浏览器直接用 preload 下好的那份
  link.setAttribute('href', preload.getAttribute('href') ?? preload.href)
  link.setAttribute('data-content-fonts-applied', '')
  doc.head.appendChild(link)
}
