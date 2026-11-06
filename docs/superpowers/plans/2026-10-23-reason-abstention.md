# 推荐理由资料不足处理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在本地实现可记账、可持久保存的合法拒写结果，保护历史内容，并完成离线验收与未合并的可审阅 PR。

**Architecture:** Prompt 与 Parser 同时采用 generated / insufficient_evidence 协议。独立 ReasonAbstention 保存最后一次合法拒写，Item 的理由处理 concern 集中待处理范围与原子写入；Generator、后台和告警共用该定义，沿用现有 Rails/Inertia 页面、任务与账本。

**Tech Stack:** 项目现有 Ruby / Rails 8.1、PostgreSQL 18、Minitest / fixtures / WebMock、React / TypeScript / Inertia、Vitest / Testing Library、Selenium Chrome；不新增依赖。

**Spec:** `docs/superpowers/specs/2026-10-23-reason-abstention-design.md`（2026-10-23 完整方案已确认）；同时阅读 `AGENTS.md`、`STYLE.md`、现行 PRD §5.7、§5.9 与 D25 / D37。

## Global Constraints

- “第一阶段仅实现本地候选并完成离线验证，不执行真实模型试验、不合并部署。”交付终点是完整候选与未合并 PR；本计划中的命令都是执行阶段的步骤，本计划编写阶段不执行它们。
- 工作区 `/Users/drewlee/.codex/worktrees/reason-abstention-contract/lowpass`，分支 `codex/reason-abstention-contract`；设计依据 main `d233d57990829f4420fd9a26adbef18b88602390`。不得将本分支的严格 Parser 单独发布给旧 Prompt。
- “模型、供应商、价格、月上限和现有 max_tokens 预算不在本轮改变范围。”不修改 endpoint、密钥、配置或历史刊期，不调用本地 Qwen；既有 12 次实网额度已用完。
- 只使用标题、说明、来源、有限元数据、画像；不增加 URL 输入、补抓全文、检索或核验模型调用。资料不足与低相关度分开；不按摘要存在与否、长度、名称或关键词机械拒写。
- generated 沿用归一化后 20–60 个 Unicode 字符且不截断；须含汉字、正文点名标签对应的启用领域。D25 的类型、长度与失败隔离保持；拒写不得单独保存译文。
- “首次收到合法拒写：一次真实请求、一次 abstained 账本，立即结束本条，不再重试。”失败仍首次加最多 2 次重试，每次真实请求前检查预算；401 / 403 / 429 不追加重试。
- marker 使用 25 字符 UUIDv7 base36 主键、唯一 item_id、UTC assessed_at、FK CASCADE；不 touch Item / Issue，不依赖 90 天账本，不回填历史。
- 自动测试不连源站或模型；数据库测试、迁移及完整 CI 由主执行者串行协调，避免与其他工作区共用测试库的运行重叠。测试与浏览器准备数据仅进入本地专用环境。
- UI 复用 `.claude/skills/lowpass-design-taste/SKILL.md` 和既有令牌；不改版、不增颜色、装饰、逐条诊断或读者重生成入口；首屏上限 300 KB。
- 网页验收使用实际浏览器，不生成 PDF。私密语义材料、原始模型响应、密钥和本地截屏不进入公开 PR。

## Review Focus

- 外层夹杂文字 / Markdown 的 JSON 与严格判别对象组合：两分支须经过相同分支校验，矛盾或多字段拒写仍 invalid（Task 2）。
- 两次管理员请求交错完成、关联对象已缓存：最后提交的合法结果生效，不能残留旧 marker 或重复 marker；失败不覆盖判断（Task 3）。
- 最后一条合法拒写恰好用尽预算：结束本条，不凭空制造一次预算终止；已有预算事件在预算解除前不能恢复（Tasks 4–5）。
- 有旧理由的 marker、隐藏再恢复、重抓换 id：历史显示与再次收费 / 复用的边界保持一致（Tasks 1、5–7）。
- 未配置供应商 / 空画像仍有历史处理记录，且四种状态同时出现：保留真实计数与禁用原因，375 / 390px 展开及键盘操作可用（Tasks 6–7）。

## 共享接口与文件边界

