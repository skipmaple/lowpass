export type Adapter = "hacker_news" | "github_trending" | "rss" | "ruanyf_weekly";
export type SourceSummary = { id: string; name: string; adapter: Adapter; state: "ok" | "empty" | "failed" | "pending"; home_url: string | null; last_ok_label: string | null };
// 适配器往 meta 里放的全部键：HN 的分数与评论、GitHub 的语言与 star、阮一峰的期号与板块锚点、
// RSS 的首图与「时间是抓取时间不是发布时间」标记（Adapters::Rss、Adapters::RuanyfWeekly）。
export type ItemMeta = { score?: number; comments?: number; comments_url?: string; language?: string; stars?: number; stars_today?: number; issue_no?: number; issue_title?: string; degraded?: boolean; anchor?: string; image_url?: string; time_from_fetch?: boolean };
export type Item = { id: string; title: string; url: string; summary: string | null; section: string | null; author: string | null; published_at: string | null; rank: number | null; meta: ItemMeta; reason: string | null; interest_tag: string | null };
export type IssueState = "generating" | "published" | "empty";
// status 与 time_label 是服务端定稿的期头文案（附录 B）：没有开 SSR，页面上读得到的字符串都得先进 props。
export type DailyIssue = { period_key: string; date_label: string; weekday: string; state: IssueState | null; time_label: string | null; status: string | null; daily_time: string; published_at: string | null; revised_at: string | null; generated_late: boolean; is_yesterday: boolean; prev_key: string | null; next_key: string | null };

// 周刊（R-2.5）：期头是「第 36 周 · 2026 · 8月31日 至 9月6日」；那一周没有期时 state 为 null，status 是「本周无内容」。
export type WeeklyIssue = { period_key: string; year: number; week_label: string; range_label: string; state: IssueState | null; status: string | null; published_at: string | null; prev_key: string | null; next_key: string | null };
export type WeeklySource = Pick<SourceSummary, "id" | "name" | "adapter" | "home_url">;
// 一个板块（RSS 源没有板块，name 为 null）；anchor 是板块锚点目录的落点（页面渲染 id 与 href 时百分号编码，见 Weekly/Show）。
export type WeeklyGroup = { name: string | null; anchor: string; items: Item[] };
// 一节 = 一个源的一期：issue_label 是「第 366 期 · 主题」，degraded 时整节只有一条指向原文的条目（R-2.3）。
export type WeeklySection = { source: WeeklySource; issue_no: number | null; issue_title: string | null; issue_label: string | null; degraded: boolean; original_url: string | null; groups: WeeklyGroup[] };

// 归档（PRD 6.2）：翻月与翻年的按钮，越界时为 null。
export type ArchiveNav = { key: string; label: string } | null;
export type ArchiveMark = IssueState | "missing";
export type ArchiveDay = { period_key: string; date_label: string; weekday: string; state: ArchiveMark; published_label: string | null; source_marks: string | null };
export type ArchiveWeek = { period_key: string; week_label: string; range_label: string; state: ArchiveMark; summary: string; count: number | null };

// 页脚在每个页面都要的两样（R51）
export type FooterData = { daily_time: string; latest_weekly_key: string | null };

// ── 搜索（PRD 5.4、设计 6.2）：props 的形状由 SearchesController#render_search 定 ──
export type Publication = "daily" | "weekly";
export type SearchState = "initial" | "results" | "empty" | "limited" | "unavailable";
export type SearchRange = "7d" | "30d" | "all" | "custom";
export type SearchSort = "relevance" | "date";
export type SearchFilters = { type: Publication | null; sources: string[]; from: string | null; to: string | null; range: SearchRange; sort: SearchSort };
export type SearchSourceOption = { id: string; name: string; enabled: boolean };
export type DatePreset = { from: string; to: string };
export type DatePresets = Record<"7d" | "30d", DatePreset>;
// 命中 run：hit 为真的那一段画 2px 墨色下划线（D22）
export type HitRun = { text: string; hit: boolean };
export type SearchResult = { item_id: string; rank: number; publication: Publication; source_name: string; where: { label: string; href: string }; published_label: string; url: string; title_runs: HitRun[]; snippet_runs: HitRun[] | null };

// P2-① 登录（PRD 5.5）：ApplicationController 的 inertia_share 每页都带的两样，加登录页与设置页的字段
export type CurrentUser = { display_name: string; avatar_url: string | null; email: string | null; admin: boolean };
export type Flash = { notice?: string; alert?: string };
export type SharedProps = { current_user: CurrentUser | null; flash: Flash };
export type AuthProvider = "google_oauth2" | "github" | "developer";
export type SettingsIdentity = { provider: "google" | "github"; strategy: AuthProvider; linked_at_label: string | null };
