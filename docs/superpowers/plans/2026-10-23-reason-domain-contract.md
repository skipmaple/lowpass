# 推荐理由正文领域校验实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐既有 R-9.3 的正文领域名校验，让只有合法标签、正文没有画像领域名的响应进入既有有限重试。

**Architecture:** 在 `Reasons::Parser.parse(text, allowed_names)` 的长度与标签校验后，检查归一化正文是否包含任一完整合法领域名称字串；名称仅在此比较时使用相同空白归一化，避免误拒绝可配置的连续空白。失败沿用 `Invalid`；生成器、Prompt、预算、模型和存储路径保持现有实现。正文领域与标签可以不同，原 PRD 未规定两者相同。

**Tech Stack:** Ruby 3.4.8、Rails 8、Minitest、WebMock、PostgreSQL 18。

**Spec:** `docs/superpowers/specs/2026-09-08-mvp-prd.md` §5.9 R-9.3、R-9.6、R-9.8、R-9.10；已有 D37 失败保留与预算约定。

## Global Constraints

- 归一化后 20–60 个 Unicode 字符；不截断，标签逐字命中画像名称。
- 不接受去空格或改标点的别名；正文比较两边均按既有规则收敛连续空白，标签仍与原始名称逐字匹配。
- 不扫描、改写或重生成历史理由；旧试验包和原始状态保留。
- 本地测试禁网；所有模型回复由 WebMock 提供，不发新的真实模型调用。
- 新拒绝可能增加既有重试频率，仍最多首次加 2 次，每次请求前检查月预算，失败保留旧字段。

## Review Focus

- 标签合法但正文缺领域名：必须拒绝。
- 正文有另一个合法领域：仍接受，避免擅自新增同标签要求。
- 领域别名与归一化空白：别名不接受，正常空白收敛后完整名称可接受。
- 新拒绝后重试成功：失败译文不得带入成功结果，每次实际请求都记账。
- 新拒绝耗尽预算或连续失败：停止后续请求，旧理由、译文与时间不变。

## Task 1：校验与生成回归

Files: `app/models/reasons/parser.rb`、`test/models/reasons/parser_test.rb`、`test/models/reasons/generator_test.rb`；仅在完整测试揭示不合规成功样本时修正相关测试数据。

- [x] 增加合法标签但无正文名称、别名、任一合法名称与空白归一化的回归；先观察缺校验造成的真实失败。
- [x] 加入最小正文检查及不泄漏输入正文的固定错误 `理由未点名领域`。
- [x] 修正旧测试的成功响应，让其本身满足既有需求；保持原断言与边界长度。
- [x] 用真实生成器加 WebMock 验证新拒绝的记账、有限重试、预算停止、失败译文隔离与旧字段保留。
- [ ] 运行目标回归及完整 `bin/ci`，独立审查完整差异后建立草稿 PR，不合并或部署。

此门禁只证明正文包含合法名称，不核验事实、领域关联强弱或推荐价值，也不把既有模型试验重新判为新运行结果。
