# Independent Translations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 理由失败或合法拒写后，仍可安全、有限、可记账地补齐日刊缺译文。

**Architecture:** 保留 Reasons 成功附带译文，新增 Translations 富模型与浅 Job。两类请求共用跨进程预算门与账本，译文只消费冻结目标，保留原文有独立终态。手动操作通过签名预览冻结范围。

**Tech Stack:** Rails 8、PostgreSQL 18、Solid Queue、Inertia/React/TypeScript，沿用当前依赖。

**Spec:** `docs/superpowers/specs/2026-10-25-independent-translations-design.md`；2026-10-25 用户已批准完整设计、本地实现与离线验收，不包含真实模型调用、合并或部署。

## Global Constraints

- 原文和 Issue 发布时间/修订时间不变；失败响应译文不保存，D38 严格拒写保持。
- 仅已发布可见日刊；HN/RSS 标题≤300字符、Trending简介≤500字符。
- 每目的/操作/条目/字段最多3次；429/401/403停止操作，逐次查同一月上限。
- 翻译响应≤64KiB；全请求20秒；标题320/简介600 token；无新依赖或常驻进程。
- 手动凭据15分钟、固定操作期限7天，不随重放续期；账本保留90天。
- 自动仅入队时上海当日新发布/重抓的实际新 id；历史显式补全。
- 不覆写已有译文；不追加读者装饰、占位、诊断或动效；首屏≤300KB。
- 本会话直接执行；最后做独立整支审查。已获完整设计实施授权，不重复请求同范围许可。

## Review Focus

- 来源配置在模型请求途中改变：前后 fingerprint 核对，不写旧输出（Task 3）。
- 重复 POST 与任务重放：同签名目标和操作键共用3次额度（Task 4）。
- 纯名称合法保留后后台零待补：仍能进入重新评估，失败保留旧判断（Task 5）。
- 收藏后同链接重抓改标题/简介：分别匹配原文才使用后补译文（Task 5）。
- 月中管理员改单价或端点：本次使用冻结配置及价格，不混账（Task 2）。

---

### Task 1: 翻译契约与持久状态

**Files:** Create `app/models/translations.rb`, `app/models/translations/parser.rb`, `app/models/translations/prompt.rb`, `app/models/translation_preservation.rb`, `app/models/item/translating.rb`, migration；Modify `app/models/item.rb`, `app/models/model_call.rb`；Test `test/models/translations/parser_test.rb`, `test/models/item/translating_test.rb`, `test/models/translation_preservation_test.rb`。

**Interfaces:** `Translations::Parser.parse(text, field:) -> Result(decision,text)`；`Translations::Prompt.messages(item, field:)` / `.max_tokens(field)`；`Item#translation_field`, `#translation_digest(field)`, `#needs_translation?(reassess: false)`, `#translation_target`, `#store_translation(result, target:, assessed_at:)`；`Translations.targets(issue, item_ids: nil, reassess: false) -> Array<Hash>`。

- [x] 写 parser RED：translated接受边界300/500；301/501、无汉字、额外键/非对象/代码围栏拒绝；unchanged仅一键。
- [x] `PARALLEL_WORKERS=1 bin/rails test test/models/translations/parser_test.rb`，确认因缺模块失败。
- [x] 实现严格独立协议、最小字段 Prompt；新表/FK/唯一/CHECK，账本 purpose/operation_key/input_field/input_digest 与索引。
- [x] 写资格/摘要空值/隐藏周刊/中文原文/保留指纹过期/unchanged不touch/失败不覆写/写入后指纹检查测试，运行迁移及上述定向测试至绿。
- [x] 提交契约与状态任务。

### Task 2: 共用请求门、预算与理由兼容

**Files:** Create `app/models/model_requests.rb`；Modify `app/models/reasons/provider.rb`, `budget.rb`, `generator.rb`, `app/controllers/admin/items/reasons_controller.rb`, `app/models/reasons/status.rb`；Test `test/models/model_requests_test.rb`, 现有 provider/generator/budget/controller 测试。

**Interfaces:** `ModelRequests.operation(key: SecureRandom.uuid, issued_at: Time.current) -> Hash`；`.valid_operation?(operation)`；`.synchronize { ... }`（跨进程 session advisory，忙时 `Busy`）；`.calls(item,purpose:,operation:,field:nil)`；`.record(... configuration:)`。Provider `.configuration` 冻结端点/模型/key/两种价格，`.chat(messages, ..., configuration: nil)`；Budget `.cost_for(..., input_price: nil, output_price: nil)`。Reasons `.generate!`/`.generate_item!` 增加可选 operation；Outcome 增加停止原因。

- [x] 写 RED：冻结价格/端点、整个请求20秒、两个连接取门冲突、异常释放门；同操作3次和合法终态不再收费。
- [x] 运行新定向测试确认真实失败，再实现门、时效、固定配置/费用和已知usage记账。
- [x] 理由逐次进入门，保持解析与写入异常隔离；Provider拒绝/限流/预算返回外层可识别停止原因；理由错误查询限定purpose。
- [x] 跑完整现有 Reasons/ModelCall/controller定向回归，修复兼容性，不重写既有生成语义。
- [x] 提交请求门任务。

