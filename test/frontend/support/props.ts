import type {
  AdapterOption,
  AdminIssueRow,
  AdminRunRow,
  AdminSourceForm,
  AdminSourceRow,
  AdminUserRow,
  ArchiveDay,
  ArchiveWeek,
  CurrentUser,
  DailyIssue,
  InterestArea,
  Item,
  ReasonsStatus,
  SearchFilters,
  SearchResult,
  SourceSummary,
  TestFetchResult,
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

export function searchFilters(overrides: Partial<SearchFilters> = {}): SearchFilters {
  return { type: null, sources: [], from: null, to: null, range: 'all', sort: 'relevance', ...overrides }
}

// 一条日刊结果：标题命中 Kuber 与 Rust，片段命中 Kubernetes
export function searchResult(overrides: Partial<SearchResult> = {}): SearchResult {
  return {
    item_id: 'itm-hn-1',
    rank: 1,
    publication: 'daily',
    source_name: 'Hacker News',
    where: { label: '9月8日', href: '/daily/2026-09-08?source=src-hn#item-itm-hn-1' },
    published_label: '9月8日',
    url: 'https://example.com/k8s-rust',
    title_runs: [
      { text: 'Kuber', hit: true },
      { text: 'netes operator in ', hit: false },
      { text: 'Rust', hit: true },
    ],
    snippet_runs: [
      { text: 'Build a ', hit: false },
      { text: 'Kubernetes', hit: true },
      { text: ' operator with the Rust SDK', hit: false },
    ],
    ...overrides,
  }
}

// ApplicationController 的 inertia_share 每页都带的当前用户
export function currentUser(overrides: Partial<CurrentUser> = {}): CurrentUser {
  return { display_name: 'Drew Lee', avatar_url: null, email: 'drew@example.com', admin: false, ...overrides }
}

// 后台信息源列表一行（R-3.1，Source::Presenting#admin_rows）；config 是列表里「测试抓取」要传的完整配置
export function adminSourceRow(overrides: Partial<AdminSourceRow> = {}): AdminSourceRow {
  return {
    id: 'src-hn', sort_order: 1, name: 'Hacker News', adapter: 'hacker_news', adapter_label: 'Hacker News', publication: 'daily', enabled: true,
    health: 'ok', health_label: '正常', last_fetch_label: '9月8日 06:12 · 成功 · 10 条', next_run_label: '9月9日 06:00',
    config: { list: 'top', count: 10, min_score: 0 }, ...overrides,
  }
}

// 新建 / 编辑来源表单（R-3.2、Source#form_props）
export function adminSourceForm(overrides: Partial<AdminSourceForm> = {}): AdminSourceForm {
  return { id: null, name: '', adapter: 'rss', publication: 'daily', sort_order: 5, config: { feed_url: '', count: 10, window_hours: 24 }, ...overrides }
}

// Source.adapter_options：四种适配器与各自可选的刊物（Source::Config::SCHEMAS）
export const ADAPTER_OPTIONS: AdapterOption[] = [
  { key: 'hacker_news', label: 'Hacker News', publications: ['daily'] },
  { key: 'github_trending', label: 'GitHub Trending', publications: ['daily'] },
  { key: 'rss', label: 'RSS/Atom', publications: ['daily', 'weekly'] },
  { key: 'ruanyf_weekly', label: '阮一峰周刊', publications: ['weekly'] },
]

// R-3.3 测试抓取的结果：前 5 条预览、解析警告、失败原因（Source::TestFetch）
export function testFetchResult(overrides: Partial<TestFetchResult> = {}): TestFetchResult {
  return {
    ok: true, parsed: 24, dropped: 0, duration_ms: 1800, feed_title: 'Hackaday', error: null, warnings: ['1 条无发布时间，已用抓取时间代替'],
    entries: [
      { title: 'A Mechanical Keyboard Built From Scrap Relays', url: 'https://hackaday.com/1', summary: null, author: 'M. Okada', published_label: '09-08 03:10', meta: {} },
      { title: 'Reviving a 1980s Oscilloscope With an ESP32', url: 'https://hackaday.com/2', summary: null, author: 'R. Alvarez', published_label: '09-08 00:02', meta: {} },
    ],
    ...overrides,
  }
}

// 后台抓取记录一行（R-3.9，Source::Presenting#run_rows）
export function adminRunRow(overrides: Partial<AdminRunRow> = {}): AdminRunRow {
  return { id: 'run-1', started_label: '9月8日 06:12:01', duration_label: '1.8 秒', status: 'succeeded', status_label: '成功', attempt_label: '1 / 3', item_count: 10, dropped_count: 0, error_summary: null, trigger_label: '调度', ...overrides }
}

// 后台期列表一行（5.6，Issue::Administering#admin_rows）
export function adminIssueRow(overrides: Partial<AdminIssueRow> = {}): AdminIssueRow {
  return { kind: 'daily', period_key: '2026-09-08', state: 'published', state_label: '已发布', time_label: '06:12', source_marks: 'HN 10 · GH 10 · HAD 10', refetchable_sources: [{ id: 'src-hn', name: 'Hacker News' }, { id: 'src-gh', name: 'GitHub Trending' }], reasons: { label: '已生成', missing: 0, ready: true }, ...overrides }
}

// 后台用户列表一行（5.6，User.admin_rows）
export function adminUserRow(overrides: Partial<AdminUserRow> = {}): AdminUserRow {
  return { id: 'u1', display_name: 'Drew Lee', email: 'drew@example.com', role: 'admin', providers_label: 'Google · GitHub', last_login_label: '2026-09-09 08:12', ...overrides }
}

// 设置页「推荐理由」一节的用量与配置（④，Reasons::Status#props）
export function reasonsStatus(overrides: Partial<ReasonsStatus> = {}): ReasonsStatus {
  return { configured: false, key_configured: false, base_url: '', model_name: '', input_price: '0', output_price: '0', monthly_cap: '0', month_calls: 0, month_cost: '0.0', today_calls: 0, ...overrides }
}

// 兴趣画像一行（④，InterestArea）
export function interestArea(overrides: Partial<InterestArea> = {}): InterestArea {
  return { id: 'ia-1', name: 'AI / LLM', keywords: '本地模型部署、Agent 框架', sort_order: 1, enabled: true, ...overrides }
}
