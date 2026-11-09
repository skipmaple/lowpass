// Content unicode ranges are separate from the small shell fonts. Import the
// selected world's full character coverage immediately; Vite caches each sheet.
export function loadContentFonts(theme: string = document.documentElement.dataset.theme ?? 'daybreak'): Promise<unknown> {
  // Keep the CSS imports in separate branches. A ternary can be collapsed into
  // one preload call during production optimization, losing B/C's stylesheet.
  if (theme === 'duet') return import('../styles/fonts-duet-content.css').catch(() => undefined)
  if (theme === 'unfold') return import('../styles/fonts-unfold-content.css').catch(() => undefined)
  // A failed optional font download must not interrupt reading or theme changes.
  return import('../styles/fonts-daybreak-content.css').catch(() => undefined)
}
