# 账户头像与周刊来源标题实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让真实头像请求失败有稳定占位，并消除已证实的 320px 周刊来源末行孤字。

**Architecture:** Settings 页面局部 URL-keyed 图像状态复用原人像占位；来源 h2 复用全局已有 T2 balance 规则。两个独立候选经独立评审后按原样组合，组合后完成 CI 与生产构建 GET 验收。

**Tech Stack:** Rails8 / React / TypeScript / Vitest / Minitest / Chrome。

**Spec:** docs/design/notes/2026-10-23-account-source-quality.md；PRD §6.4；Lowpass design taste 的字体与既有令牌。

## Global Constraints

- 不改变账户认证、显示内容、已发布刊期、图像处理或外部请求权限。
- 保留 20px 头像图标、48px 既有头像占位、no-referrer 和装饰性语义。
- 仅改变来源标题的换行策略，不硬编码来源、br、缩小字号或移动链接。
- root 独占默认 Rails 测试数据库；worker 仅前端与无 DB 的候选渲染/自有浏览器 GET。
- 不合并其他待审 PR，不部署。

## Review Focus

- 同 URL 字段更新不无限重试；换 URL / null / 回原 URL 可重试。
- error 必须移除破图；成功图保持，身份字段与占位几何稳定。
- 320px 原标题末行至少两汉字，375px 仍一行，字体真实加载。
- 均衡换行适用于 SourceBand 类而非单个文字；不覆盖打印换行规则。
- 浏览器失败与修正的测试探针必须保留，不由 props 手写或 DOM/style 注入证明成功。

## Task 1: 头像回归与修复

- [x] Settings error 与 URL 更新测试先 RED，局部最小实现后 GREEN。
- [x] 前端完整套件、类型与构建检查。
- [x] 冻结源码与独立静态评审。

## Task 2: 来源标题回归与修复

- [x] 真实系统测试 375 单行、320 孤字先 RED。
- [x] 仅加入 T2 选择器，相同测试 GREEN。
- [x] 真实 GET、实际字体与 Range 行几何检查。

## Task 3: 组合交付

- [x] 组合源码与 worker 冻结字节比对，完整 bin/ci。
- [x] 最终同构建真实 GET / 自有浏览器验收与 root 视觉复核。
- [ ] 更新设计记录，提交 Draft PR，核对远端 head 门禁，保存失败与 receipt；不发布。
