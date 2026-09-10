import { useEffect } from 'react'

// 搜索结果的「所在期」带着锚点进来（日刊 #item-<id>，周刊板块的 slug，中文按百分号编码）。条目与板块是
// React 挂载后才在 DOM 里，整页加载时浏览器自己的锚点定位赶不上，所以挂载后补一次。
// Inertia 自己也按 hash 滚（3.7.0 的 Scroll.scrollToAnchor）：它拿没解码的 hash 去 getElementById，中文锚点
// 找不到就滚回顶部，而且它排在一个 setTimeout 里、在 React 提交之前就排好了。这里也排进 setTimeout，
// 排在它后面，最后一次滚动才是我们的。key 换了（切到另一期）再来一次。
export function useScrollToHash(key: string) {
  useEffect(() => {
    const timer = setTimeout(() => {
      const id = decode(window.location.hash.slice(1))
      if (id) document.getElementById(id)?.scrollIntoView()
    })
    return () => clearTimeout(timer)
  }, [key])
}

function decode(fragment: string): string {
  try {
    return decodeURIComponent(fragment)
  } catch {
    return fragment
  }
}
