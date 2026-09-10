// 一个角色一个字体（设计 skill「四个字体角色」）：一段文字里中文与数字并存时，
// 得按字符段切开分别上字体，否则「延迟生成于 07:05」整段走等宽、中文掉进回退字体。
//
// 例外是「含数字的中文短语」：PRD 6.3 与 docs/design/notes/type-audit-2026-09-09.md 的决定写着
// 「9月7日」「第 36 周」按中文处理、整体用文楷，不拆成两种字体。所以紧贴着 年/月/日/周/期 的数字段，
// 以及跟在「第」后面的数字段，都并进中文段；纯时间（06:11）、计数（约 1 分钟）与记号仍旧走 Maple。
// 画布 docs/design/src/pages_front2.py 的 mixed() 只按字符类切段，会把「9月7日」切成
// Maple[9] 文楷[月] Maple[7] 文楷[日]——画布落后于定稿，这里以 PRD 6.3 为准。

const CJK_CHAR = '[\\u2E80-\\u9FFF\\uFF00-\\uFFEF]'
// 通用相邻规则只认日期与序数字符；「第 36 条」里的「条」由「第」那一支带出来
const DATE_UNIT = '[年月日周期]'
// 一个中文段 = 中文字符 ∪「第 N」∪ 贴着日期单位的数字段 ∪ 夹在这些之间的空格
const CJK_PHRASE = new RegExp(
  `(?:第\\s*\\d+|\\d+(?=\\s*${DATE_UNIT})|${CJK_CHAR}|\\s+(?=${CJK_CHAR}|\\d+\\s*${DATE_UNIT}))+`,
  'g',
)

export type Run = { cjk: boolean; text: string }

// 「上次成功 9月7日 06:11」→ 文楷[上次成功 9月7日] + Maple[ 06:11]
export function splitRuns(text: string): Run[] {
  const runs: Run[] = []
  let at = 0

  for (const match of text.matchAll(CJK_PHRASE)) {
    const start = match.index ?? 0
    if (start > at) runs.push({ cjk: false, text: text.slice(at, start) })
    runs.push({ cjk: true, text: match[0] })
    at = start + match[0].length
  }
  if (at < text.length) runs.push({ cjk: false, text: text.slice(at) })

  return runs
}

export type MixedProps = {
  text: string
  // 非中文段用哪个角色：数字与记号走 Maple（默认），源站给的拉丁内容走 Newsreader
  font?: 'data' | 'latin'
  // 要随断点变的字号传 'inherit'，实际字号交给 className 那条 CSS（行内样式盖不住 @media）
  size?: number | string
  color?: string
  nowrap?: boolean
  className?: string
  // 拉丁段的字重：默认按角色取（Maple 400、Newsreader 500），来源名是 600（令牌表）
  weight?: number
}

export function Mixed({ text, font = 'data', size = 'var(--fs-13)', color = 'var(--ink2)', nowrap = false, className, weight: given }: MixedProps) {
  const latin = font === 'data' ? 'var(--font-data)' : 'var(--font-latin)'
  const weight = given ?? (font === 'data' ? 400 : 500)

  return (
    <span className={className} style={{ lineHeight: 1.6, whiteSpace: nowrap ? 'nowrap' : undefined }}>
      {splitRuns(text).map((run, index) =>
        run.cjk ? (
          <span key={index} style={{ fontFamily: 'var(--font-cjk)', fontSize: size, color }}>
            {run.text}
          </span>
        ) : (
          <span key={index} style={{ fontFamily: latin, fontSize: size, fontWeight: weight, color }}>
            {run.text}
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
