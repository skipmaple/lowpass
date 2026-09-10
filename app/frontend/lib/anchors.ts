import { useEffect } from 'react'

// 搜索结果的「所在期」带着锚点进来（日刊 #item-<id>，周刊板块的 slug，中文按百分号编码）。条目与板块是
// React 挂载后才在 DOM 里：整页加载时浏览器自己的锚点定位赶不上，这里在挂载后补一次；Inertia 访问时它
// 自己也会按 hash 滚一次，重复无害。key 换了（切到另一期）再来一次。
export function useScrollToHash(key: string) {
  useEffect(() => {
    const id = decode(window.location.hash.slice(1))
    if (id) document.getElementById(id)?.scrollIntoView()
  }, [key])
}

function decode(fragment: string): string {
  try {
    return decodeURIComponent(fragment)
  } catch {
    return fragment
  }
}
