# Favorite accepted stamp implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 被在途请求忽略的再次点击不得改变盖章，取消失败回滚也不应盖章。

**Architecture:** 复用 FavoritesProvider 已有的同步乐观状态契约：点击前后用 has 读取实际状态，只有 toggle 真正改变状态才修改本按钮的盖章标记。保留现有去重、请求与恢复语义。

**Tech Stack:** React / TypeScript、Vitest、现有生产 Vite 构建与只读浏览器观测。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md` M3；PRD D34 / R-10.5。

## Global Constraints

- 动效沿用 240ms、既有缓动与减少动态规则；不改 CSS 或引入动画库。
- 同一链接只允许一个在途请求，额外点击不排队补做。
- 生产重放全部使用冻结 props 与内存响应，不写真实收藏、不部署或调用模型。

## Review Focus

1. 取消 pending 时再次点击，失败后恢复实心但不盖章：新增回归。
2. 添加 pending 时再次点击，不应摘掉首次操作的盖章标记：新增回归。
3. 无 itemId 的未收藏按钮不接受添加，不应给后续带入状态留下盖章：新增回归。
4. 正常添加、取消、再添加与初始已收藏：保留既有 M3 回归。
5. 失败回滚、恢复凭据、换页保护与同 hash 请求去重：保留 Provider 与收藏页既有测试。

## Task 1: 只让实际状态变化控制盖章

**Files:** `app/frontend/components/FavoriteButton.tsx`、`test/frontend/components/FavoriteButton.test.tsx`；验收笔记 `docs/design/notes/2026-10-23-favorite-stamp-acceptance.md`。

**Interfaces:** 消费现有 `has(urlHash): boolean` 与 `toggle(target): void`。不新增或改变对外接口。

- [x] 增加上述三个回归，运行 `npm test -- test/frontend/components/FavoriteButton.test.tsx`，确认旧源码在盖章断言真实失败。
- [x] 只在同步 toggle 前后状态变化时更新 stamping。
- [x] 同一文件与收藏页测试通过；完整 `bin/ci` 退出 0。
- [x] 固定真实构建并重放四个正常 / 减少动态上下文及取消失败连点反例；比较自然帧、请求数与终态。保留原始失败证据。
- [ ] 独立审查 diff 与原始证据，提交 Draft PR 并验证最新 head 的四项远端 CI；发布与用户 Chrome 验收仍单列。
