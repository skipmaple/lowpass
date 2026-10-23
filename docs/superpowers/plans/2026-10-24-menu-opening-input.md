# Menu opening input implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** 菜单自然展开期间，已显示的「账户信息」接受原生点击并发出正确导航。

**Architecture:** 只尝试在 `.menu-card` 使用 `will-change: contents`，避免裁切动画的合成路径与输入命中不同步。是否有效由实际构建后的原生输入决定；失败则撤回候选，不叠加 CSS 提示。

**Tech Stack:** Rails / Inertia / React / CSS；受控 Chromium 原生输入。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md` M7；MVP PRD §6.4。

## Global Constraints

- 保留向下展开、`--dur-1` 120ms、现有 easing、菜单尺寸和焦点规则。
- 保留 reduced-motion；不延迟焦点、不冻结动画、不等待动画结束才点击。
- 使用相同冻结 Settings 输入；所有业务请求在本机拦截，不触及生产、数据库和模型。
- 本轮仅本地验证及可审阅草稿，不合并、不部署。

## Review Focus

- 375px / 1440px 原生点击在动画仍 running、非 pending、时间小于 120ms 时命中目标。
- 不以截图或命中探针促使绘制同步后再点击。
- 自然展开保留视觉与完整焦点轮廓，没有明显跳动。
- 键盘导航、Escape 返回焦点、减少动态效果保持可用。
- 小菜单额外绘制成本可接受，无全站渲染提示。

### Task 1: 修复并验收展开期间的原生输入

**Files:**
- Modify: `app/frontend/styles/motion.css`
- Evidence: 独立私有目录 `m7-menu-candidate-20261024`，保留脚本、原始结果及审查。
- Existing tests: `test/frontend/components/Masthead.test.tsx`、`Dialog.test.tsx`、`test/system/design_rules_test.rb` 及完整 CI。

**Interfaces:**
- Consumes: 当前 main d233d579；冻结无探针原生控制结果与 Settings 输入。
- Produces: 最小 CSS diff、相同控制器的候选结果、独立审查和验证记录。

- [x] **Step 1:** 写行为验收 oracle，检查可信 pointerdown/up/click 的账户链接目标、一次 held GET/settings、关闭菜单、无意外请求及错误、上下文清理。
- [x] **Step 2:** 对冻结原始控制结果运行 oracle；Expected: 两种宽度因 HEADER 误命中与 GET=0 失败，而非脚本错误。
- [x] **Step 3:** 增加局部 contents hint，构建实际候选资产；不改交互和动效契约。
- [x] **Step 4:** 固定候选输入及脚本，以同一无前置截图/无命中探针原生控制执行一次；Expected: 两宽通过 oracle。失败即回到原因调查。
- [x] **Step 5:** 检查自然视频、键盘和 reduce；通过后执行 `mise exec -- bin/ci`，Expected: 所有门禁通过。
- [x] **Step 6:** 独立整份 diff 审查；仅当证据通过才提交并准备草稿 PR。封存记录，不合并或部署。

## 本地验收结果（2026-10-24）

原始两宽无探针控制通过行为 oracle 确认 RED；候选在 50.8ms / 43.1ms 仍自然展开时正确命中并各发出一次预期导航，oracle GREEN。四组补充键盘 / reduce 通过，独立审查通过。完整 `bin/ci` 退出 0：602 前端测试、895 Rails 测试、104 系统测试，零失败；首屏 265.89KB / 300KB。专项证据位于本机独立 `m7-menu-candidate-20261024` 包；约 25fps 视频只支持自然展开目视检查，不作精确事件帧对齐。尚未合并或部署，草稿提交是下一交付步骤。

后续同一 M7 批次在 PR #92 补充目录返回焦点裁切修复，详见 `2026-10-24-directory-return-focus.md`；菜单已有原生输入证据保留，不重复计为新增验证。
