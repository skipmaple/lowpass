import { describe, expect, it } from 'vitest'
import { normalizeDateLabel } from '@/lib/displayDate'

describe('日期展示', () => {
  it('按斜线显示日期，不改周次、来源域名或路由', () => {
    expect(normalizeDateLabel('2026年9月8日')).toBe('2026/09/08')
    expect(normalizeDateLabel('收藏于 2026.11.04')).toBe('收藏于 2026/11/04')
    expect(normalizeDateLabel('2026-11-04')).toBe('2026/11/04')
    expect(normalizeDateLabel('11月6日 06:00')).toBe('11/06 06:00')
    expect(normalizeDateLabel('2026年 · 第 36 周 · 工具')).toBe('2026年 · 第 36 周 · 工具')
    expect(normalizeDateLabel('rikiyat.github.io')).toBe('rikiyat.github.io')
  })
})
