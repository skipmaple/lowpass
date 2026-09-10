import type {
  ArchiveDay,
  ArchiveWeek,
  DailyIssue,
  Item,
  SourceSummary,
  WeeklyGroup,
  WeeklyIssue,
  WeeklySection,
} from '@/types/lowpass'

// 样例 props：字段与 Issue::Presenting 给出的那一套一一对应（周期键、附录 B 的文案、
// 适配器往 meta 里放的键）。每个工厂给一份能直接渲染的默认值，测试只覆盖它关心的字段。

export function source(overrides: Partial<SourceSummary> = {}): SourceSummary {
  return {
    id: 'src-hn',
    name: 'Hacker News',
    adapter: 'hacker_news',
    state: 'ok',
    home_url: 'https://news.ycombinator.com/news',
    last_ok_label: null,
    ...overrides,
  }
}

export function item(overrides: Partial<Item> = {}): Item {
  return {
    id: 'itm-hn-1',
    title: 'Show HN: A terminal log viewer written in Rust',
    url: 'https://example.com/termlog',
    summary: null,
    section: null,
    author: null,
    published_at: '2026-09-08T17:12:00Z',
    rank: 1,
    meta: {},
    reason: null,
    interest_tag: null,
    ...overrides,
  }
}

export function dailyIssue(overrides: Partial<DailyIssue> = {}): DailyIssue {
  return {
    period_key: '2026-09-08',
    date_label: '9月8日',
    weekday: '星期二',
    state: 'published',
    time_label: '06:12 发布',
    status: null,
    daily_time: '06:00',
    published_at: '06:12',
    revised_at: null,
    generated_late: false,
    is_yesterday: false,
    prev_key: '2026-09-07',
    next_key: null,
    ...overrides,
  }
}

export function weeklyIssue(overrides: Partial<WeeklyIssue> = {}): WeeklyIssue {
  return {
    period_key: '2026-W36',
    year: 2026,
    week_label: '第 36 周',
    range_label: '8月31日 至 9月6日',
    state: 'published',
    status: null,
    published_at: '06:20',
    prev_key: '2026-W35',
    next_key: null,
    ...overrides,
  }
}

export function weeklyGroup(overrides: Partial<WeeklyGroup> = {}): WeeklyGroup {
  return {
    name: '科技动态',
    anchor: 'src-ruanyf-1',
    items: [item({ id: 'itm-ry-1', title: '人生的容错率', url: 'https://example.com/ruanyf-366' })],
    ...overrides,
  }
}

export function weeklySection(overrides: Partial<WeeklySection> = {}): WeeklySection {
  return {
    source: {
      id: 'src-ruanyf',
      name: '阮一峰科技爱好者周刊',
      adapter: 'ruanyf_weekly',
      home_url: 'https://www.ruanyifeng.com/blog/weekly/',
    },
    issue_no: 366,
    issue_title: '人生的容错率',
    issue_label: '第 366 期 · 人生的容错率',
    degraded: false,
    original_url: 'https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md',
    groups: [weeklyGroup()],
    ...overrides,
  }
}

export function archiveDay(overrides: Partial<ArchiveDay> = {}): ArchiveDay {
  return {
    period_key: '2026-09-08',
    date_label: '9月8日',
    weekday: '星期二',
    state: 'published',
    published_label: '06:12 发布',
    source_marks: 'HN 10 · GH 10 · HAD 8',
    ...overrides,
  }
}

export function archiveWeek(overrides: Partial<ArchiveWeek> = {}): ArchiveWeek {
  return {
    period_key: '2026-W36',
    week_label: '第 36 周',
    range_label: '8月31日 至 9月6日',
    state: 'published',
    summary: '阮一峰科技爱好者周刊 第 366 期 · 人生的容错率',
    count: 42,
    ...overrides,
  }
}
