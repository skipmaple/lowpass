// Content unicode ranges are separate from the small shell fonts. Import the
// selected world's full character coverage immediately; Vite caches each sheet.
export function loadContentFonts(theme: string = document.documentElement.dataset.theme ?? 'daybreak'): Promise<unknown> {
  const sheet = theme === 'duet' ? import('../styles/fonts-duet-content.css')
    : theme === 'unfold' ? import('../styles/fonts-unfold-content.css')
      : import('../styles/fonts-daybreak-content.css')
  // A failed optional font download must not interrupt reading or theme changes.
  return sheet.catch(() => undefined)
}
