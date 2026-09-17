# Lowpass UI/UX Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the approved 2026-09-17 page-by-page review while preserving Lowpass's paper publication identity.

**Architecture:** Extend the existing Rails props and React components; improve shared navigation and controls before page-specific workflows. Keep authentication, job execution and immutable publication rules intact. Use focused behavior regression tests, then real-browser responsive checks.

**Tech Stack:** Rails 8, Inertia 3.7, React 19, TypeScript, PostgreSQL, Vitest and Minitest.

**Spec:** The user-approved `Lowpass-UIUX-逐页评审.md` (2026-09-17); archived in the current task outputs. Exact implementation requirements from it are reproduced below. Existing product requirements: `docs/superpowers/specs/2026-09-08-mvp-prd.md` and `.claude/skills/lowpass-design-taste/SKILL.md`.

## Global Constraints

- Preserve single-column reading, warm paper `#E8E3DA`, ink `#1D1D1B`, existing font roles and 1px/2px rules; green retains only its three established roles. No decorative cards, shadows within paper, rounded controls, new marketing sections or new dependencies.
- Chinese uses Wenkai; English content uses Newsreader; numbers and marks use Maple Mono; Bodoni is reserved for branding. Font sizes use existing tokens.
- Every page must fit at 320, 375, 390, 481, 600, 768, 1024 and 1440 CSS pixels, without document horizontal overflow or overlapping controls. Mobile margins and article padding remain 24px. Interactive navigation/form/action targets are at least 44px high, icon controls at least 44px square.
- Keep admin authorization, audit logs, server-side validation, immutable publications and background job concurrency unchanged. Do not execute real fetch, model or alert requests during testing. No real OAuth, deployment, push or merge as part of implementation.
- Use typed Inertia props. Do not hide overflow to conceal a broken layout. Keep source choice in URLs and search back/forward state correct.
- Behavior fixes receive meaningful failing-then-passing tests. Reversible visual/copy edits receive browser checks, not tests that mirror CSS or implementation details. Tests use local fixtures, no external network.
- All work occurs in this isolated branch. Use `mise exec -- ...` with a non-login shell. Agents must not spawn other agents. Root handles browser walkthrough and final CI; implementers may run scoped tests.
- Original review's conditional P3 extensions (month jump after history grows, user search after growth, links from job classes to business entities, full Mission Control translation) remain explicitly future work, not new product requirements. The paper-texture change is a reviewable restrained visual adjustment, not a claim of user research.

### Task 1: Shared shell and reader journeys

**Files:**
- Modify `app/frontend/components/{Layout,Masthead,PageHead,Footer,SourceTabs,ItemRow,Dialog,Toast}.tsx`, `app/frontend/pages/{Login,Daily,Weekly,Settings,Errors}/`, `app/frontend/styles/tokens.css`, `app/frontend/entrypoints/application.tsx`, `app/views/layouts/application.html.erb`, `public/500.html`.
- Modify relevant issue presentation/controller props and `app/frontend/types/lowpass.ts` only as needed for latest-readable entries and reason availability.
- Update relevant tests under `test/frontend/components/`, `test/frontend/pages/`, `test/controllers/`, `test/models/issue/` and the Inertia test support if Head is introduced.
- Document approved design deltas in PRD and design tokens (responsive breakpoints, text measure, mobile 3-line summaries, factual login text, quieter texture).

**Interfaces:** Preserve existing public component APIs unless extended with optional props. PageHead supplies a document title with optional explicit context; all non-PageHead views set their title. Inertia title suffix is ` · Lowpass`. Default Layout supplies exactly one `main`, a skip link, global flash feedback; do not duplicate admin flashes later. Dialog remains compatible with existing callers but defaults focus to cancel and locks the background.

