// 系统「减少动态效果」：所有动效都看它（设计 skill「动效」）。没有 matchMedia（jsdom）就当没开
export function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true
}
