# 期级提示与部署帮助链接质量修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除实际期级事实句的末行孤字，并让未配置时的帮助入口有真实 44px 高点击区。

**Architecture:** IssueNotice 的事实句改用段落，让现有 balance 生效；不改全局 state-line 或来源级状态。部署帮助入口复用既有搜索次级链接的流内目标规则，说明与动作拆为现有操作行的相邻flex项，沿用12px间距和换行，保持13px文楷、原生锚点与原文。

**Tech Stack:** Rails/Inertia/React、既有 CSS 令牌、真实 Chrome 字形与点击系统回归。

**Spec:** `docs/superpowers/specs/2026-09-08-mvp-prd.md` §6.4、`docs/superpowers/specs/2026-10-14-award-quality-design.md` T2；既有 lowpass design skill。

## Global Constraints

- 保持原始提示和链接文字，不裁切、缩字、改字号或硬编码换行。
- 普通文字目标高度至少44px；图标、报头导航与收藏另有44×44规则，不混淆。
- 不覆盖相邻备注或禁用按钮的点击区；不改SourceState的既有布局。
- 基于 main c1f4795；不夹带尚未合并的PR69–78，不合并或部署。
- 本地fixture/testDB、外部请求阻断；无真实模型、OAuth或生产业务写入。

## Review Focus

- 日刊空刊与周刊降级都出现孤字，同一组件修复需覆盖两者。
- 生成中、缺期、周刊空态和有附加原文动作的提示不应退化。
- 320px的inline帮助链接会碎成多个矩形，不能用union包围盒冒充实际目标。
- 告警/备份配置的独立分支分别显示或隐藏入口；13px字体与完整句子保留。
- 原生Tab→Enter跳到部署帮助后，下一Tab仍进入该节summary；不人为注入焦点。

### Task 1: 期级事实句

**Files:** `app/frontend/components/IssueNotice.tsx`、`test/system/state_readability_test.rb`。

**Interfaces:** `IssueNotice({ text, children })`不变；事实句成为有块级格式上下文的段落，附加动作仍是后续独立区块。

- [x] 写真实日刊空刊和周刊降级系统回归，在320/375/1440读取自然字形行盒，验证完整原文及末行不只有一汉字。
- [x] 在基线实际运行RED，确认是末行孤字失败。
- [x] 最小实现并GREEN，不动全局state-line样式。
- [x] 冻结真实构建，复核所有实际期级notice文案十宽及正常来源状态对照（最终notice-candidate-v2共58组）。

### Task 2: 帮助链接触控区

**Files:** `app/frontend/styles/tokens.css`、`app/frontend/pages/Admin/Settings/Show.tsx`、同一系统回归文件。

**Interfaces:** `a.field-note`复用`.search-links > a`的流内inline-flex、min-height44px、center与现有断行约束；说明span与帮助a是`.admin-actions`的独立子项，沿用gap12，帮助使用现有`.t`下划线，原生href不变。

- [x] RED：默认未配置两入口的真实目标高度、实际命中与禁用按钮隔离。
- [x] 最小扩展既有选择器，GREEN验证320/375/768/1440与13px字体、文字完整性。
- [x] 用可信点击九点检查真实链接矩形；Tab/Enter跳转和下一Tab的summary落点仍有效。
- [x] 375px严格备注字框点检发现既有不足1px邻接命中带；实际RED后用现有操作行gap12分开说明/动作，保留严格保护检查，不给边界例外。
- [x] 用真实默认/仅告警/仅备份/部分配置GET输入检查独立分支，不伪造props（最终help-candidate-v2共52上下文）。

### Task 3: 交付与范围复核

- [x] 独立审查最终V2完整diff；定向系统3/204与`bin/ci`通过（454前端、856 Rails、80系统），首屏264.58KB≤300KB。
- [x] 封存实际输入/源码/资源、原始行盒与命中、截图和失败尝试；更新品质轮次，不自封奖项分数。空白gap的原始边界命中与核心/中部指标分开，不缩减备注/按钮保护。
- [ ] 创建并附加独立Draft PR，确认最新提交远端门禁；原有发布/模型/用户Chrome问题保持待答。
