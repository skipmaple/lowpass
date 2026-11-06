import { useEffect } from 'react'

// 搜索与收藏的「所在期」带着条目锚点进来；旧周刊链接仍可用板块锚点。条目与板块是 React
// 挂载后才在 DOM 里，整页加载时浏览器自己的锚点定位赶不上，所以挂载后补一次。
// Inertia 自己也按 hash 滚（3.7.0 的 Scroll.scrollToAnchor）：拿 location.hash 原样去 getElementById，找不到
// 就滚回顶部，而且排在一个 setTimeout 里。所以（1）页面上的 id 必须与 hash 原样相等——中文锚点在地址里
// 一律是百分号编码（URL 解析器的规矩），Weekly/Show 渲染 id 时也编码；（2）这里也排进 setTimeout，
// 放到一帧之后的宏任务，确保缺失条目时的来源回退在它的归零之后执行。key 换了（切到另一期）再来一次。
// 日刊 ?source= 与周刊 ?section= 提供回退落点：重抓换掉条目 id 后仍能回到来源或板块。
export function useScrollToHash(key: string, fallbackId?: string, focusWeeklyItem = false) {
  useEffect(() => {
    // Inertia 的历史条目有滚动快照：刷新、Back/Forward 由框架恢复，不重新定位锚点。
    if (window.history.state?.documentScrollPosition) return
    let timer: ReturnType<typeof setTimeout> | undefined
    const frame = requestAnimationFrame(() => {
      timer = setTimeout(() => {
        const hash = window.location.hash.slice(1)
        const target = (hash ? document.getElementById(hash) : null) ?? (fallbackId ? document.getElementById(fallbackId) : null)
        target?.scrollIntoView()
        if (focusWeeklyItem && hash.startsWith('item-') && target?.matches('article.item-row--weekly')
          && (document.activeElement === document.body || document.activeElement === document.documentElement)) target.focus({ preventScroll: true })
      })
    })
    return () => { cancelAnimationFrame(frame); clearTimeout(timer) }
  }, [key, fallbackId, focusWeeklyItem])
}
