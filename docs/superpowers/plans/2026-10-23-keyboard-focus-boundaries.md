# Keyboard Focus Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复实际键盘验收中发现的对话框首尾停点与账户菜单开场按键重复处理，使焦点始终符合当前选中项和弹层状态。

**Architecture:** 保留 Dialog 的原生中间 Tab / radio 箭头导航，仅按当前单选组代表项计算首尾；焦点暂落在纸卡本身时，双向 Tab 都回到框内按钮。账户按钮已处理的打开方向键不再传给同一次事件中新增的菜单监听器。

**Tech Stack:** React / TypeScript、Vitest / Testing Library、Rails Minitest / Selenium Chrome。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md` M7、CHECK5；PRD §6.4；WAI-ARIA APG radio、modal dialog、menu button。

## Global Constraints

- 基于 main `c1f47954` 独立提交；不依赖待发布的 PR #73 字体调整。
- 只修改键盘焦点与已处理事件的传播，不引入依赖或新的视觉令牌。
- 不改来源选择、删除或提交契约，不改已发布刊期或历史理由。
- 真实业务操作的浏览器验收全部由本地内存响应夹具应答；完整 CI 沿用测试库 fixture / seed。
- 不部署、不调用模型、不重试锁定用户 Chrome 或已知 Firefox 启动阻塞。

## Review Focus

- 第二、第三来源选中后，确认 Tab 回当前已选项，已选项 Shift+Tab 回确认；箭头选择仍实时生效。
- radio 组按同一 form owner 和非空 name 区分；无名控件独立，不因邻组的 checked 丢失边界。
- busy 全禁用时 Tab 保持纸卡，失败恢复按钮后从纸卡双向 Tab 进入按钮。
- 点击打开菜单、菜单内方向键 / Home / End、Escape 返回按钮保持原行为；首次打开方向键只处理一次。
- 关闭对话框后，滚动、inert 与触发点恢复；成功删除的自定义标题返回由真实 partial 响应验证。

## Task 1: Dialog 的实时单选停点与纸卡焦点

**Files:**
- Modify: `app/frontend/components/Dialog.tsx`
- Test: `test/frontend/pages/AdminIssuesIndex.test.tsx`
- Test: `test/frontend/components/Dialog.test.tsx`
- Test: `test/system/keyboard_focus_test.rb`

**Interfaces:** 保留 `DialogProps` 与回调；在每次 Tab 读取当前 DOM 状态，首尾 radio 以当前 checked 代表项参与边界判断；没有 checked 时保留组内首项，当前产品始终预选来源。

- [x] 为实际选源页面添加键盘单测：取消 → Shift+Tab 首源 → ArrowDown 第二源，双向循环停在第二源；再次箭头改选第三源后循环随之更新。
- [x] 为 Dialog 添加 busy=true → false 的双向 Tab 断言，以及不同 form / 无名 radio 的独立停点断言。
- [x] 添加真实系统测试，在现有管理员与刊物 fixture 上用原生按键复现选源焦点离框；运行并保留实际失败。
- [x] 只修正单选组边界与纸卡本身的 Tab 入口；不扩成通用 tabbable 引擎。
- [x] 运行相关单测与原生系统回归通过，并在两种宽度的 production 包夹具重放既有失败轨迹。

## Task 2: 菜单打开方向键只处理一次

**Files:**
- Modify: `app/frontend/components/Masthead.tsx`
- Test: `test/system/keyboard_focus_test.rb`
- Existing coverage: `test/frontend/components/Masthead.test.tsx`

**Interfaces:** 账户按钮 ArrowDown 打开首项、ArrowUp 打开末项；打开后的菜单键盘协议与链接、登出回调保持原契约。

- [x] 用真实系统测试复现原生产组件的首次 ArrowDown / ArrowUp 跳项；现有 jsdom 首尾测试已通过，不能把它当本轮失败证据。
- [x] 阻止已处理的打开方向键继续冒泡给新挂载的 document 菜单监听。
- [x] 既有 Masthead 单测与系统回归通过；本地夹具核对两宽首尾、菜单内方向键 / Home / End / Escape。

## 交付

- [x] 独立代码与原始基线浏览器证据审查；一次完整 `bin/ci`，首屏仍须低于 300 KB；候选重放完成后另审。
- [ ] 补设计验收 note，保留失败、修正与夹具限制；提交独立 Draft PR，核对最新远端门禁。