| 单元 | 固定接口 / 职责 |
|---|---|
| `Reasons::Parser.parse(text, allowed_names)` | 返回 `Result = Data.define(:decision, :reason, :interest_tag, :title_zh, :summary_zh)`。decision 是 wire 字符串 `"generated"` 或 `"insufficient_evidence"`；后者其余四字段全 nil。invalid 始终抛 `Parser::Invalid`。不把模型拒绝或解析异常包装成合法拒写。 |
| `ReasonAbstention` | `belongs_to :item`；只有 item_id、assessed_at 与自身时间。`Item` 包含新 `Item::Reasoning` concern，并 `has_one :reason_abstention`，无 touch。删除保障在数据库。 |
| `Item.daily` / `Item.without_reason_abstention` | 分别关联日刊 Issue、排除 marker；返回可组合的 ActiveRecord relation。 |
| `Item.pending_reasons` | `visible` + `daily` + `reason: nil` + `without_reason_abstention`；后台 missing、补缺、完成判断、预算摘要、Scheduler 都从这里取。 |
| `Item.reusable_reasons` | 日刊、reason 非 nil、无 marker；不额外改变既有跨日日期与 D25 同原文 / 译文前提。 |
| `item.record_reason_abstention(assessed_at:)` | 返回保存后的 ReasonAbstention；锁 Item，再创建或覆盖 marker，不改 Item / Issue。 |
| `item.store_generated_reason(result, generated_at:)` | result 为 Parser::Result 或可复用的 Item，提供四个内容 getter；返回 nil。在同一个 Item 锁事务中写理由 / 合规且需要的译文 / 时间并删除 marker；没有新译文保留旧值。 |
| `Generator.generate_item!(item, names: ..., profile: ...)` | 返回符号 `:generated`、`:abstained` 或 `:failed`，调用方必须 case 匹配。未准备好 / 请求前预算阻止为 :failed 且零账本；保留 Rejected / Limited 抛出，供整期停止与控制器报告。 |
| `Generator.generate!(issue, only_missing: true)` | `Outcome = Data.define(:generated, :reused, :abstained, :failed, :skipped)`；前四项整数，skipped 只保留供应商 / 画像未准备好的布尔语义。拒写不计 generated / failed / skipped。 |
| `Reasons.recover_if_complete(issue)` | 返回 nil；仅在该期 `pending_reasons.none?` 且预算未耗尽时，调用 `Alerts.recover!(kind: "reasons_missing", issue: issue)`。 |
| `Alerts.recover!(kind:, source: nil, issue: nil)` | 新增可选 issue 过滤；既有 source / 搜索 / 备份等调用与恢复语义保持。issue 非 nil 时只选该 issue 的既有未恢复事件，不新建事件。 |
| `Item.reason_counts_by_issue(issue_ids)` | 返回以 issue.id 为键的 Hash；每值含 `with_reason`、`abstained`、`retained`、`missing` 四个整数及 `last_assessed_at: Time / nil`。在 concern 内做批量聚合，不逐行装载 Item；缺席 issue 的默认值全 0 / nil。 |
| `AdminIssueReasons` props | `{ with_reason: number; abstained: number; retained: number; missing: number; ready: boolean; unready_label: string | null; last_assessed_label: string | null }`；替换原 label 混合状态。`AdminIssueRow.reasons` 的 null / 周刊省略规则保持。 |

四类以数据库 nil / 非 nil 与 marker 有 / 无分区；合法生成不会产生空字符串理由。`last_assessed_at` 是可见条目 marker 的最大 assessed_at，服务端转上海时间为 `最后处理 YYYY-MM-DD HH:mm`；不借用 reason_generated_at。`Item::Reasoning` 只承载这组理由状态，不重构其他 Item 功能。

当前 `2026-10-23-reason-domain-contract.md` 与 Parser 测试明确允许正文领域与标签不同。完整新设计 §3 已批准收紧为对应同一领域：这处预期须被明确取代，不能把旧测试保留为“兼容”。

---

### Task 1：独立 marker、账本状态与统一待处理范围

**Files:** Create `db/migrate/20261023100000_create_reason_abstentions.rb`、`db/migrate/20261023100100_add_abstained_to_model_calls.rb`、`app/models/reason_abstention.rb`、`app/models/item/reasoning.rb`、`test/models/reason_abstention_test.rb`；Modify `app/models/item.rb`、`app/models/model_call.rb`、`db/schema.rb`；Test `test/models/item_test.rb`、`test/models/model_call_test.rb`、`test/models/issue/sections_test.rb`。

**Interfaces:** Produces ReasonAbstention association and four relation scopes above; `ModelCall::STATUSES` adds `abstained` without changing column length, token / cost fields or retention.

