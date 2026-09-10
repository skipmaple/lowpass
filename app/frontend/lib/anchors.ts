import { useEffect } from 'react'

// 搜索结果的「所在期」带着锚点进来（日刊 #item-<id>，周刊板块 #issue-<期号>-<slug>）。条目与板块是 React
// 挂载后才在 DOM 里，整页加载时浏览器自己的锚点定位赶不上，所以挂载后补一次。
// Inertia 自己也按 hash 滚（3.7.0 的 Scroll.scrollToAnchor）：拿 location.hash 原样去 getElementById，找不到
// 就滚回顶部，而且排在一个 setTimeout 里。所以（1）页面上的 id 必须与 hash 原样相等——中文锚点在地址里
// 一律是百分号编码（URL 解析器的规矩），Weekly/Show 渲染 id 时也编码；（2）这里也排进 setTimeout，
// 与它落在同一个元素上，谁后跑都无所谓。key 换了（切到另一期）再来一次。
export function useScrollToHash(key: string) {
  useEffect(() => {
    const timer = setTimeout(() => {
      const id = window.location.hash.slice(1)
      if (id) document.getElementById(id)?.scrollIntoView()
    })
    return () => clearTimeout(timer)
  }, [key])
}
