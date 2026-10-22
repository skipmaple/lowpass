# Tagged title tail quality implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 320px 实际日刊中两个带标签英文标题的末词孤行，保留原文与标签位置。

**Architecture:** 仅 ItemRow 的 tagged、`latinLang(title) === 'en'`、至少两个空白分隔 token 的标题，用声明式尾部 span 保护末两个 token。原空白逐字保留；父 balance、标题行内排版、原链接和标题末端 10px 间距不变。片段有宽度上限且可在超长 token 内断开。

**Tech Stack:** React / TypeScript / CSS，Minitest + Selenium，Vitest + Testing Library；不加依赖。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md` T2、Q4/C4；实际诊断见外部验收目录 `typography-final-lines/README.md`、`diagnosis.md`。

## Global constraints

- 仅改 ItemRow；CJK、单 token、无标签及周刊保留原结构。不扩 Search / Favorites / Mixed / HitText。
- 不改源文字、NBSP、字体令牌、标签内容、链接可读名称与 URL；不用标题特例、命令式 DOM 或新依赖。
- 独立本地工作树测试，不触发生产写入、真实 OAuth 或模型；独立视觉复核前不提交、推送或宣称全样本通过。

## Review focus

- 多个/首尾空白不得被分词归一化；Vitest 比较完整 textContent。
- Inertia 重渲染换文不能遗留片段或改变链接可读名；Vitest 使用 rerender。
- 单 token、CJK、无标签、周刊保持原结构；Vitest 按输入边界覆盖。
- 极长尾词不能横向溢出；片段上限和 anywhere fallback 交真实浏览器验证。
- 片段可能改变原链接分片命中；root 用新构建做 320/768/1440 全样本与触控独立验收。

### Task 1: 重现并修复 tagged title tail

**Files:** Modify `app/frontend/components/ItemRow.tsx`、`app/frontend/styles/tokens.css`、`test/frontend/components/ItemRow.test.tsx`；Create `test/system/title_tail_test.rb`、`docs/design/notes/2026-10-23-title-tail-quality.md`。

- [x] 写真实 Rails / React / 自托管字体的 320px 系统回归：`Tailwind Labs is joining Shopify` + `前端开发`，`Hunting the Wild Vibrotruck` + `电子机械与自动化`。读取标题后代字符 Range，断言多行末行至少两个词、标签同行相邻或整签下一行行首、无横溢。
- [x] 未改生产源码先跑 `bin/rails test test/system/title_tail_test.rb`，保存两个实际失败到外部 fix/red.log。
- [x] 加少量原文/链接/标签/重渲染边界前端回归，实现最小 TitleText 分段与有界 inline-block。
- [x] 跑目标系统与 ItemRow 前端回归，再跑完整 `bin/ci`。保存日志与 source pins。
- [x] 记录实测与限制，将完整 diff 交 root 和独立视觉接受；实现者不自行提交、推送或发布。root 验证 291 字段、72 标签、27 个44×44内接区及全部7页打印；原4个标签保护凹口保留并有旧版配对。证据在外部 typography-final-lines/candidate-matrix/，发布仍待独立授权。
