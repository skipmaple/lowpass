import { describe, expect, it, vi } from 'vitest'

const loaded = vi.hoisted(() => ({ a: vi.fn(), b: vi.fn(), c: vi.fn() }))
vi.mock('@/styles/fonts-daybreak-content.css', () => { loaded.a(); return {} })
vi.mock('@/styles/fonts-duet-content.css', () => { loaded.b(); return {} })
vi.mock('@/styles/fonts-unfold-content.css', () => { loaded.c(); return {} })
import { loadContentFonts } from '@/lib/contentFonts'

describe('selected theme content fonts', () => {
  it('loads only the selected family and caches repeat imports', async () => {
    await loadContentFonts('duet')
    await loadContentFonts('duet')
    expect(loaded.b).toHaveBeenCalledTimes(1)
    expect(loaded.a).not.toHaveBeenCalled()
    expect(loaded.c).not.toHaveBeenCalled()
  })
  it('supports the default and dark theme', async () => {
    await loadContentFonts('daybreak')
    await loadContentFonts('unfold')
    expect(loaded.a).toHaveBeenCalledTimes(1)
    expect(loaded.c).toHaveBeenCalledTimes(1)
  })
})
