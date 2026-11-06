import { useSyncExternalStore } from 'react'
import { loadContentFonts } from '@/lib/contentFonts'

export const THEMES = [
  { id: 'daybreak', letter: 'A', name: '层叠清晨', description: '明亮色面 · 温润圆黑' },
  { id: 'duet', letter: 'B', name: '双声部', description: '黑白对读 · 编辑宋体' },
  { id: 'unfold', letter: 'C', name: '展开阅读', description: '深色平面 · 清晰荧黑' },
] as const
export type Theme = typeof THEMES[number]['id']
export const THEME_KEY = 'lowpass-theme'

export function isTheme(value: unknown): value is Theme {
  return THEMES.some((theme) => theme.id === value)
}

function currentTheme(): Theme {
  const value = document.documentElement.dataset.theme
  return isTheme(value) ? value : 'daybreak'
}

function subscribe(listener: () => void) {
  window.addEventListener('lowpass:theme', listener)
  function sync(event: StorageEvent) {
    if (event.key === THEME_KEY) applyTheme(isTheme(event.newValue) ? event.newValue : 'daybreak', false)
  }
  window.addEventListener('storage', sync)
  return () => {
    window.removeEventListener('lowpass:theme', listener)
    window.removeEventListener('storage', sync)
  }
}

function applyTheme(theme: Theme, persist: boolean) {
  document.documentElement.dataset.theme = theme
  const fonts = loadContentFonts(theme)
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', theme === 'unfold' ? '#111515' : theme === 'duet' ? '#FCFCFA' : '#FCFAF2')
  if (persist) {
    try { localStorage.setItem(THEME_KEY, theme) } catch { /* The current tab still works when storage is unavailable. */ }
  }
  window.dispatchEvent(new Event('lowpass:theme'))
  return fonts
}

export function setTheme(theme: Theme) {
  // Keep the same article on screen when the composition changes; React state and
  // form nodes stay mounted. Font completion may change its position once more.
  const visible = (node: HTMLElement) => node.getBoundingClientRect().bottom > 100 && node.getBoundingClientRect().top < innerHeight
  const anchor = window.scrollY > 100
    ? Array.from(document.querySelectorAll<HTMLElement>('article[id]')).find(visible)
      ?? Array.from(document.querySelectorAll<HTMLElement>('section[id]')).find(visible)
    : undefined
  const offset = anchor?.getBoundingClientRect().top
  const fonts = applyTheme(theme, true)
  let userScrolled = false
  const cancelRestore = () => { userScrolled = true }
  const cancelOnKey = (event: KeyboardEvent) => {
    if (['ArrowDown', 'ArrowUp', 'PageDown', 'PageUp', 'Home', 'End', ' '].includes(event.key)) cancelRestore()
  }
  if (anchor) {
    window.addEventListener('wheel', cancelRestore, { passive: true })
    window.addEventListener('touchmove', cancelRestore, { passive: true })
    window.addEventListener('keydown', cancelOnKey)
  }
  const restore = () => {
    if (!userScrolled && anchor?.isConnected && offset !== undefined) window.scrollBy(0, anchor.getBoundingClientRect().top - offset)
  }
  requestAnimationFrame(() => {
    restore()
    void fonts.then(() => document.fonts?.ready).then(() => {
      if (currentTheme() === theme) requestAnimationFrame(restore)
    }).catch(() => { /* Keep the selected theme and system fallback if a font request fails. */ }).finally(() => {
      window.removeEventListener('wheel', cancelRestore)
      window.removeEventListener('touchmove', cancelRestore)
      window.removeEventListener('keydown', cancelOnKey)
    })
  })
}

export function useTheme() {
  return { theme: useSyncExternalStore(subscribe, currentTheme, () => 'daybreak' as const), setTheme }
}