- [x] **Step 1: 写失败测试。** `test "marker 唯一且与条目同寿命"` 新建 marker 主键满足 `assert_match(/\A[0-9a-z]{25}\z/, marker.id)`；item_id / assessed_at 非空、item_id 唯一且有真实 FK。`test "abstained 是合法账本状态且未知状态受 CHECK 拒绝"` 绕过模型校验检验数据库。`test "pending 只包括可见日刊无理由无 marker 条目"` 构造四类、隐藏与周刊条目：`assert_equal [pending.id], Item.pending_reasons.pluck(:id)`；隐藏再恢复的 marker 保留。
- [x] **Step 2: 观察失败。** Run `bin/rails test test/models/reason_abstention_test.rb test/models/item_test.rb test/models/model_call_test.rb test/models/issue/sections_test.rb`；预期新常量 / scope 尚不存在，不能把环境错误当红测证据。
- [x] **Step 3: 实现模型、scopes 与迁移。** Rails migration 8.1，新表 id / item_id string limit 25、assessed_at / timestamps 非空、唯一 index、`on_delete: :cascade`；沿用项目长度 CHECK 风格。替换 `model_calls_status` CHECK，保留全部四个旧状态并加 abstained。执行本地迁移生成 schema，不手改历史迁移，不建立数据回填或定时清理 marker。
- [x] **Step 4: 验证寿命与级联。** 为 91 天旧 ModelCall 建 marker，cleanup 后 `assert ReasonAbstention.exists?(item_id: item.id)`；`replace_section!` 的 delete_all 和 Issue 的 dependent delete_all 均删除旧 marker，新 item 不承接；普通 Item.destroy 亦通过。重复 Step 2 命令，预期全绿。
- [x] **Step 5: 审查并提交。** 只提交本任务模型 / 迁移 / schema / 测试，commit `feat: persist reason abstention markers`；不包含本地测试数据。

### Task 2：严格两分支 Parser 与同批候选 Prompt

**Files:** Modify `app/models/reasons/parser.rb`、`app/models/reasons/prompt.rb`、`test/test_helpers/reasons_test_helpers.rb`、`test/models/reasons/parser_test.rb`、`test/models/reasons/prompt_test.rb`；Update protocol-dependent successful samples in `test/models/reasons/generator_test.rb`、`test/controllers/admin/items/reasons_controller_test.rb`、`test/system/admin_test.rb`。

**Interfaces:** Produces five-field Parser::Result above; keeps `Prompt.messages(item, profile_text)` / `max_tokens(item)` signatures. Test helper `model_reply(reason:, interest_tag:, title_zh: nil, summary_zh: nil, prompt_tokens: 100, completion_tokens: 40)` emits decision generated. Add `abstained_reply(prompt_tokens: 100, completion_tokens: 40)` emitting only decision inside completion content.

- [x] **Step 1: 写分支与边界失败测试。** `test "两分支有显式 decision 且拒写内容全空"` 断言合法拒写 `result.decision == "insufficient_evidence"` 且四内容全 nil；`test "拒写多任意字段均 invalid"` 对 reason / interest_tag / title_zh / summary_zh / diagnostic 分别以 nil、空字符串和值构造混合对象，均 `assert_raises(Parser::Invalid)`。`test "缺失未知 decision 与非对象均 invalid"` 覆盖缺 decision、未知值、空对象 / 响应、数组、标量与坏 JSON；`test "外层提取不放宽分支校验"` 检查整段、夹字和 fenced JSON 的同一对象必须同判。
- [x] **Step 2: 观察失败。** Run `bin/rails test test/models/reasons/parser_test.rb test/models/reasons/prompt_test.rb`；预期旧协议接受缺 decision / 混合对象或缺结果字段而失败。
- [x] **Step 3: 实现严格校验。** 保留现有外层 JSON 提取方式；先检查 decision。generated 的 reason / interest_tag 必须为 String，tag 与启用名精确匹配，正文归一化后含该 tag 的归一化完整名称且有汉字；19 / 61 拒绝、20 / 60 原样完整保留。译文保持 300 / 500、含汉字、类型校验；只消费既有内容字段，禁止额外内容被持久化。insufficient_evidence 只接受 `json.keys == ["decision"]`，不从错误推断此分支。
- [x] **Step 4: 实现候选 Prompt 与回归样本。** 系统规则先判断证据，再判断相关性；写明不透明名 / 热度不构成功能证据、充分标题可无说明、弱相关仍据实写、主体 / 否定 / 模态 / 位置 / 引用区别及不能凑字数。显示两种明确 JSON，仅 generated 要本条所需译文。用户消息字段与不可信资料分隔保持，不加入 URL。保留 MAX_TOKENS=200、TITLE_TOKENS=120、SUMMARY_TOKENS=400。旧成功样本补 decision 并让正文与标签一致，保留单独错配反例，不能由 helper 自动修正错配。
- [x] **Step 5: 验证并提交。** 重复 Step 2，并 Run `bin/rails test test/models/reasons/generator_test.rb test/controllers/admin/items/reasons_controller_test.rb`；所有旧长度、空白 / 别名、译文隔离测试保持含义，纯英文合法长度理由拒绝。Prompt 测试证明无额外输入与 token 改动，不声称能判事实正确。commit `feat: define evidence-aware reason output contract`。

### Task 3：合法结果原子保存且不触碰历史

**Files:** Modify `app/models/item/reasoning.rb`；Create `test/models/item/reasoning_test.rb`、`test/models/reason_abstention_concurrency_test.rb`。

