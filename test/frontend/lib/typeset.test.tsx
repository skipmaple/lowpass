import { render } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { Mixed, absoluteStamp, compactCount, relativeAge, splitRuns } from '@/lib/typeset'

// 排字规则的出处是 PRD 6.3 与 docs/design/notes/type-audit-2026-09-09.md：
// 一段文字里中文与数字并存时按字符段切开分别上字体，例外是「含数字的中文短语」
// （9月7日、第 36 周）整体走文楷。这里把每一条规则都钉成一个例子。

// Mixed 渲染出来的每一段：文字 + 行内样式里的字体角色
function runsOf(container: HTMLElement) {
  const wrapper = container.firstElementChild as HTMLElement
  return Array.from(wrapper.children).map((child) => ({
    text: child.textContent,
    font: (child as HTMLElement).style.fontFamily,
    weight: (child as HTMLElement).style.fontWeight,
  }))
}

describe('splitRuns', () => {
  it('纯拉丁与纯中文各是一整段', () => {
    expect(splitRuns('OpenClaw')).toEqual([{ cjk: false, text: 'OpenClaw' }])
    expect(splitRuns('低通滤波')).toEqual([{ cjk: true, text: '低通滤波' }])
  })

  // 元数据行只有数字与记号，整行一个角色（Maple），不该被切碎
  it('数字与记号整行走非中文段', () => {
    expect(splitRuns('▲ 312 · 145 · 5h')).toEqual([{ cjk: false, text: '▲ 312 · 145 · 5h' }])
  })

  it('贴着日期单位的数字并进中文段，纯时间留给 Maple', () => {
    expect(splitRuns('上次成功 9月7日 06:11')).toEqual([
      { cjk: true, text: '上次成功 9月7日' },
      { cjk: false, text: ' 06:11' },
    ])
  })

  it('「第 N 周」「2026年9月7日」是一整个中文段', () => {
    expect(splitRuns('第 36 周')).toEqual([{ cjk: true, text: '第 36 周' }])
    expect(splitRuns('2026年9月7日')).toEqual([{ cjk: true, text: '2026年9月7日' }])
  })

  // 序数由「第」那一支带出来，量词不在 年/月/日/周/期 里也算：「第 36 条」整段是中文，
  // 同样带「条」的「共 5 条」没有「第」，5 仍旧是数字段。
  it('序数看「第」，不看后面的量词', () => {
    expect(splitRuns('第 36 条')).toEqual([{ cjk: true, text: '第 36 条' }])
    expect(splitRuns('共 5 条')).toEqual([
      { cjk: true, text: '共' },
      { cjk: false, text: ' 5' },
      { cjk: true, text: ' 条' },
    ])
  })

  // 附录 B 的两句：时间与计数都不是日期短语，仍旧切出来交给 Maple
  it('时间与计数不并进中文段', () => {
    expect(splitRuns('已于 06:42 修订')).toEqual([
      { cjk: true, text: '已于' },
      { cjk: false, text: ' 06:42' },
      { cjk: true, text: ' 修订' },
    ])
    expect(splitRuns('生成中，约 1 分钟后刷新')).toEqual([
      { cjk: true, text: '生成中，约' },
      { cjk: false, text: ' 1' },
      { cjk: true, text: ' 分钟后刷新' },
    ])
  })

  // 源站给的标题：拉丁段与紧跟的空格留在前一段，中文从第一个汉字起
  it('中文里的拉丁片段自成一段', () => {
    expect(splitRuns('OpenClaw 2.0 是一个缩影')).toEqual([
      { cjk: false, text: 'OpenClaw 2.0' },
      { cjk: true, text: ' 是一个缩影' },
    ])
  })

  it('空字符串没有段', () => {
    expect(splitRuns('')).toEqual([])
  })
})

