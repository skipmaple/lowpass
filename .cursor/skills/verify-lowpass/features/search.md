# Search

## Sub-features

- `/search` with an empty `q` is the initial page (heading `搜索`, no `search_logs` row).
- A query the tokenizer accepts navigates to `/search?q=...`, renders `#search-status`, and inserts one `search_logs` row.
- A query that matches nothing renders the empty copy and stores `result_count` 0.

## How to get to it (user POV)

Sign in, then click `搜索` in the masthead (`nav[aria-label="主导航"]`). The field label is `搜索`, the input id is `search-query`, and the submit button in that form is `搜索`. A signed-out visit to `/search` redirects to `/login?next=/search`.

## Driving it with Chrome

```bash
bundle exec .cursor/skills/verify-lowpass/scripts/drive search
```

The script uses headless Chrome against `http://127.0.0.1:3000`:

1. Click `//button[normalize-space()='以读者身份进入']` and wait for `/daily/YYYY-MM-DD`.
2. Click `nav[aria-label='主导航'] a[href='/search']`.
3. Type `zzzxlowpassverify` into `#search-query`.
4. Click `form[role='search'] button[type='submit']`.
5. Wait until the URL contains `q=zzzxlowpassverify` and `#search-status` is exactly `没有找到「zzzxlowpassverify」相关内容。试试更短的关键词，或放宽筛选。`

Observable end state: that status string, that URL, and exactly one new `search_logs` row whose `query` is `zzzxlowpassverify`, `result_count` is 0, and `page` is 1. The script counts rows before the click and reads the new row with `bin/rails runner`. Exit 0 is that match. The development server runs `Search::Runner` against PostgreSQL; the empty count is the real result for this term.

## Gotchas

- One Latin letter, or only symbols, is unsupported: `#search-status` becomes `请输入至少 2 个字母的关键词，或中文、C、C++、C#。纯符号不会执行搜索。` and no `search_logs` row is written. Do not shorten `zzzxlowpassverify` to force a page. A missing row on this journey is a failure.
- An empty query stays on the initial page and writes no row. The rate limit is 60 searches per user per minute; over the limit the status is `操作过于频繁，请等待 1 分钟后重试。` and no row is written.
- `db:seed` does not create items. This query is chosen so a later published issue still returns no hits. Do not replace it with a word copied from an issue title.
