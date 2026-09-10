// 一个角色一个字体（设计 skill「四个字体角色」）：一段文字里中文与数字并存时，
// 得按字符段切开分别上字体，否则「延迟生成于 07:05」整段走等宽、中文掉进回退字体。
// 画布上的同一套做法见 docs/design/src/pages_front2.py 的 mixed()。

const CJK_RUN = /([\u2E80-\u9FFF\uFF00-\uFFEF]+)/
const ALL_CJK = /^[\u2E80-\u9FFF\uFF00-\uFFEF]+$/

export type MixedProps = {
  text: string
  // 非中文段用哪个角色：数字与记号走 Maple（默认），源站给的拉丁内容走 Newsreader
  font?: 'data' | 'latin'
  size?: number | string
  color?: string
  nowrap?: boolean
}

export function Mixed({ text, font = 'data', size = 'var(--fs-13)', color = 'var(--ink2)', nowrap = false }: MixedProps) {
  const latin = font === 'data' ? 'var(--font-data)' : 'var(--font-latin)'
  const weight = font === 'data' ? 400 : 500

  return (
    <span style={{ lineHeight: 1.6, whiteSpace: nowrap ? 'nowrap' : undefined }}>
      {text
        .split(CJK_RUN)
        .filter(Boolean)
        .map((run, index) =>
          ALL_CJK.test(run) ? (
            <span key={index} style={{ fontFamily: 'var(--font-cjk)', fontSize: size, color }}>
              {run}
            </span>
          ) : (
            <span key={index} style={{ fontFamily: latin, fontSize: size, fontWeight: weight, color }}>
              {run}
            </span>
          ),
        )}
    </span>
  )
}

// R-1.12 条目时间用相对时间；元数据行只有数字与记号，所以是 5h 不是「5 小时前」。
export function relativeAge(published: string, now: number = Date.now()): string {
  const minutes = Math.max(0, Math.floor((now - new Date(published).getTime()) / 60_000))
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h`
  return `${Math.floor(hours / 24)}d`
}

const SHANGHAI = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Asia/Shanghai',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

// R-1.12 悬停显示绝对时间，按 Asia/Shanghai；元数据里的日期写成数字（09-07 06:12）。
export function absoluteStamp(published: string): string {
  const parts = SHANGHAI.formatToParts(new Date(published))
  const part = (type: Intl.DateTimeFormatPartTypes) => parts.find((p) => p.type === type)?.value ?? ''
  return `${part('month')}-${part('day')} ${part('hour')}:${part('minute')}`
}

// GitHub 的 star 数按榜单的写法收成 12.3k
export function compactCount(value: number): string {
  return value >= 1000 ? `${(value / 1000).toFixed(1)}k` : String(value)
}