describe('Mixed', () => {
  it('中文段上文楷，非中文段默认上 Maple', () => {
    const { container } = render(<Mixed text="上次成功 9月7日 06:11" />)

    expect(runsOf(container)).toEqual([
      { text: '上次成功 9月7日', font: 'var(--font-cjk)', weight: '' },
      { text: ' 06:11', font: 'var(--font-data)', weight: '400' },
    ])
  })

  it('font="latin" 只换非中文段的角色', () => {
    const { container } = render(<Mixed text="Hacker News 完整榜单" font="latin" />)

    expect(runsOf(container)).toEqual([
      { text: 'Hacker News', font: 'var(--font-latin)', weight: '500' },
      { text: ' 完整榜单', font: 'var(--font-cjk)', weight: '' },
    ])
  })

  it('weight 覆盖角色的默认字重（来源名是 600）', () => {
    const { container } = render(<Mixed text="Hacker News" font="latin" weight={600} />)

    expect(runsOf(container)[0]).toMatchObject({ font: 'var(--font-latin)', weight: '600' })
  })

  it('字号与颜色照传，nowrap 落在外层', () => {
    const { container } = render(<Mixed text="第 36 周" size="var(--fs-12)" color="var(--paper)" nowrap />)
    const wrapper = container.firstElementChild as HTMLElement
    const run = wrapper.firstElementChild as HTMLElement

    expect(wrapper.style.whiteSpace).toBe('nowrap')
    expect(run.style.fontSize).toBe('var(--fs-12)')
    expect(run.style.color).toBe('var(--paper)')
  })
})

describe('relativeAge', () => {
  const now = Date.parse('2026-09-08T22:12:00Z')

  it('不满一分钟是 0m', () => {
    expect(relativeAge('2026-09-08T22:11:30Z', now)).toBe('0m')
  })

  it('一小时以内按分钟', () => {
    expect(relativeAge('2026-09-08T21:30:00Z', now)).toBe('42m')
    expect(relativeAge('2026-09-08T21:13:00Z', now)).toBe('59m')
  })

  it('一天以内按小时（5h，不是「5 小时前」）', () => {
    expect(relativeAge('2026-09-08T21:12:00Z', now)).toBe('1h')
    expect(relativeAge('2026-09-08T17:12:00Z', now)).toBe('5h')
    expect(relativeAge('2026-09-07T23:12:00Z', now)).toBe('23h')
  })

  it('超过一天按天', () => {
    expect(relativeAge('2026-09-07T22:12:00Z', now)).toBe('1d')
    expect(relativeAge('2026-09-05T22:12:00Z', now)).toBe('3d')
  })

  // 源站给的时间偶尔比本地时钟还新（时区标错、机器时间偏了），夹到 0 而不是写成负数
  it('未来的时间夹成 0m', () => {
    expect(relativeAge('2026-09-09T06:00:00Z', now)).toBe('0m')
  })

  it('解析不出的时间不显示', () => {
    expect(relativeAge('not-a-timestamp', now)).toBe('')
  })
})

describe('absoluteStamp', () => {
  it('把 UTC 换算到 Asia/Shanghai 的 MM-DD HH:MM', () => {
    expect(absoluteStamp('2026-09-09T13:27:00Z')).toBe('09-09 21:27')
  })

  // 时区真的生效才看得出跨日：UTC 还是 8 号晚上，上海已经是 9 号凌晨
  it('跨日时按上海那天算', () => {
    expect(absoluteStamp('2026-09-08T16:30:00Z')).toBe('09-09 00:30')
  })
})

describe('compactCount', () => {
  it('不到一千照原样写', () => {
    expect(compactCount(0)).toBe('0')
    expect(compactCount(999)).toBe('999')
  })

  it('一千往上收成一位小数的 k', () => {
    expect(compactCount(1000)).toBe('1.0k')
    expect(compactCount(12300)).toBe('12.3k')
    expect(compactCount(12345)).toBe('12.3k')
  })

  it('百万收成一位小数的 M', () => {
    expect(compactCount(1_000_000)).toBe('1M')
    expect(compactCount(1_234_567)).toBe('1.2M')
    expect(compactCount(12_345_678)).toBe('12.3M')
  })
})
