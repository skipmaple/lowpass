# Publication Wrapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [x]) syntax for tracking.

**Goal:** Remove the observed source subtitle and archive orphans while preserving complete text, links, fonts and the approved layout.

**Architecture:** Keep presentation changes local to the existing Weekly and Daily pages. Extend the established balance rule to the missing text containers, then group short semantic units without making long configurable names unbreakable.

**Tech Stack:** Rails 8, Inertia/React, TypeScript, CSS, Minitest system tests with real Chrome and local fonts.

**Spec:** docs/superpowers/specs/2026-10-14-award-quality-design.md §4.2 T2 and §7; .claude/skills/lowpass-design-taste/SKILL.md. Observed cases and root-cause evidence: production-width-matrix-20261023/diagnosis-wrap.md in this task's artifact directory.

## Global Constraints

- T2: 标题用均衡换行（text-wrap: balance），段落用避免孤字（text-wrap: pretty）。
- Preserve all visible source names, counts, states, dates, issue themes, whitespace and href values.
- Preserve the four font roles, existing sizes, mobile 24px margins and archive grid.
- Do not change stored or published issues, global Mixed font splitting, models, prompts or dependencies.
- Only local test transactions may create the frozen reproduction inputs. No live model calls or production writes.

## Review Focus

- Mixed font runs have different glyph heights; cluster character ranges by vertical center, not exact top.
- Long Chinese, English and unbroken custom source names must still wrap inside the metadata column.
- The middle dot separator must not become an isolated line.
- Cross-month and cross-year date ranges must retain their literal text and locally bind each short date.
- Multi-issue archive themes and the 767/768 and 1023/1024 breakpoints must stay complete and readable.

### Task 1: Reproduce and fix the missing title wrap contexts

**Files:** Create test/system/publication_wrapping_test.rb; modify app/frontend/styles/tokens.css.

**Interfaces:** The real Weekly/Show source-band-issue and Weekly/Index archive-label consume unchanged server props. No new public API.

- [x] Add independent real-page regressions for 第 416 期 · 编程已经面目全非 at 320px, the same archive theme at 320px, and Jev 决策模型有什么用 at 1024px. Use the production 32/40 item counts so the desktop meta column has the same width.
- [x] Load the actual text fonts, group grapheme Range rectangles into lines, assert full text/href/font sizes and a final line of at least two visible graphemes. Run the tests and retain the expected RED output.
- [x] Extend the existing local balance selector to these text containers. Run the three regressions and inspect their actual lines.
- [x] Verify multi-issue themes and adjacent breakpoints in the final focused matrix.

### Task 2: Keep each daily source result together when it fits

**Files:** Modify app/frontend/pages/Daily/Index.tsx and app/frontend/styles/tokens.css; extend the same real-page test.

**Interfaces:** SourceMarks still consumes the exact source_marks string and returns the exact same text in the same order.

- [x] Create 10/21–23 test issues with real HN10/GH10-or9/Hackaday7 item counts. At 375px prove Hackaday and its 7 occupy different actual lines before the fix.
- [x] Use a locally bounded inline group for each source result, preserving separator text and existing Mixed font roles. Do not apply unbounded nowrap.
- [x] Assert the source name/count stay on one line when the unit fits, no separator is alone, exact text/href are retained, and an 80-character custom source name with the longest state remains fully visible without overflow.

### Task 3: Bind short date units and accept the whole change

**Files:** Modify app/frontend/pages/Weekly/Index.tsx and app/frontend/styles/tokens.css; extend the same real-page test.

**Interfaces:** range_label remains a server-formatted string; the client only groups its existing date units. It must not recompute period keys or replace whitespace.

- [x] At 320px prove the W41 range 10月5日 至 10月11日 splits a date before the fix.
- [x] Bind the two short dates locally, allowing a line break between them and keeping the existing 15px CJK font.
- [x] Verify cross-month 9月28日 至 10月4日 and cross-year 12月28日 至 1月3日, unchanged text/href and no overflow.
- [x] Run the focused real-page regressions, frontend typecheck/unit tests and complete bin/ci once the candidate is stable. Inspect the exact changed contexts at ten widths and adjacent breakpoints; review actual browser-rendered PNGs.
- [x] Obtain independent whole-diff review, address material findings, commit and prepare a reviewable PR. Do not treat local acceptance as production deployment approval.

## Execution record

Current-session implementation under the existing approved T2 repair scope. The reason-abstention implementation was separately approved on 2026-10-23 and remains in its own branch.

- RED: the real-font reproduction failed for source subtitles, daily source counts, archive themes and short date units. The first balanced subtitle still split 编程 at 320px; a semantic group regression then drove the bounded source subtitle grouping. A long-title regression proved that grouping must allow wrapping.
- Focused GREEN: 8 system tests, 907 assertions; 48 PNGs across 12 widths and long-text/fallback cases. The 32 archive PNGs are byte-identical to the independently reviewed preceding candidate. Final source subtitle pixels receive a separate review.
- The scope removes the observed orphans and preserves full text. It does not promise dictionary-aware Chinese word wrapping for all archive themes.

- Final source subtitle review accepted all 16 PNGs, including 320px and long/fallback titles. First complete CI: Rails and frontend checks passed, but one existing initial search focus assertion failed; unresolved, so CI is not yet accepted.

- Final whole-diff review: no Critical / Important product findings. Deferred minor: explicitly assert both complete multi-issue archive themes in the matrix test; actual full themes remain in the accepted pixel evidence.
- The initial full CI and diagnostic reruns exposed an inactive headless document before the search resize test began. `activeElement` was correct while `document.hasFocus()` and `:focus` were false. Same-handle window activation did not fix it. The test now explicitly emulates a focused/active target, asserts that precondition and retains every original source/375px/1440px focus assertion; both focus emulation and viewport are restored in ensure. This does not prove OS window activation.
- Final complete `bin/ci`: 602 frontend tests, 895 Rails tests, 112 system tests / 9534 assertions, all passing; first screen 265.92 KB. The external diagnostic probe was absent from this gate.
- Visual acceptance uses real system-test Chrome screenshots, individually inspected as image artifacts; it does not claim manual CUA interaction with this local candidate or physical-device coverage.
