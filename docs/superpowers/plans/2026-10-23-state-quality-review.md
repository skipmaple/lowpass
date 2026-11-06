# 异常状态阅读质量修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 保留日刊来源状态事实，消除没有正文目标的跳转与失败头像的破图。

**Architecture:** 日刊已经用期级 notice 代替 generating/empty 的来源正文，目录据此切换为静态来源清单；已发布来源仍使用原生锚点。头像失败移除覆盖账户图标的图片，复用现有图标，不改账户菜单。

**Tech Stack:** Rails 8、Inertia、React、TypeScript、Vitest、真实生产构建与隔离的 Chrome。

**Spec:** `docs/superpowers/specs/2026-09-08-mvp-prd.md` §6.2、D35；`.claude/skills/lowpass-design-taste/SKILL.md`。

## Global Constraints

- 来源失败或无新内容的事实仍在目录展示，不伪造正文。
- 不修改已发布数据、模型、生产、OAuth 或未合并 PR 的内容。
- 复用现有字体、图标、尺寸和视觉表达，不新增依赖。
- 浏览器使用真实控制器 GET 导出的 HTML/props 与实际构建；外部请求在出网前阻止。

## Review Focus

- generating/empty 不应把键盘用户带入无目标链接；事实和来源顺序保留。
- published 的 failed/empty 来源也有真实正文，必须保留跳转和返回目录。
- 生成中轮询发布后恢复真实锚点，不改变阅读位置。
- 头像加载失败、同 URL 重渲染及新 URL 更新使用合理回退。
- 账户按钮名称、菜单键盘行为和原生 summary 的展开与焦点不退化。

### Task 1: 日刊来源的真实跳转

**Files:** `app/frontend/components/SourceDirectory.tsx`、`app/frontend/pages/Daily/Show.tsx`、`app/frontend/styles/tokens.css`、`test/frontend/pages/DailyShow.test.tsx`。

**Interfaces:** `SourceDirectory({ sources, navigable })`；`navigable` 来自该次渲染是否存在来源正文。静态模式是带来源名称的非交互列表；导航模式保留既有 nav、a 和焦点目标。

- [x] 添加 generating、empty 的 RED 测试：3 个来源事实仍可见，无来源导航和无目标链接；无来源正文。
- [x] 添加 published failed/empty 的目标完整性与 generating→published 重新渲染测试。
- [x] 运行定向测试，确认新增回归因现有死链接失败。
- [x] 最小实现静态清单，静态项不使用链接悬停和指针；导航项保持原有样式。
- [x] 定向测试通过，真实浏览器比对布局、Tab、跳转与轮询恢复。

### Task 2: 头像失败回退

**Files:** `app/frontend/components/Masthead.tsx`、其既有前端测试。

**Interfaces:** 使用当前头像 URL 的本地失败状态；失败后保留既有 user Icon，新 URL 可尝试加载。

- [x] 先测试自然 image error 后没有破图、按钮名称保留、同 URL 不立即重试与新 URL 可加载，记录 RED。
- [x] 最小实现并运行现有 Masthead 测试。
- [x] 真实浏览器阻止 fixture 的无效头像请求，检查回退和菜单操作。

### Task 3: 完整验收与交付

**Files:** 本计划与验收记录；已授权桌面 40px/手机 26px 品牌文档一行纠偏。

- [ ] 补齐真实失败来源、收藏和后台页面的原十宽验收，五类原生 summary 验收与缺口分别记账。
- [x] 运行 `npm test`、类型检查、`bin/ci`；攻击完整 diff 并独立评审。
- [ ] 冻结真实候选构建、HTML、props、截图与原始观测，校验哈希；只报告实际证据边界。
- [ ] 提交独立 Draft PR，附上工作树与 PR，确认远端门禁；不合并或部署。