**Interfaces:** Consumes Parser::Result / Item getters; produces `record_reason_abstention(assessed_at:)` and `store_generated_reason(result, generated_at:)` exactly as shared interface table. This task performs no Provider calls.

- [x] **Step 1: 写字段保护失败测试。** `test "拒写保护新旧条目全部内容与时间"` 对新条目、已有理由条目保存全部 `item.attributes` 与 `issue.attributes` 快照；合法拒写后 `assert_equal before, item.reload.attributes`、Issue 同样不变。`test "重复拒写只刷新唯一 marker"` 断言连续合法拒写只有一个 marker 且 assessed_at 更新；已有两个译文与 reason_generated_at 完全保留。
- [x] **Step 2: 观察失败。** Run `bin/rails test test/models/item/reasoning_test.rb`；预期新富模型方法不存在。
- [x] **Step 3: 实现受锁写入。** 两方法均在 Item.with_lock 的新鲜数据库状态上操作；拒写只保存 marker。generated 同事务 update! 内容 / generated_at 与删除 marker，不从缓存 association 判断 marker 是否存在；只保存该 item 需要且本次合规非 nil 的译文。返回值遵守接口，不包住网络或调用账本。
- [x] **Step 4: 写并运行原子性 / 交错回归。** 删除 marker 时注入数据库失败，断言旧内容和 marker 一并保留；重复独立 Item 实例、预先加载的空 / 非空 association 后交错 generated / abstained，断言最终合法提交一致。并发测试单独类关闭 transactional tests，自己建已提交的测试条目、独立连接与线程屏障，不用 sleep；两 writer 后 marker count ≤1，generated 终态无 marker、abstained 终态仅更新判断，ensure 清理自建数据。Run `bin/rails test test/models/item/reasoning_test.rb test/models/reason_abstention_concurrency_test.rb`，预期全部通过且不留下数据。
- [x] **Step 5: 审查并提交。** commit `feat: store reason decisions atomically`；验证无 touch、无历史批量更新、无独立译文成功路径。

### Task 4：单条三态、调用方适配与真实请求账本

**Files:** Modify `app/models/reasons/generator.rb`、`app/controllers/admin/items/reasons_controller.rb`；Test `test/models/reasons/generator_test.rb`、`test/models/reasons/budget_test.rb`、`test/models/reasons/status_test.rb`、`test/controllers/admin/items/reasons_controller_test.rb`、`test/controllers/admin/issues/reasons_controller_test.rb`。

**Interfaces:** Consumes Tasks 1–3; changes `generate_item!` to `:generated / :abstained / :failed`, produces five-field Outcome, adapts every current consumer in the same task, and uses the two Item persistence methods. Provider Rejected / Limited exceptions remain visible to callers. Actual HTTP / parsing / ledger precede business persistence. Audit.record(action, target, payload = {}) and existing action names remain.

- [x] **Step 1: 写三态失败测试。** `test "合法拒写一次调用记账并终止"` 用 provider stub 真正走 Generator：合法拒写一次请求、一次 `abstained`，真实 100 / 40 tokens、配置单价 1 / 10 得费用 `BigDecimal("0.0005")`，duration_ms 非负，error_summary nil；返回 `assert_equal :abstained, result`。`test "invalid 后拒写不串用译文"` 断言两次请求、`["invalid", "abstained"]` 与两笔真实 usage，Item 全字段及既有 marker 不被失败响应污染。控制器四结果分别断言固定 notice / alert / 审计，不能因 Ruby symbol truthiness 把拒写视为生成成功。
- [x] **Step 2: 观察失败。** Run `bin/rails test test/models/reasons/generator_test.rb test/models/reasons/budget_test.rb test/models/reasons/status_test.rb test/controllers/admin/items/reasons_controller_test.rb test/controllers/admin/issues/reasons_controller_test.rb`；预期旧布尔返回 / 拒写重试路径失败。
- [x] **Step 3: 实现分支与记账顺序。** 合法 generated 记 ok 后原子写入；合法 insufficient_evidence 记 abstained 后独立保存 marker，立即返回。将持久化与账本异常向任务失败路径抛出，不 rescue 成 Parser::Invalid / Provider 错误，不重试模型；不可把账本包进 Item 事务。generate! 同时 case 三态计数并返回新 Outcome，ready false 四计数为0 / skipped true；更新现有布尔 / outcome 断言，避免中间提交仍用 symbol 当布尔。
- [x] **Step 4: 保持并补齐失败门禁。** 断言 invalid→拒写、超时→拒写均终止且不串译文；已有 marker 的三次 invalid / 超时失败保留 marker；无配置 / 空画像 / 已耗预算无请求无账本；每次请求前预算、上限 0、401 / 403 / 429 停止、普通失败最多三次均保持。合法最后一条恰好耗尽预算不新建终止事件；失败恰好耗尽继续按 D37 立即告警。注入 Item 保存失败，断言一笔已收费 ledger 仍在、模型只请求一次、异常向外抛出。
- [x] **Step 5: 适配管理员同步结果与审计。** 单条入口查 visible daily Item；generated notice `已重生成`；abstained 按当前条目有无旧理由分别 notice `资料不足，未生成理由` / `本次资料不足，保留旧理由`；failed / Rejected / Limited 保持失败事实与 alert。每次已执行的重生成在现有 action 下记录实际 `outcome: "generated" / "abstained" / "failed"`；拒写附 `retained_reason: true / false`，失败可用固定错误分类，不放原始回复。未准备 / 请求前预算 / 非管理员 / 404 仍不记成功操作。整期仅保留入队审计与“已开始”提示，不伪造完成数。
- [x] **Step 6: 验证费用与提交。** 重复 Step 2；增加 abstained 跨上海日 / 月边界与 Status 月 / 今日计数，证明无需 status 过滤且包含费用；单条隐藏 / 周刊404、member403均通过。commit `feat: account for terminal reason abstentions`。

