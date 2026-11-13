# Daily issue

## Sub-features

- `/` redirects to the latest daily period key, or to today in Asia/Shanghai when no daily issue exists (`DailyIssuesController#latest`).
- The issue page shows the server's status sentence when the issue is missing, generating, or empty, and the seeded source names when it is published.
- `日刊归档` is `/daily` (footer link, or the calendar date on the issue). It is not the masthead `日刊` link. That link is `/`.

## How to get to it (user POV)

Sign in with `以读者身份进入`. With no `origin`, login redirects to `/`, and `DailyIssuesController#latest` sends that to the latest daily period key, or to today in Asia/Shanghai when no daily issue exists. The masthead brand and the nav link `日刊` both point at `/`. The hidden heading (`h1.visually-hidden`) reads that period key with slashes plus ` 日刊`.

## Driving it with Chrome

```bash
bundle exec .cursor/skills/verify-lowpass/scripts/drive daily
```

Sign in the same way as [login](login.md). Wait for `/daily/YYYY-MM-DD`. Read the period key from the URL. Then read the daily `Issue` row with `bin/rails runner` (`Issue.daily.find_by(period_key:)` and `Issue.daily_props_for`). The screen has to match that row:

- No row, and Asia/Shanghai time is before `Setting` `daily_time` (default `06:00`): `.state-line` is `今日将于 06:00 生成`.
- No row, at or after `daily_time`: `.state-line` is `本期未生成`.
- `state` `generating`: `.state-line` is `生成中，约 1 分钟后刷新`.
- `state` `empty`: `.state-line` is `本期为空刊，管理员已收到通知`.
- `state` `published`: every name from `Issue.daily_source_summaries` is visible in `.source-tab-name`, and `h1.visually-hidden` text content is the period key with slashes plus ` 日刊`. A finalized issue lists only sources recorded in `source_states` (`Issue::Daily.daily_columns`). The seeded daily sources are Hacker News, GitHub Trending, and Hackaday when those columns were recorded.

A published issue that was generated late also shows that status in `.issue-head-status` (`延迟生成于 HH:MM`). The body and the row disagreeing is a failure.

## Gotchas

- `db:seed` creates sources, not issues. `bin/dev` still starts jobs. After 06:00 Asia/Shanghai the minute tick inserts today's issue and fetches the three sources. Once that row exists, a check that requires `本期未生成` fails. Report the row. Do not delete it, and do not stop the tick, to keep the missing-issue sentence.
- Before the first published issue that has visible items, `Issue.latest_daily_key` is nil. The archive still lists today, labeled `缺期` or `待 06:00 生成`.
- Source fetches use the public network. A failed source does not block publish; the column then shows the failed state. Do not stub the adapter to paint `ok`.
