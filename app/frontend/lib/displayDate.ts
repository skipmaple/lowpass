// Display only: route keys and server timezone calculations stay unchanged.
export function normalizeDateLabel(value: string): string {
  return value
    .replace(/(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日/g, (_, year: string, month: string, day: string) => `${year}/${month.padStart(2, '0')}/${day.padStart(2, '0')}`)
    .replace(/(\d{1,2})月\s*(\d{1,2})日/g, (_, month: string, day: string) => `${month.padStart(2, '0')}/${day.padStart(2, '0')}`)
    .replace(/\b(\d{4})[.-](\d{2})[.-](\d{2})\b/g, '$1/$2/$3')
    .replace(/\b(\d{2})\.(\d{2})\b/g, '$1/$2')
}