### Task 5：补缺、跨日复用、完成与按期恢复告警

**Files:** Modify `app/models/reasons/generator.rb`、`app/models/reasons.rb`、`app/models/alerts.rb`、`app/models/scheduler.rb`；Test `test/models/reasons/generator_test.rb`、`test/models/alerts_test.rb`、`test/models/scheduler_test.rb`、`test/jobs/generate_reasons_job_test.rb`。

**Interfaces:** Consumes Task 4 Outcome; produces `Reasons.recover_if_complete(issue)` and adds optional issue keyword to Alerts.recover!. All only_missing / pending counts consume `Item.pending_reasons`; explicit processing uses visible daily items and does not skip markers. Job `perform(issue, only_missing = true)` and concurrency key stay unchanged.

- [x] **Step 1: 写批量与恢复失败测试。** `test "整期四结果独立计数且拒写不是 skipped"` 一期各一个 generated / reused / abstained / failed：`assert_equal [1, 1, 1, 1, false], [outcome.generated, outcome.reused, outcome.abstained, outcome.failed, outcome.skipped]`。`test "重复补缺跳过拒写而显式重生重新评估"` 断言 only_missing 零新请求与显式 false / 单条重评估。`test "完成只恢复本期且预算未解除不恢复"` 为两期建 open reasons_missing，本期完成只恢复本期；预算尚耗尽两期都不误恢复。
- [x] **Step 2: 观察失败。** Run `bin/rails test test/models/reasons/generator_test.rb test/models/alerts_test.rb test/models/scheduler_test.rb test/jobs/generate_reasons_job_test.rb`；预期 marker 被重复补缺、全局恢复与 reason:nil 统计失败。
- [x] **Step 3: 接入统一选择与计数。** only_missing 用 issue.items.pending_reasons.ranked；显式用 visible daily items；保留 Task 4 三态计数。跨天候选改为 Item.reusable_reasons，并保留 url_hash、较早 period_key、原文与合规译文要求；复用仍无模型账本、沿用原时间语义。禁止复制 marker，次日没有可复用成功理由时正常调用。
- [x] **Step 4: 接入告警共用完成判断。** Generator 的单条合法结果、复用 / 整期结束都调用 Reasons.recover_if_complete；Alerts 在 issue 参数存在时才增该期过滤，其他调用不变。预算摘要从 pending_reasons.count 取数。Scheduler 仍只处理当天发布满 30 分钟且 ready 的期：有 pending 告警；零 pending 调共用恢复检查；不请求模型、不新增 tick 步骤。合法最后结果预算耗尽不新建事件，已有预算事件保留；真正被预算拦住的后续工作按旧规则告警。
- [x] **Step 5: 验证并提交。** 补证带 marker 的旧理由不能传播，但更早无 marker 合规理由仍可依原查询复用；次日不复制拒写、同源重抓换 id 重评估、设置变更不清 marker；minute check / 预算摘要排除合法拒写。保留源抓取与搜索恢复回归。重复 Step 2，commit `feat: reconcile reason completion per issue`。

### Task 6：后台真实四类统计与最后判断时间

**Files:** Modify `app/models/item/reasoning.rb`、`app/models/issue/administering.rb`；Test `test/models/issue/administering_test.rb`、`test/controllers/admin/issues_controller_test.rb`。

**Interfaces:** Produces `Item.reason_counts_by_issue(issue_ids)` and AdminIssueReasons props above. Task 7 immediately consumes this new props shape before candidate integration validation; no partial interface deployment.