### Task 3: 独立生成与复用

**Files:** Create `app/models/translations/generator.rb`, `test/models/translations/generator_test.rb`；Modify translating concern。

**Interfaces:** `Translations::Generator.generate!(issue, targets:, operation:, reassess: false) -> Outcome(translated,reused,preserved,failed,skipped,stop_reason)`；每次从冻结 target 找行，复用/请求/短事务存储都遵守门及指纹。

- [x] 写 RED：理由为空/拒写仍可译、画像为空、已有译文不请求、单键unchanged、3次invalid/超时、429停止、预算只允许一次、失败译文隔离。
- [x] 运行失败测试，实施同原文跨日复用、独立请求与真实账本；不跨源/字段/原文复用。
- [x] 加入请求中改原文/隐藏/删行/重抓换id/改source配置，以及业务保存失败不重调、作业同键重放测试。
- [x] 定向测试至绿；核对Item原字段/Issue时间/ReasonAbstention的前后快照。
- [x] 提交生成任务。

### Task 4: 冻结范围、后台资源与自动装订

**Files:** Create `app/models/translations/preview.rb`, `app/jobs/generate_translations_job.rb`, `app/controllers/admin/issues/translations_controller.rb` 及对应模型/job/controller测试；Modify `config/routes.rb`, `app/jobs/generate_reasons_job.rb`, `app/models/issue/sections.rb`, `source/fetching.rb`, `issue/finalization.rb`, `issue/daily.rb`。

**Interfaces:** `Translations::Preview.issue(issue,user:,reassess:) -> signed token + counts`；`.verify(token,issue:,user:) -> frozen operation/targets/options`。Translation Job消费签名验证后的payload；Reason Job向后兼容旧两参数，无targets不触发独立翻译，新参数包含冻结targets与operation签发时间。

- [x] 写 RED：GET预览无调用/写入；POST伪造/跨用户/跨期/过期/周刊403或422；重复POST同key、后插行不混入。
- [x] 实施签名快照与浅Job；Busy只重排原操作、7天到期终止，普通失败不自动重跑三次。
- [x] 装订内部返回写入ids与dropped_count；只在当日新发布/当日重抓传实际新ids，历史/旧消息/理由重生不新增独立调用。
- [x] 加跨午夜、过去日期补生成/重抓、429不落入翻译、无画像仍译测试；保持周刊装订回归。
- [x] 定向controller/job/finalization/fetching/sections测试至绿，提交。

### Task 5: 后台与阅读消费

**Files:** Modify `app/models/issue/administering.rb`, `app/frontend/types/lowpass.ts`, `app/frontend/lib/paths.ts`, `app/frontend/pages/Admin/Issues/Index.tsx`, `app/frontend/pages/Admin/Settings/Show.tsx`, `app/controllers/favorites_controller.rb`；新增对应frontend/controller/system测试。

**Interfaces:** 每期 `translations: {pending,preserved,ready,unready_label}`；模型状态增加两目的调用分项，总量不变；只读预览返回 `{token,target_count,...}`，确认POST使用token，不信任客户端item列表。

- [x] 写 RED：无reason仍显示译文、只有preserved仍能重新评估、预览加载/目标零不可确认、画像为空不禁用翻译、pending筛选包含译文。
- [x] 复用现有Dialog/Table/operations文案与令牌，冻结预览避免晚响应替换新选项；不加表列或读者新装置。
- [x] 收藏title/summary分别比对原文再取live译文，快照不回写；增加同url改标题/简介交叉匹配回归。
- [x] 跑前端定向、admin/favorites控制器与真实本地系统测试；验证键盘焦点、取消/确认、403/失败反馈。
- [x] 提交消费方任务。

### Task 6: 规格同步、完整验收与审查

**Files:** Modify `AGENTS.md`, MVP PRD、D38设计交叉引用，实施状态与本计划；新增只含离线证据的执行记录。

- [x] PRD记录D39已批准契约和未发布状态，更新对应R/AC/7.2/附录文案；不把新决定追写成旧授权。
- [x] 按IT-01…20建立命令/测试/数据库/渲染证据映射，实际覆盖后才勾完成；真实内容质量与手机/Windows不冒充通过。
- [x] 运行 `bin/ci`（独立PG18测试库、无外部模型、无worker）和≤300KB门禁；新增错误才补跑相关检查。
- [ ] 派独立代理只读攻击完整diff和覆盖证据，处理真实问题并重新验证受影响范围。
- [ ] 审查最终diff、提交并报告本地工作区/测试/限制。未经本轮额外授权，不推送合并、部署或实网试词。

## Self-review

设计§1–3/5–6→Task1/3，§7→Task2/3，§4→Task4，§8→Task5，§9–10→Task6及各任务定向测试。所有20项IT均有所属任务；接口名称统一，审查重点已归入Task2–5。完整八项获奖目标保持原范围，不以该功能完成代替全站最终验收。
