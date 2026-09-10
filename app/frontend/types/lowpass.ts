export type Adapter = "hacker_news" | "github_trending" | "rss" | "ruanyf_weekly";
export type SourceSummary = { id: string; name: string; adapter: Adapter; state: "ok" | "empty" | "failed" | "pending"; home_url: string; last_ok_label: string | null };
export type ItemMeta = { score?: number; comments?: number; comments_url?: string; language?: string; stars?: number; stars_today?: number; issue_no?: number; issue_title?: string; degraded?: boolean };
export type Item = { id: string; title: string; url: string; summary: string | null; section: string | null; author: string | null; published_at: string | null; rank: number | null; meta: ItemMeta; reason: string | null; interest_tag: string | null };
export type IssueState = "generating" | "published" | "empty";
// status 与 time_label 是服务端定稿的期头文案（附录 B）：没有开 SSR，页面上读得到的字符串都得先进 props。
export type DailyIssue = { period_key: string; date_label: string; weekday: string; state: IssueState | null; time_label: string | null; status: string | null; daily_time: string; published_at: string | null; revised_at: string | null; generated_late: boolean; is_yesterday: boolean; prev_key: string | null; next_key: string | null };
export type ArchiveDay = { period_key: string; date_label: string; weekday: string; state: IssueState | "missing"; published_label: string | null; source_marks: string | null };