- [x] **Step 1: 写统计与返回失败测试。** `test "四类理由计数互斥且只计可见日刊"` 每类各1且附隐藏 / 周刊样本：四整数为 `[1,1,1,1]`、总和等于可见日刊条目数；`test "最后判断时间只取可见 marker 且配置事实不覆盖计数"` 检查最大时间与上海格式。未配置 / 空画像时计数不变，ready false 与准确 unready_label 独立存在。
- [x] **Step 2: 观察失败。** Run `bin/rails test test/models/issue/administering_test.rb test/controllers/admin/issues_controller_test.rb`；预期旧 props 与计数失败。
- [x] **Step 3: 实现批量聚合和 props。** 在 Item concern 批量按 issue 与 reason / marker 分区计数，missing 使用同一 pending 定义；聚合 assessed_at，不逐期查询 Item。Issue::Administering 格式化上海最后处理时间并传 ready / unready_label，未发布与周刊规则保持。用查询计数回归证明一月多期不产生逐行查询增长。
- [x] **Step 4: 验证并提交。** 重复 Step 2；一个月31行 / 多类条目聚合不出现逐行 Item 查询，未发布 / 缺期 / 周刊 props行为保持；commit `feat: expose accurate admin reason counts`。

### Task 7：既有后台内呈现计数，读者静默与浏览器回归

**Files:** Modify `app/frontend/types/lowpass.ts`、`app/frontend/pages/Admin/Issues/Index.tsx`、`test/frontend/support/props.ts`、`test/frontend/pages/AdminIssuesIndex.test.tsx`、`test/frontend/pages/AdminManagement.test.tsx`、`test/frontend/pages/AdminManagementMobile.test.tsx`、`test/frontend/components/ItemRow.test.tsx`；Create `test/system/reason_abstention_test.rb`；Test `test/models/issue/presenting_test.rb`、`test/system/admin_test.rb`。仅必要时 Modify `app/frontend/styles/tokens.css` 与 script/subset_fonts 的生成字体 / CSS。

**Interfaces:** Consumes Task 6 AdminIssueReasons. Reader Item props 不新增 marker / diagnostic / 核验状态；原文、收藏和历史理由仍走原 ItemRow。

- [x] **Step 1: 写四类、禁用与静默失败测试。** `it('shows four real reason counts and separate readiness')` 断言 `已有理由 N 条`、`资料不足未写 M 条`、`保留旧理由 L 条（本次资料不足）`、`缺 K 条`；零可省略。仅 K>0 使用既有缺失 Chip，其余现有灰字。`it('excludes legal abstentions from pending issues')` 检查只含合法拒写的行不命中待处理，K>0 / 缺期 / 原有源故障仍命中；ready false 的行同时看到真实计数与独立禁用原因。
- [x] **Step 2: 观察失败。** Run `npm test -- test/frontend/pages/AdminIssuesIndex.test.tsx test/frontend/pages/AdminManagement.test.tsx test/frontend/pages/AdminManagementMobile.test.tsx test/frontend/components/ItemRow.test.tsx`；预期旧 label 与 props 失败。
- [x] **Step 3: 实现现有格内状态。** 更新类型与测试 props，理由格按固定顺序显示非零类别，最后处理时间同格使用既有 Mixed / 时间字体；该格自然进入手机既有“刊物详情”，桌面无需新面板。禁用 title 取 unready_label；保留同一操作 DOM、键盘焦点与响应式装置。无新颜色、字号、动效或标签。
- [x] **Step 4: 建立真实浏览器回归。** 使用现有 ApplicationSystemTestCase / 登录助手、WebMock 和直接建立的测试记录。CDP Emulation 实测 viewport=375、390、1440（不用受 Chrome 最小窗口限制的 resize_to）；等 document.fonts.ready。展开“刊物详情”、Tab / Enter 到现有操作，验证四类与时间完整可读、document.documentElement.scrollWidth <= innerWidth；减少动效开启时结果仍可达。读者新拒写无 reason / interest tag / 译文行或诊断，但原文链接与收藏可用；保留旧理由的拒写仍显示历史内容，无核验标识。不要为本轮新增读者重生成控件。
- [x] **Step 5: 验证并提交。** Run Step 2、`npm run check`、`bin/rails test test/models/issue/presenting_test.rb`、`bin/rails test:system TEST=test/system/reason_abstention_test.rb`。Run `script/subset_fonts --check`；仅缺字时生成既有字体 / CSS，再检查并确认差异仅由新增文案产生。commit `feat: present reason abstention states in existing admin views`。

### Task 8：契约文档同步与既有私密材料独立审查

**Files:** Modify `docs/superpowers/specs/2026-09-08-mvp-prd.md`、`docs/superpowers/specs/2026-09-14-p2-reasons-design.md`、`docs/engineering-conventions.md`、`docs/development.md`；仅为旧相反结论加“被本决定取代”注记：`docs/superpowers/plans/2026-10-23-reason-domain-contract.md`。Private review output stays outside repository in the existing local materials directory; no new public fixture copied from those materials.

