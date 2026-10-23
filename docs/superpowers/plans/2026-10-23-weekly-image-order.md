# 周刊配图顺序 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 新抓取周刊保留可证明的原文图文顺序，旧数据完整兼容。

**Architecture:** 原解析器输出仅在内存使用的 image_body；适配器证明最终纯文本段落边界后在既有 meta 写可选 image_positions。WeeklyContent 严格验收整个数组后穿插原有媒体组件，任一异常走完整旧展示。

**Tech Stack:** Rails 8 / Ruby 3.4、React / TypeScript、Minitest、Vitest、现有 PostgreSQL 18 与原生 Chrome QA。

**Spec:** `docs/superpowers/specs/2026-10-23-weekly-image-order-design.md`

## Global Constraints

- 不改已发布 Item/Issue；不新增图片、图片处理、旁路缓存或网络请求。
- content 仍为纯文本且上限 50000 字；summary 仍为 500 字；其他已有字段不变。
- 可选位置最多处理 128 张现有图片；无可靠全量映射时完整回退。
- 颜色、字号、字体与媒体版式沿用既有设计令牌。

## Review Focus

- HTML/跨行 Markdown 清洗可能改变前缀：必须证明与最终 content 相等，否则回退。
- 标题前图或标题括注可能错删一段：真实原文反例验证标题剥离后的边界。
- 重复/无效/归一化碰撞 URL 可能部分重排：必须整条回退。
- 错误元数据或旧 summary 回退可能丢图片：前端保留原展示及所有有效图片。
- 段间图片失败可能留下空块或错序编号：保留完整正文、全条目编号与既有失败收起。

### Task 1: 生产位置元数据

**Files:** `app/models/adapters/ruanyf_weekly/markdown.rb`、`app/models/adapters/ruanyf_weekly.rb`；新增 `app/models/adapters/ruanyf_weekly/image_positions.rb`；测试 `test/models/adapters/ruanyf_weekly_test.rb`。

**Interfaces:** 解析条目新增内部 `image_body: String`。`Adapters::RuanyfWeekly::ImagePositions.for(body:, content:, image_urls:) -> Array<Integer> | nil` 返回清洗后段落边界，content 为 `SummaryCleaner.content(item[:summary])` 的最终值，image_urls 为尚未绝对化的原序列；须重扫 body 的未去重出现序列检测重复，适配器还须验证绝对化没有丢弃或碰撞后才加入 meta。Entry 继续使用原始 item[:summary]，不二次清洗最终值。

- [x] 保存 20 期离线现有条目基线（外部 QA 文件，不入生产契约）：697 条、529 条带图、715 张配图，单条最多 7 张。
- [x] 写并运行失败回归：393 耳机 positions=[1]、专题段中图、封面图在正文前、相邻两图同位置；保持原有所有字段。
- [x] 写失败边界回归：行内、重复/非法 URL、缩进/围栏/HTML代码中的图片、清洗前缀不一致、50000 字上限及超128图均无新位置，旧图片/正文仍保留。
- [x] 实现 image_body 与 ImagePositions.for；不修改 Entry、生成器或清洗器。
- [x] 运行 `bin/rails test test/models/adapters/ruanyf_weekly_test.rb test/models/adapters/entry_test.rb`，确认通过。
- [x] 再导出 20 期结果逐条比较旧字段，记录新增位置覆盖和回退原因。

### Task 2: 按位置显示周刊正文和既有图片

**Files:** 新增 `app/frontend/components/WeeklyContent.tsx`；修改 `ItemRow.tsx`、`types/lowpass.ts`、`styles/tokens.css`；测试 `test/frontend/components/ItemRow.test.tsx`。

**Interfaces:** `WeeklyContent({ item }: { item: Item })` 负责纯文本段落与 WeeklyMedia；ItemMeta 增加 `image_positions?: number[]`。

- [x] 先写失败 DOM 顺序回归：介绍段 < 耳机图 < “上图中”段，所有文字仅一次；同边界多图保持次序。
- [x] 写非法/缺失位置（非数组、越界、负数、非整数、逆序、数量不匹配、无 content）全部回退及已定位图失败的回归。
- [x] 移动原 WeeklyMedia 到 WeeklyContent，保留原尺寸/请求/错误/编号逻辑；新数组全合法才穿插，旧分支 DOM 不变。
- [x] 补图片之后段落的既有 12px 间隔，其他令牌不变。
- [x] 运行 `npm test -- test/frontend/components/ItemRow.test.tsx` 与 `npm run check`，确认通过。

### Task 3: 真实页面与交付

**Files:** 更新 PRD 7.3/7.5 的源字段说明，并记录 D9 与 D36 已有冲突的适用边界；QA 输出放本线程 VIZ。

- [ ] 从新适配器的393本地样本在隔离数据库生成控制器 GET，保留旧/新条目字段比较；完成回滚和临时数据库清理。
- [ ] 手机375/桌面1440 原生浏览器检查目标条目；只允许既有确定原图 URL，保存前后截图及真正的图文几何。无 PDF。
- [ ] 完整 `bin/ci` 与首屏预算通过后独立审查整个 diff、兼容回退和画面。
- [ ] 提交草稿 PR、附加本线程、核对最终 head 的远端 CI。保持未合并/未部署，目标仍为 active。
