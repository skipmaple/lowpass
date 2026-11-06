# Content Font Order Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 去掉异步正文字体表中重复的界面字体声明，保持相同的字形选择、按需加载与阅读布局。

**Architecture:** 真实布局中的 `data-content-fonts` preload 位于 application stylesheet 前。动态 stylesheet 紧接该锚点插入，使 vendor 文楷声明在前、application 中的界面子集声明在后。异步表不再导入整份 `fonts-subset.css`。

**Tech Stack:** Rails 8、Inertia/React、TypeScript、Vite 8.2.4、Vitest、Playwright。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md` D3/D4；`.claude/skills/lowpass-design-taste/SKILL.md` 四字体角色。

## Global Constraints

- 不改字体文件、unicode-range、字体角色、颜色、字号、内容、刊期或数据库契约。
- 正文字体表保持 preload 后异步启用；同一 document 只挂一次，无 preload 时无操作。
- 首屏预算仍为 300 KB，完整 `bin/ci` 是合并门禁。
- 历史实际 CSS +5655 B 的结果保留；新的反事实和当前候选收益分别标明，不能改写旧结论。
- 不部署、不调用模型、不绕过待完成的用户 Chrome 验收。

## Review Focus

- 样式表下载完成顺序与 DOM 顺序不同：浏览器延迟加载对照验证最终字形与请求集合。
- UI、extra、admin 三类中文与非 UI 字：真实字体资源和缺字回退对照，不以 family 名相同代替资源验证。
- 缺少 preload、重复调用、Inertia 后续页面：单测覆盖无操作与幂等，不产生第二份 stylesheet。
- 冷缓存正常/减少动态效果与两个视口：以 production 包和真实 helper 输出测 CLS/资源，禁用测量用逐帧几何读取。
- 未来布局变动破坏 preload 在 application 前的前提：真实布局顺序纳入测试与正式浏览器检查。

## Task 1: 保持异步字体的声明优先级并去重

**Files:**
- Modify: `app/frontend/lib/contentFonts.ts`
- Modify: `app/frontend/entrypoints/fonts-content.css`
- Modify: `app/frontend/styles/fonts.css`（仅同步顺序说明）
- Test: `test/frontend/lib/contentFonts.test.ts`
- Test: `test/integration/head_meta_test.rb` 中真实 HTML 布局顺序。
- Create: `docs/design/notes/2026-10-23-content-font-order.md`

**Interfaces:** `loadContentFonts(doc: Document = document): void`；消费现有 preload，产出同 URL 的唯一 `link[data-content-fonts-applied]`，不增加配置或 API。

- [x] 添加功能单测：具有 preload 与 application stylesheet 的 document，调用后 applied stylesheet 在 application 前；href 原文、无 preload、二次调用继续通过。
- [x] 运行该文件并确认新顺序断言在旧实现失败（1 failed / 3 passed）。
- [x] 将动态 stylesheet 插到 preload 后；删除异步表对 `fonts-subset.css` 的重复 import，更新相关说明。
- [x] 运行单测并补真实 Rails 布局顺序断言；布局前提不成立时先修正契约，不能删除 glyph 范围来凑体积。
- [x] 对固定 c1f 源码和候选各做一次同锁 production 构建，逐资源 Ruby/Zlib gzip 比较全部 CSS 与首屏。
- [x] 真实浏览器核对同一冻结日刊的冷首载、字体请求、三类 UI/正文/四字体角色、逆序加载、幂等、375/1440 终态几何和像素。Chrome / WebKit 对照通过；Firefox 启动环境阻塞单列，不计通过。仅性能阶段不读几何，稳定后才截图比较。
- [x] 独立审查代码与构建、CI 证据；一次完整 `bin/ci`，记录现有告警和边界。浏览器最终回执提交前再审。
- [ ] 提交并创建独立 Draft PR，远端门禁全绿后保留用户 Chrome 与发布门槛。
