const RESULT_ID = /^search-result-[a-z0-9]{25}$/

export function searchResultId(itemId: string): string {
  return `search-result-${itemId}`
}

export function searchResultTarget(): string | null {
  const id = window.location.hash.slice(1)
  if (window.location.pathname === '/search' && RESULT_ID.test(id)) {
    return id
  } else {
    return null
  }
}

// 仅替换当前搜索 entry 的原生片段。原样交回不透明的 state，不排入 Inertia 的加密写队列，
// 不增加历史记录，也不触发锚点滚动。标记失败时，所在期的正常访问继续。
export function markSearchResult(itemId: string): void {
  const id = searchResultId(itemId)
  if (window.location.pathname !== '/search' || !RESULT_ID.test(id)) return

  const url = new URL(window.location.href)
  url.hash = id
  try {
    window.history.replaceState(window.history.state, '', url.href)
  } catch {
    // 浏览器不允许替换历史时，返回焦点退回既有行为。
  }
}
