# Weekly

## Sub-features

- Masthead `周刊` opens the latest published weekly that has visible items, or `/weekly` when there is none.
- `/weekly` is the year archive. A week with no issue is labeled `本周无内容`.
- Opening a week with no sections shows `.state-line` `本周无内容` under the week heading.

## How to get to it (user POV)

Sign in. The masthead link `周刊` uses `latest_weekly_key` from the signed-in page (`Issue.latest_weekly_key`: published weekly issues that have visible items). The footer link `最新周刊` uses the same rule. The archive control on a weekly issue is labeled `归档` and points at `/weekly`.

## Driving it with Chrome

```bash
bundle exec .cursor/skills/verify-lowpass/scripts/drive weekly
```

Sign in the same way as [login](login.md). Click the masthead link whose text is `周刊` (`nav[aria-label="主导航"] a`).

Read `Issue.latest_weekly_key` with `bin/rails runner` before deciding what the screen must show.

- When the key is nil, the URL path is `/weekly` and `p.page-context` is `周刊归档`. A week with no issue shows `本周无内容`. A week that has an issue shows that issue's summary instead, including when the issue is not published with visible items (that is why `latest_weekly_key` can be nil while a row is not `本周无内容`).
- When the key is present, the URL is `/weekly/<key>`, `h1[aria-label]` is that week's `第 N 周` label, and each section source name from `weekly_section_props` is on the page (`h2.source-band-title` is the issue title or the source name; `.source-band-source` repeats the name when a title is present). An empty section list shows `.state-line` `本周无内容`.

The screen and `Issue.latest_weekly_key` disagreeing is a failure.

## Gotchas

- `db:seed` creates the weekly source and no weekly issue, so a cold database starts with `latest_weekly_key` nil. `bin/dev` jobs run the weekly check on the minute tick. After that check publishes a weekly issue with visible items, the masthead no longer opens the archive. Do not delete the issue to restore the archive URL.
- A direct visit to `/weekly/<key>` for a key that is not a real week is a 404 (`Errors/NotFound`), not the empty-week sentence. The empty-week sentence is for a real week key with no sections.
- Weekly items do not get recommendation reasons. Do not wait for a reason on this page.
- Each weekly item's bookmark is the same `FavoriteButton` as on the daily issue, in the item actions (`app/frontend/components/ItemRow.tsx`). The weekly page does not have a second bookmark control.