- [ ] Add behavior regressions: menu arrow/Home/End navigation + Escape/return focus; Dialog initial cancel focus + restoration; reason generation has per-item busy/result/error feedback and disables unavailable operation with settings link; missing issue has a useful latest-readable action; weekly navigation points to latest readable content.
- [ ] Run scoped tests and capture expected failures. Example commands: `mise exec -- npm test -- test/frontend/components/Masthead.test.tsx test/frontend/components/Dialog.test.tsx test/frontend/components/ItemRow.test.tsx`.
- [ ] Fix F01/F02/F06/F08: responsive masthead/source tabs throughout 320–1440px, 44px hit areas, lang=zh-CN, main/skip link/h1/title, available/busy/result/error reason controls. All feedback must describe actual server outcome, not assume success. Unconfigured model and no enabled interests should explain unmet prerequisites.
- [ ] Improve Login with `每天一期技术日刊，登录后阅读`, per-provider pending text, retryable nearby errors; preserve existing authenticated flow. Rename Settings to `账户信息`, remove duplicate identity heading data, move logout to secondary session action, clarify 30-day inactivity/90-day maximum and same verified-email account merging versus account switching.
- [ ] Improve daily header spacing and source index compactness; cap reading measure; mobile summaries 3 lines; add source-directory return at column end. Preserve date and source navigation. Missing-page repeated status becomes one fact and one useful reader action; admin may backfill through existing endpoint with visible progress.
- [ ] Give archives explicit `日刊归档`/`周刊归档` context and latest-readable links; show understandable full source names instead of unexplained HN/GH/HAD. Emphasize source issue/theme in weekly rows. Top navigation goes to latest weekly content with archive still reachable.
- [ ] Weekly directory must expose all sections on narrow screens, with each section offering return to directory; consolidate duplicated single-item section/title while preserving heading levels and search item anchors. Footer says `下期日刊`.
- [ ] Make 403/404 facts real h1 with adequate recovery targets. Replace 500 with a self-contained Chinese static paper/ink error page and home/reload action, without application resources.
- [ ] Keep paper texture restrained. Update existing design requirements so approved changes do not contradict them. Run scoped tests, frontend typecheck and relevant Rails tests; commit and self-review.

### Task 2: Search state and mobile search

**Files:** `app/frontend/pages/Search/Show.tsx`, `app/frontend/components/SearchFilters.tsx`, search-specific styles in `app/frontend/styles/tokens.css`, relevant frontend and system tests.

**Interfaces:** Consume the shared shell/title conventions from Task 1. Draft query belongs to the Search page and is passed to SearchHead and SearchFilters; avoid independent stale draft copies. Keep existing server query API and URL format.

- [ ] Add failing regression: enter `rust` without submitting, switch publication/source/date; draft survives and query used in request is rust. Add clear-button/refocus and empty-action coverage; browser history check belongs in system tests if it cannot be proven with the existing router mock.
- [ ] Run `mise exec -- npm test -- test/frontend/pages/SearchShow.test.tsx test/frontend/components/SearchFilters.test.tsx` and record expected red output.
- [ ] Lift draft state; choosing a filter immediately queries using current trimmed draft. Synchronize draft on genuine navigation (including back/forward) without wiping edits on unrelated renders. Keep dates/source/range/sort correct.
- [ ] Keep mobile search input/button in one row, add accessible explicit clear button, autofocus initial input. Collapse advanced filters on mobile with summary of active conditions; retain obvious sort/count, and make hidden controls inaccessible until expanded. Use focus continuity and aria-live result count/loading text.
- [ ] When empty with no active narrowing filters, offer `修改关键词` to focus/select input; with active narrowing filters offer effective `清除筛选`. One page has no pager. Preserve URL and navigation semantics.
- [ ] Run focused tests/typecheck, update changed existing expectations if they encode superseded UI, commit and self-review.

### Task 3: Source and admin settings forms

**Files:** `app/frontend/components/{SourceForm,Field,SegButtons,InterestAreaRow}.tsx`, `app/frontend/pages/Admin/Sources/{New,Edit}.tsx`, `app/frontend/pages/Admin/Settings/Show.tsx`, appropriate styles, model settings props/validation when required, corresponding frontend and Rails tests.

**Interfaces:** Use Task 1 Dialog's safe focus and shell feedback; retain all source config payload shapes and constraints. The root will deliver the user's currency clarification before model-unit work; if not supplied, preserve unknown legacy accounting semantics explicitly and require unit selection before claiming a currency for stored amounts.