**Interfaces:** Documentation describes Tasks 1–7 as current local candidate, not production enabled. Existing six-input / ten-card framework is reused read-only; independent reviewer produces a separate new review note, never edits prior trial records or expected results.

- [x] **Step 1: 写验收对照并先查旧冲突。** 用 `rg -n '每条都要|每条.*理由|理由可以更短|只看.*reason|reason IS NULL|截到 60|超长截断|正文.*标签|已生成' docs/superpowers/specs/2026-09-08-mvp-prd.md docs/superpowers/specs/2026-09-14-p2-reasons-design.md docs/engineering-conventions.md docs/development.md docs/superpowers/plans/2026-10-23-reason-domain-contract.md`，记录与新契约相反的现行描述；未同步前本任务不通过。
- [x] **Step 2: 同步前瞻契约。** PRD 更新 D16、R-9.1–9.4 / 9.6–9.8 / 9.10、无说明边界、R-1.11 与跨日边界、AC-9.1 / 9.3 / 9.5、§5.7、附录 A 的 ReasonAbstention / ModelCall 与附录 B 四类 / 重生成文案；新增 2026-10-23 决定 D38，保留 D37 原决定历史，不追认旧设计当时已含新细节。新增 AC-9.9–AC-9.18 分别对应 A1–A10。旧设计的强制生成、截断、全局恢复与旧协议标注由现行 PRD / 本设计取代；工程约定与开发说明同步范围、维护 / 清理和回退边界。
- [x] **Step 3: 核对已有材料来源。** 只读目录 `/Users/drewlee/.codex/visualizations/2026/10/22/01a162a8-dbb7-7583-bab0-a4e6384d008a/content-semantic-offline-next/` 内 semantic-cards.json、adversarial-cases.json、manifest.json、root-review.json、proposal.md、prompt-a-draft.txt；先核对已有条数 / 标识 / 哈希与来源，不重建框架或改旧文件。既有相邻 `content-trial-executor/` 只作参考，不运行 run.rb、transport 或模型试验。
- [x] **Step 4: 由未写 Prompt 的独立审查者完成 A9。** 将候选 Prompt 与六条资料的允许 / 禁止范围逐条对照，再检查十组正反卡中的主体、否定、模态、因果、引用、问句预设、名称消歧、热度与画像扰动；同时找误写与无必要拒写。另存私密 `reason-abstention-candidate-review.md`，记录材料标识、候选代码版本、问题与结论，不更改旧 root-review。公开报告只给匿名覆盖与限制；不得把人工预期写成模型已通过、把格式校验写成事实核验。发现 Prompt 问题回 Task 2 修复并重跑相关离线测试。
- [x] **Step 5: 验证并提交文档。** 重复 Step 1，剩余旧语句必须明确属于历史且有取代指向；逐一核对 A1–A10 / AC-9.9–18 映射与真实实现。只提交仓库文档，commit `docs: define prospective reason abstention behavior`。

### Task 9：整体验收、独立攻击 diff 与未合并 PR

**Files:** Review all changed files; local logs / screenshots under ignored `tmp/reason-abstention-qa/` or task-private artifact directory. Update this plan's checkboxes only after corresponding evidence exists.

**Interfaces:** Consumes complete candidate, test evidence and private A9 review; produces branch / commit identity, independent review conclusion, offline acceptance matrix and draft PR URL. No main merge, deployment, paid trial, automatic historical regeneration or production setting changes.

- [x] **Step 1: 运行完整门禁。** 在主执行者释放共享测试库后 Run `bin/ci`，保存完整退出码与各步骤结果；包括 Ruby style、TypeScript、Vitest、build、安全检查、Rails、系统、seeds 与 `script/first_screen_size` ≤300 KB。失败修复后只重跑受影响检查及必要最终 CI；不跳过、改弱测试或把环境失败写成全绿。
- [x] **Step 2: 实际网页人工验收。** 使用本地隔离数据与 stub 结果，登录管理员检查 `/admin/issues` 在375 /390 /1440px 的四状态混合、未配置、空画像、last_assessed 时间、展开 / 收起、待处理过滤与键盘焦点；读者检查新拒写 / 保留历史理由、原文与收藏。保存实际浏览器截图与溢出测量，不生成 PDF，不把 jsdom 当视觉验收。不得对任何真实模型配置点击会收费的操作。
- [x] **Step 3: 独立完整 diff 审查。** 使用 requesting-code-review 与 verification-before-completion 工作流；审查者核对 A1–A10、事务与账本顺序、竞态 / 唯一约束、三态所有调用方、所有直接 reason:nil 缺失统计、issue 恢复范围、私密材料是否误加入、范围外配置变化及 UI 证据。Run `rg -n 'where\(reason: nil\)|reason\.nil\?|generate_item!|recover!\(kind: "reasons_missing"' app test`，逐处给出保留或替换依据；修复真实问题并重新验证。
- [x] **Step 4: 建立可审阅 PR 并保持未合并。** 最终 `git diff --check` 与 status 只含本变更；提交 / 推送本分支，创建 draft PR，描述具体前后行为、A1–A10 本地结果与未执行实网内容验收的限制。只暴露公共仓库文件与非私密概述；使用 attach_artifact 附到当前 chat。PR 明确“本地候选；不合并、不部署”，不触发 main 自动部署。
- [x] **Step 5: 交付并止于本阶段边界。** 报告工作区 / branch / commit、PR URL、完整 CI 与首屏结果、浏览器375 /390 /桌面证据、独立内容审查结论及仍需实网验证的协议遵守 / 内容质量风险。后续若申请发布，另列次数 / 预算 / 模型 / 重试 / 记账 / 停止线取得新授权；发布前补部署与回退执行步骤。启用后回退须停止本轮理由任务、保留 marker 表及 abstained 账本 / CHECK，不回滚删除数据，不将旧代码忽略 marker 视为透明回退。本阶段不执行这些操作。

