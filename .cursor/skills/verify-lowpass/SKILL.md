---
name: verify-lowpass
description: >-
  Use when launching or driving the Lowpass reader web app (Rails, Inertia,
  React) at http://127.0.0.1:3000 and capturing evidence of a real reader
  path — login, daily issue, search, favorites, or weekly — before claiming
  the UI works. Reach for it when landing cold mid-task on this repo.
---

# Verify Lowpass

The primary surface is the reader web UI. `bin/dev` serves it at `http://127.0.0.1:3000` (Puma), with Vite at `http://localhost:3036/vite-dev/` and Solid Queue in the same Foreman process. Secondary surfaces: `/up` (process liveness only), `/health` (JSON dial, often 503 until a daily issue exists and a tick is fresh), and `/admin` (whitelist email only). There is no reader CLI.

One instance. `Procfile.dev` binds port 3000, `config/vite.json` binds Vite to port 3036 on IPv6 localhost, and the development databases are `lowpass_development` and `lowpass_development_queue` on `127.0.0.1:5432`. `bin/setup` names its Docker container `lowpass-postgres`. Do not start a second `bin/dev`.

Reader pages are behind the login wall. Development login is the OmniAuth `developer` strategy: the button `以读者身份进入` GETs `/auth/developer/callback` for `reader@lowpass.test`. Do not sign in with `sign_in_as`, system tests, or an OmniAuth mock. Those use fixtures.

## Launch

From the repo root, with mise already activated (`eval "$(mise hook-env -s bash)"` when `ruby` is not on `PATH`):

```bash
bin/setup
.cursor/skills/verify-lowpass/scripts/launch
```

`bin/setup` is idempotent. If nothing is listening on `127.0.0.1:5432` it starts Docker container `lowpass-postgres` (`postgres:18`, user and password `postgres`). It needs `nc` for that probe; a missing `nc` makes the probe fail and it tries Docker. Then `bin/rails db:prepare` creates the databases, migrates, and on a new database seeds four sources and the default interest areas. It does not create issues.

`scripts/launch` refuses to start when tmux session `lowpass-verify` exists or port 3000 or 3036 is already listening. It runs `bin/dev` in that session (`web` on 3000, `vite` on 3036, `jobs`). The first `bin/dev` installs the `foreman` gem if the executable is missing. Ready means all of these, not merely a process answering:

- `GET http://127.0.0.1:3000/up` is 200 and the body contains `background-color: green`
- `GET http://localhost:3036/vite-dev/@vite/client` is 200 (Vite is not on `127.0.0.1`)
- `GET http://127.0.0.1:3000/login` is 200, the Inertia component is `Login/Show`, and `developer_accounts` includes `reader@lowpass.test`
- the session pane is Foreman and a `solid-queue` process is in that tree

`bin/dev` jobs run `Scheduler.tick` every minute. After 06:00 Asia/Shanghai that tick tries to publish today's daily issue, and the weekly check can publish a weekly issue. Source failures do not block publish. Do not treat that fetch as a fixture you should stub.

## Doctor

```bash
.cursor/skills/verify-lowpass/scripts/doctor
```

Read-only. Exit 0 prints `doctor: ok`. It checks the recorded Foreman pid is alive, its cwd is the repo, `git rev-parse HEAD` matches the revision recorded at launch, the tmux pane pid is that Foreman, ports 3000 and 3036 are owned by descendants of that pid, a `solid-queue` descendant exists, `/up` and the Vite client respond as above, and `/login` offers the reader button. It does not log in. If `tmp/verify-lowpass/run/cookies.txt` exists (written by a drive), `GET /settings` with that cookie must be Inertia `Settings/Show` for `reader@lowpass.test`. A HEAD mismatch means the running process is not this checkout; cleanup and launch again.

## Drive

Harness: headless Chrome via `selenium-webdriver` (Gemfile test group, installed by `bin/setup`) against `http://127.0.0.1:3000`. Chrome must be the system Google Chrome from `docs/development.md`. Rails `allow_browser versions: :modern` rejects an old browser before the login wall.

Each mapped feature is one Chrome session against the already running server. Google Chrome is the binary (`CHROME_BIN`, otherwise `/usr/local/bin/google-chrome`, `/usr/bin/google-chrome`, or `/usr/bin/google-chrome-stable`). Chromium is not a stand-in.

```bash
bundle exec .cursor/skills/verify-lowpass/scripts/drive login
bundle exec .cursor/skills/verify-lowpass/scripts/drive daily
bundle exec .cursor/skills/verify-lowpass/scripts/drive weekly
bundle exec .cursor/skills/verify-lowpass/scripts/drive search
bundle exec .cursor/skills/verify-lowpass/scripts/drive favorites
```

Search selectors, in order:

1. `//button[normalize-space()='以读者身份进入']`
2. URL matches `/daily/YYYY-MM-DD`
3. `nav[aria-label='主导航'] a[href='/search']`
4. `#search-query` receives `zzzxlowpassverify`
5. `form[role='search'] button[type='submit']`
6. `#search-status` text is `没有找到「zzzxlowpassverify」相关内容。试试更短的关键词，或放宽筛选。`

The other commands use the selectors in `features/`. Do not drive them through `bin/rails test:system`.

There is no reader dry-run. `/up` does not render a page. Search hits PostgreSQL through `Search::Runner` in the development process; do not wrap it in WebMock. A journey that needs a published item and finds none fails and says so.

## Evidence

`scripts/launch` creates `.cursor/skills/verify-lowpass/evidence/<UTC timestamp>/` and records that path in `tmp/verify-lowpass/run/meta.env`. That directory is gitignored. Capture doctor on stdout into it:

```bash
EVIDENCE="$(cat tmp/verify-lowpass/run/evidence_dir)"
.cursor/skills/verify-lowpass/scripts/doctor | tee "$EVIDENCE/doctor.txt"
```

Each `scripts/drive <feature>` writes `<feature>/url.txt`, `<feature>/page.html`, `<feature>/screenshot.png`, and `<feature>/result.txt` under that evidence directory. Search also writes `search/search_log.json`. Pass for search means the status string above, the `q=` URL, and exactly one new `search_logs` row (`query` `zzzxlowpassverify`, `result_count` 0, `page` 1) read with `bin/rails runner`. The screenshot shows the page the reader sees; the log row is the side effect (`Search::Log.record` in `SearchesController#show`).

## Cleanup

```bash
.cursor/skills/verify-lowpass/scripts/cleanup
```

Kills tmux session `lowpass-verify` only when its pane pid is the Foreman pid recorded at launch. Does not signal processes by name. Does not delete the evidence directory. After a failed launch or drive, run cleanup before the next attempt.

## Helpers

| Script | Invocation |
|---|---|
| `scripts/launch` | `.cursor/skills/verify-lowpass/scripts/launch` |
| `scripts/doctor` | `.cursor/skills/verify-lowpass/scripts/doctor` |
| `scripts/drive` | `bundle exec .cursor/skills/verify-lowpass/scripts/drive login` (also `daily`, `weekly`, `search`, `favorites`) |
| `scripts/cleanup` | `.cursor/skills/verify-lowpass/scripts/cleanup` |

`doctor` is Python 3 from the base image. `drive` needs the bundle. Feature map: `features/README.md`.
