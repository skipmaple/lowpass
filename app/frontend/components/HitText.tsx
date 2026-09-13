import { Mixed } from '@/lib/typeset'
import type { HitRun } from '@/types/lowpass'

// 命中高亮（R-4.6、D22）：命中的 run 画 2px 墨色下划线，不用颜色块。每个 run 再经 Mixed 按字符段上字体
// （标题里的英文走 Newsreader，中文走文楷），下划线挂在外层 span 上，里面的字体段一起被划到。
export type HitTextProps = { runs: HitRun[]; size: string; color: string }

export default function HitText({ runs, size, color }: HitTextProps) {
  return (
    <>
      {runs.map((run, index) =>
        run.hit ? (
          <span key={index} className="hit">
            <Mixed text={run.text} font="latin" size={size} color={color} />
          </span>
        ) : (
          <Mixed key={index} text={run.text} font="latin" size={size} color={color} />
        ),
      )}
    </>
  )
}
