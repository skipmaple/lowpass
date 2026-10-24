# Directory return focus implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** 周刊原生「返回板块目录」与下一次 Tab 后，完整焦点轮廓都在视口内。

**Architecture:** 保留原生 fragment、history、details 与立即焦点规则，只给目录落点复用日刊目录既有的 24px 滚动留白。目录小签复用已有的墨色 2px 轮廓与 2px 间距，避免浏览器默认蓝色。

**Tech Stack:** Rails / Inertia / React / CSS；Selenium 原生键盘与计算几何。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md` M7、§7.5；`docs/superpowers/specs/2026-09-08-mvp-prd.md` §6.4、D34。

## Global Constraints

- 只在既有隔离工作区 `menu-opening-input` 修改；保留 `.menu-card` contents hint 与原验收记录。
- 不改 120 / 240ms 动效、减少动态效果、立即焦点、原生 hash / history / details。
- 只用既有 24px 留白与 `var(--ink)` 的 2px / 2px 焦点规则；不扩展视觉政策。
- 独立测试库 `lowpass_directory_focus_test`；只构建 `public/vite-test`；不提交、推送、合并、部署。

## Review Focus

- 375px / 1440px、普通与减少动态效果都检查返回后的 nav 与下一次 Tab 的首个小签，连同 outline / offset 的四边几何。
- 真正的 Enter 激活与 Tab 导航；不以脚本 focus 或模拟 click 替代。
- 目录打开、焦点即时移入、首个小签顺序及 fragment / history 保持原生行为。
- 使用足够长的真实周刊内容，避免短页无法滚动掩盖视口上沿裁切。
- 完整 CI 与生产资产构建由主代理在独立审查后执行；本任务仅报告专项结果。

### Task 1: 复现并修复目录焦点裁切

**Files:**
- Modify: `test/system/keyboard_focus_test.rb` — 真实键盘回归与展开后的轮廓几何。
- Modify: `app/frontend/styles/tokens.css` — 目录滚动留白与小签焦点复用。
- Evidence: 独立私有目录 `m7-directory-focus-candidate-20261024` — RED / GREEN 命令、原始结果与审阅摘要。

**Interfaces:**
- Consumes: 既有 `Weekly/Show` 原生目录与长正文 fixture；PostgreSQL 18、Ruby 3.4.8、Node 24。
- Produces: 最小 CSS diff、375 / 1440 × 两种动效偏好的原生键盘回归。

- [x] **Step 1:** 增加四组原生 Enter / Tab 测试，读取 outline width / offset 扩出的四边；验证焦点与 hash / history。
- [x] **Step 2:** 使用独立库运行新测试；Expected: 因轮廓上沿小于 0 而 RED，非 setup 错误。
- [x] **Step 3:** `.anchors` 添加既有 24px `scroll-margin-top`，`.anchor-chip:focus-visible` 复用墨色 2px / 2px 规则。
- [x] **Step 4:** 重建 test 资产、运行整个 `keyboard_focus_test.rb`；Expected: 新旧测试 GREEN；保留原始诊断数据。
- [x] **Step 5:** 检查 diff、范围与语法风格，交主代理独立审查；不自行提交。

## 执行约定

本任务由主代理明确指定现有工作区与执行方式，例行本地修复无需再次请求许可。完整 CI、生产构建与分支集成由主代理在最终审查后处理。

## 本地专项结果（2026-10-24）

原生键盘四组 RED：4 runs、76 assertions、4 failures、0 errors，失败均为外扩轮廓上沿小于 0。最小 CSS 后整个 `keyboard_focus_test.rb` GREEN：6 runs、119 assertions、0 failures、0 errors；四组返回 nav 与下一次 Tab 小签的完整外扩轮廓上沿约 19.99–20.98px。原生 hash 历史递增与 Back / Forward 通过；RuboCop 和 `git diff --check` 通过。

首轮未设 `CI=true` 时 ViteRuby 误认为测试开发服务器可用，登录页白屏，4 个 setup errors 单独记录，不计 RED。有效 RED / GREEN 均用 `CI=true` 禁用开发代理，并从 `public/vite-test` 读取实际构建资产。完整原始日志、计算 outline / offset 与四边几何保存在独立私有 `m7-directory-focus-candidate-20261024` 包。仅本地候选专项验收，尚未运行完整 CI 或生产资产构建。

## 主代理整合验收

独立整份分支审查无发现。完整本地 `bin/ci` 退出 0：602 前端、895 Rails / 3993 assertions、108 系统 / 8726 assertions。该安全本地调用设置全局 `RAILS_ENV=test`，构建写入 `vite-test`，不能当成新生产包；随后显式去掉该变量重建生产包并独立测量，首屏 265.90KB / 300KB。原误选旧生产包的四组 QA 保留并排除候选结论。正确生产包 `application-zwdeN2O5.css` 在输入前核对新规则，冻结 W43 的四组真实原生操作通过，八个目录 / 小签轮廓完整，原生 hash / history / Back / Forward 保留，独立实际查看八张 PNG。未合并或部署。