- [ ] Add failing behavior regressions for stale test results after config changes (including a response arriving after an edit), dirty-only navigation protection, fixed repository readonly, independent interest-row busy/errors and delete confirmation.
- [ ] Run scoped frontend tests first; use existing validation tests for backend changes. Do not add tests merely checking a CSS class, text token or implementation copy.
- [ ] F04: source type group wraps, every option visible; label `来源类型`. Fields use max-width:100%, numeric input type/inputMode/min/max from actual validation, time inputs for schedule, required/error hints with aria linkage. Fixed Ruanyf repository is readOnly and copyable.
- [ ] Test button says `测试中…`; results show tested time and preview. Editing any configuration invalidates old result with `配置已变化，请重新测试`; reject stale async responses. Save says `正在保存…`, result near action. Keep failed-test saving as permitted behavior with explanation. Editing heading includes source name; dirty edits show status and protect both browser unload and Inertia navigation, while legitimate save/cancel confirmation does not double-prompt.
- [ ] F05: interest areas become vertical field groups on mobile with full-width keyword input and visible per-row actions. Each row has labels, independent submission/error/success state, enabled checkbox adequate target and delete confirmation. Preserve data on failed saves.
- [ ] Admin settings gets section directory and anchor targets; scope-specific save labels `保存调度`/`保存模型设置`, local saving/success/error states, both schedule fields clearly Asia/Shanghai. Units next to input/output prices per million tokens; monthly cap nearby `0 = 不限`; actual accumulated cost same unit, no silent conversion/relabel of legacy cost.
- [ ] Replace raw docs path with openable in-page deployment configuration help including actual env variable names from docs/development.md, secret-only server environment instructions, no secrets. Disabled controls visibly unavailable with nearby reason. Do not expose secret values.
- [ ] Run focused tests/typecheck/relevant Rails validation tests, document accounting-unit decision, commit and self-review.

### Task 4: Admin management lists and queue context

**Files:** `app/frontend/components/{Table,AdminPage,AdminNav}.tsx`, `app/frontend/pages/Admin/{Sources/Index,Sources/Runs,Issues/Index,Users/Index}.tsx`, relevant CSS/controller props if necessary, minimal Mission Control view overrides and tests.

**Interfaces:** Consume shared safe Dialog/title/flash behavior and responsive field components. Admin lists must not duplicate global flash announcements. Maintain existing job hooks and endpoint semantics. Inspect installed engine templates before overriding and preserve its forms, CSRF and authorization.

- [ ] Add failing behavior regressions for state-aware today's publication action, per-operation pending/outcomes, refetch target confirmation and mobile disclosure semantics. Preserve tests for authorization and audit writes.
- [ ] F07: narrow lists show identity, health/status and common actions without horizontal searching; use grouped mobile rows/disclosures with full labels and desktop table preserved. Technical fields may be secondary. Ensure missing values use a consistent dash. Source name plus adapter/grouped details replaces duplicated dominant columns; edit/records primary, test/state-changing actions secondary.
- [ ] Runs prioritizes status/error, expandable long errors, button `重抓最新一期 · <date>` and confirmation explicitly targeting latest issue/source. Use Mixed title through shared PageHead. Do not accidentally retarget a historical row.
- [ ] Issues navigation `刊物管理`, column `日期 / 周次`; one page primary `生成今日日刊` or `重抓今日日刊` according to actual data, secondary row backfill; pending labels and outcomes for backfill/reasons/refetch. Add simple local `待处理` filter for missing/failed generation or incomplete reasons if grounded in available props. Disabled actions explain why. F04 refetch dialog uses vertical native radios, labels fully visible, confirmation names issue and source.
- [ ] Users uses grouped identity/email/role/last login on mobile, readonly whitelist rule above list. Do not add account editing or speculative user search.
- [ ] AdminNav includes `任务队列` using ordinary full-page link to engine. Queue views get return-to-admin, timezone explanation (use actual configured time zone), visible overflow continuation in tabs, Blocked explanation, clear Run now/Discard contextual confirmation, Workers empty message and no `1 / 0`. Preserve utility styling, all eight engine views, technical job classes and engine actions. Avoid full translation or unrelated features.
- [ ] Run focused frontend/relevant Rails tests, typecheck, commit and self-review. Root runs final full CI and real-browser walkthrough over all page classes.
