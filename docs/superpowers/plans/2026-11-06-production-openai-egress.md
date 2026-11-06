# Production OpenAI Egress Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement and verify each task in this session.

**Goal:** Production OpenAI requests use a private Los Angeles Tailscale proxy; connection failures or exhausted OpenAI credits fall back directly to the existing SiliconFlow DeepSeek model. Development and unrelated traffic keep their existing paths.

**Architecture:** Tinyproxy listens only on the Los Angeles Tailscale IPv4 address, permits only the Hong Kong production node, and allows only api.openai.com on CONNECT port 443. Rails selects this proxy explicitly for production OpenAI calls. The existing model operation/ledger/budget gate remains responsible for retries and persistence.

**Tech Stack:** Rails 8, Net::HTTP, PostgreSQL 18, Tailscale, Ubuntu Tinyproxy, systemd, Kamal, GitHub production Environment Secrets.

**Spec:** User approved the dedicated-model-egress approach and direct SiliconFlow fallback in this conversation on 2026-11-06.

## Global Constraints

- No default-route, system-wide proxy, development settings, or unrelated application changes.
- Keep TLS verification end-to-end; never intercept OpenAI TLS or put API credentials on the proxy.
- Secrets remain in GitHub production Environment and deployment environment; no plaintext keys in source or logs.
- A connection/CONNECT tunnel failure before sending a model request may fall back once. HTTP 401/403, ordinary rate-limit 429, invalid output and TLS certificate errors do not trigger fallback.
- An in-flight disconnect is recorded as a failed attempt; the existing bounded retry then re-evaluates the route. Do not hide a second potentially billable request inside a completed connection.
- Record actual provider/model, currency, token classes and a frozen price snapshot; keep OpenAI USD and SiliconFlow CNY totals separate. No silent FX conversion.
- User confirmed no purchased OpenAI balance and no auto-recharge. Fall back on explicit exhausted-credit codes. SiliconFlow has no independent cap; retain usage and actual time-based model rates.
- Preserve D38/D39 protocol, immutable issues, concurrency, operation stop and budget controls.
- Port the previously approved bounded body/README evidence reader and strict no-title-only generation rule as a cohesive prompt/parser/generator change; do not ship unfinished frontend work.
- Work from production main in this separate worktree; do not deploy the unfinished PR #145 integration.

## Review Focus

- Development with production environment variables must still use its original provider and direct connection.
- Only api.openai.com may use this proxy; no redirects or credentials sent to other destinations.
- Rejected/rate-limited responses and transport failures after sending a request must not silently trigger another provider call.
- Fallback responses and parsing failures must use the fallback model metadata/prices in the ledger.
- Both services unavailable must preserve the existing retry ceiling; restoration must prefer OpenAI again.

## Tasks

- [x] Verify Hong Kong to Los Angeles Tailscale connectivity and SSH identities.
- [x] Add failing provider/ledger regression tests for scope, transport failover and actual-provider accounting.
- [x] Implement scoped proxy selection, frozen fallback configuration, connection-boundary failover and ledger metadata.
- [x] Add deployment variables, restrictive proxy installer and operator runbook; update ADR process budget.
- [x] Verify private-only proxy binding, source/target denial and OpenAI TLS connectivity from the production container.
- [x] Run local Ruby/frontend/security checks and independent review (Rails 1107, frontend 702, system 194 passed); require GitHub CI before release.
- [ ] Deploy only the focused release with GitHub-held keys, configure the primary provider with an audit record, and verify one real request through each route. Do not regenerate historical issues in bulk.
- [ ] Verify existing public health, direct news/backup network paths and unchanged development configuration; document rollback.

## Verification notes

- Local browser tests use `CI=1`, matching GitHub, to use built assets. macOS Ruby timed socket detection falsely reports an absent Vite server as available; no application or development settings were changed to work around it.
- Local Brakeman analysis: zero warnings; installed 8.1.0 matches the registry checked over IPv4. Its latest-version wrapper cannot complete the local IPv6 TLS request. GitHub must pass the unmodified wrapper.
- Branch-history gitleaks scan must be clean; the all-ref local scan also sees unrelated unmerged worktree history. No allowlist or CI security gate was relaxed.
- Production frontend budget remains 300 KiB in this focused release (275.12 KiB measured). The three-theme changes and their separate approved budget remain in PR #145.

- GitHub audit surfaced newer upstream advisories for the existing lockfile. Updated only patch releases of Rails (8.1.4.1), Rack (3.2.8), rails-html-sanitizer (1.7.2), Loofah (2.25.3), Nokogiri (1.19.7), and Addressable (2.9.2); refreshed advisory database reports no vulnerabilities. No security exemptions added.