## 自审覆盖矩阵

| 设计 / 验收 | 负责任务与可检查结果 |
|---|---|
| §1–2；A9 | Tasks 2、8：有边界的候选 Prompt、六条输入及十组卡的独立私密人工审查，明确无新模型证据。 |
| §3；A1 | Task 2：明确 discriminator / exact abstention、类型 / 汉字 / 对应标签、19 /20 /60 /61、外层提取与译文规则。 |
| §4；A3 | Tasks 1、3–4：一对一 / FK / UTC、全字段保护、锁与原子删 marker、失败不抹 marker、账本不随业务失败消失。 |
| §5；A2 | Task 4：terminal / 三次失败 / 每次预算 / 401 /403 /429 / 超时 / 真实费用 / 最后合法结果无额外终止。 |
| §6；A4 / A6 / A7 | Tasks 1、5：统一 pending、显式重评估、90天清账后有效、跨日候选排除 marker、delete_all 级联、按期且预算约束的恢复。 |
| §7；A5 / A8 | Tasks 6–7、9：四类互斥计数、配置事实独立、真实 outcome 审计、读者静默 / 历史保留、实际浏览器窄屏与键盘验收。 |
| §8；A10 | Task 9：独立 diff 审查、相关回归与完整 bin/ci、300KB、真实网页，不生成 PDF。 |
| §9–10 | Tasks 8–9：前瞻 PRD / 旧决定标注、完整候选未合并PR、阶段边界与保数据回退；命名、返回值、锁与批量接口在本计划固定。 |

自审结论：完整设计各节与 A1–A10 均有任务；无待产品负责人再决定的工程问题。执行后才能勾选成功与宣称完成，离线通过不能宣称新 Prompt 的实网内容质量已经达标。


## 本地候选验收结果（2026-10-24）

- Draft PR：[资料不足时允许不写推荐理由 #91](https://github.com/skipmaple/lowpass/pull/91)。保持未合并；无生产部署、历史重生成或新增模型调用。
- 产品/测试提交 `52efb35c93d5e0f37aad56d84f8d523f03386770` 的完整 `bin/ci` 退出0：605项前端，935 Rails /4251 assertions，108系统 /8692 assertions，均零失败；首屏266.21KB /300KB，类型、风格、安全、构建与seeds通过。使用独立本地测试库；本次结果记录随后只修改完成文档。
- 实际Chrome375/390/1440px四类混合、上海处理时间、未配置/空画像、待处理、详情展开/Enter收起、Tab/Enter到查看，以及读者静默/保留旧理由/收藏均通过；对应宽度没有横向溢出。独立逐图像素复核通过。减少动效由系统测试覆盖，未宣称实体手机、Windows或OS窗口激活通过。没有PDF。
- 独立完整diff审查无Critical；已修复两处旧Provider JSON断言，保留原断言并补齐后台三宽度溢出测量。最终门禁另暴露并复现既有邮件测试顺序泄漏，两个发邮件测试类采用Rails标准清理；同一seed23619两文件RED→GREEN和完整935 Rails回归通过，未改生产投递逻辑。
- A9独立人工审查复用六输入/十组卡，22个来源哈希一致；真实模型协议遵守、事实正确率与无必要拒写率尚无新证据。上下文反驳作用域、热度推断、无必要拒写保留为后续内容评估项，不能把离线通过称作模型或获奖品质达标。
- 后续发布仍需单独界定范围与授权。任何启用后回退须停止相关任务，保留ReasonAbstention表、abstained账本及CHECK；本阶段未执行生产迁移/回退。
