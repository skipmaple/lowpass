# 推荐理由原始长度验收 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新生成理由归一化后超过60字即拒绝，避免本地硬截断损坏句子或项目名；每次真实调用前遵守月费用上限。

**Architecture:** 沿用现有 Parser::Invalid、Generator 最多首次加两次重试及 ModelCall 账本。只成功响应能进入 store；失败重生成保留旧理由、标签、译文和时间。同步修订 PRD，独立提交 PR，发布另行验收。

**Tech Stack:** Rails 8 / Ruby 3.4.8 / PostgreSQL 18 / Minitest / WebMock；无新依赖。

**Spec:** 用户2026-10-22明确批准“采用新验收契约”：超过60字判失败，首次加最多2次重试，每次前检查月上限并记账；失败不写新字段，重生成失败保留旧字段，失败响应译文不保存；同步PRD、离线回归及独立PR，保持模型和历史理由。原规范为 `docs/superpowers/specs/2026-09-08-mvp-prd.md` §5.9 R-9.3、R-9.6、R-9.8、D25。

## Global Constraints

- 归一化顺序维持 `strip.gsub(/\s+/, " ")`，长度按现有Ruby Unicode字符数，20与60均可接受，19与61均拒绝。
- 每条最多3次真实请求；月cap=0仍表示不限。只给实际请求记账，invalid也记录usage/cost。
- 每次 Provider.chat 前重查 Budget.exhausted?，已达上限立即结束本条，不发送下一次请求。
- 401/403/429不追加重试；其他既有失败分类、provider参数、供应商、提示词、价格、cap均保持。
- 无生产模型请求、无生产配置或刊期写入，不重新生成历史内容；仅离线Minitest/WebMock。
- 同次invalid响应的译文不可写入，也不可混入下一次成功结果；有效理由搭无效译文仍不为译文重试。
- 这只防止本地机械截断；不添加句号检测，不宣称已解决模型原始半句或事实支持问题。

## Review Focus

- 归一化后临界长度：多余空白不能让有效60字符误失败，归一化61仍拒绝。
- 超长含项目名：保留原始长度错误而非把被切掉的前60字视为成功。
- 首次invalid用尽月预算：下一次请求不可发生；cap=0时仍遵守最多3次请求。
- 已有理由的手动重生成失败：旧reason/tag/title_zh/summary_zh/generated_at与updated_at保持。
- 失败译文污染及成功后空译文：不能把失败响应译文存入新结果；现有有效理由/无效译文行为不变。

---

### Task 1: 原始输出验收与有预算的重试

**Files:**
- Modify: `app/models/reasons/parser.rb` — 长度上下限及返回完整归一化reason。
- Modify: `app/models/reasons/generator.rb` — 每次调用前重查预算。
- Test: `test/models/reasons/parser_test.rb` — 19/20/60/61、空白与超长项目名。
- Test: `test/models/reasons/generator_test.rb` — 超长重试、账本、旧字段保留及译文隔离。
- Modify: `docs/superpowers/specs/2026-09-08-mvp-prd.md` — R-9.3/R-9.6/R-9.8、异常边界及决议/修订记录。

**Interfaces:**
- Consumes: `Reasons::Parser.parse(text, allowed_names)`；`Reasons::Budget.exhausted?`；现有 Provider / store / record。
- Produces: 原有 `Parser::Result` 或 `Parser::Invalid`；`Generator.generate_item!` 的boolean与生成统计接口不变。

- [x] **Step 1: 写有意义的失败回归。**
  - Parser:19拒绝；20/60逐字返回；61及归一化后仍超长抛Invalid，错误只含长度。将旧“80截到60”测试替换为拒绝契约，保留JSON/标签/译文已有边界。
  - Generator:61→有效结果仅两次请求且账本invalid/ok；连续三次超长失败且三条invalid及准确usage/cost；重生成失败不改旧字段；失败title_zh不流入后续有效reason。
  - 用正费率和低cap证明第一次invalid耗尽预算后只有一次实际调用、一次账本；cap=0仍可三次，合法理由/不合规译文仍一次成功。
- [x] **Step 2: 跑红并确认是所需行为差异。**
  - Run: `CI=true mise exec ruby@3.4.8 node@24 -- ruby bin/rails test test/models/reasons/parser_test.rb test/models/reasons/generator_test.rb`。
  - 本机若子进程误取系统Ruby，使用Ruby入口将 `RbConfig::CONFIG["bindir"]` 前置PATH；测试全程WebMock，不访问供应商。
- [x] **Step 3: 最小实现并修订规范。**
  - Parser对归一化reason的 `length > MAX` 抛Invalid，返回reason本身；不增加模糊语义验证或新异常类别。
  - Generator在重试循环每次请求前判断cap；不伪记未调用请求，不主动清空旧字段。
  - PRD记录用户批准的超长拒绝与每次请求前预算规则，继续明确历史保持、失败保留旧值及译文副产物边界。
- [x] **Step 4: 验证并独立审阅。**
  - 重跑两类模型测试、受影响Reasons/Budget/ModelCall/Job/请求测试，期望零失败；RuboCop和diffcheck通过。
  - 根代理完整 `bin/ci`、独立攻击diff，重点Review Focus，不用“JSON通过”作为编辑质量达标证明。
- [ ] **Step 5: 提交并创建独立PR。**
  - 根代理验证后提交、推送新分支并附加PR；不合并/部署本契约，不再发送额外远端试词请求。

## 执行边界

工作树 `/Users/drewlee/.codex/worktrees/reading-entry-quality/lowpass`，分支 `codex/reasons-output-contract`，基线为PR #68合并 `c1f47954b56f4d8c08d58f02a9beab0ee61b8081`。原PR #67分支引用保留。执行方式沿用当前协作：GPT工作代理实施，根代理及独立审阅验收；用户已批准以上完整契约，无需再次确认同一范围。

## 工作代理执行记录（2026-10-22）

- Red：先改两份测试，旧实现运行 `parser_test.rb` 与 `generator_test.rb` 得到 30 runs、127 assertions、9 failures、0 errors。失败包括超长未抛 Invalid、错误保存为成功及首次 invalid 后已达 cap 仍发出三次请求。
- Green：最小改动 Parser 与 Generator 后，同一两份测试为 30 runs、151 assertions、0 failures、0 errors。
- 受影响验证：`test/models/reasons`、`test/models/model_call_test.rb`、`test/jobs/generate_reasons_job_test.rb`、`test/controllers/admin/items/reasons_controller_test.rb`、`test/controllers/admin/issues/reasons_controller_test.rb` 合计 60 runs、302 assertions、0 failures、0 errors、0 skips。全部调用由 WebMock 隔离；未请求真实模型。
- 运行方式：`CI=true mise exec ruby@3.4.8 node@24 -- ruby -rrbconfig -e 'ENV["PATH"]=[RbConfig::CONFIG["bindir"],ENV.fetch("PATH")].join(File::PATH_SEPARATOR); exec(RbConfig.ruby,"bin/rails",*ARGV)' -- test <测试路径>`。
- 四份改动 Ruby 文件经 RuboCop 验证，4 files inspected、no offenses detected；`git diff --check` 通过。工作代理自审已检查归一化顺序、完整返回、逐次预算门禁、失败账本与两种译文隔离。
- Step 4 的根代理独立验收、完整 `bin/ci` 及 Step 5 的提交和 PR 尚未执行。工作代理未提交、推送、合并或部署；未修改 Prompt / Provider / 配置及历史字段。

### 评审修复第 1 轮：预算终止告警一致性

- 根原因：逐次预算 guard 只返回 false，预算告警原本只在外层处理下一条条目时触发。唯一或最后条目没有下一次循环，直接重生成也不经过外层；第三次 invalid 恰好触顶更没有下一次重试 guard。已有理由全部保留时，原来无缺失就 recover 的路径还会立刻关闭预算告警。
- 核查：`Alerts.reasons_missing!` 接受 0 缺失数和自定义摘要，已有期 / 上海日唯一键可去重；单条 controller 进入前已达 cap 时只返回停止提示，进入后失败显示最后 ModelCall 的原因，不负责这次新发生的预算告警。因此修复放在 Generator，不修改 controller、告警模型或事件种类。
- 修复：外层与单条预算终止复用同一告警方法；单条 guard 以及三次失败结束处都能记录预算告警。缺失数为 0 时使用“本月费用已达上限，已停止生成”，仍只统计实际无理由的可见条目；重复遇到同一期预算终止沿用既有去重，不重复投递。
- 取舍：无缺理由时，只有预算未耗尽才执行原来的 recover；已存在的预算告警会保持到预算解除且无缺失，避免旧字段保留把预算终止误报为恢复。最后一条成功且无需下一次请求时不新建预算终止告警，未扩展成功路径的告警范围。
- 红绿证据：旧 guard 新增 4 项测试为 4 runs、15 assertions、4 failures、0 errors，均复现漏告警；修复后连同成功路径反例为 5 runs、36 assertions、0 failures、0 errors、0 skips。
- 修复后受影响验证：上述 Reasons / ModelCall / Job / 两个请求测试，另加 `test/models/alerts_test.rb`，共 73 runs、383 assertions、0 failures、0 errors、0 skips。四份 Ruby 文件 RuboCop 无违规，`git diff --check` 通过。使用同一 CI / Ruby 3.4.8 / Node 24 入口及 WebMock 隔离，没有真实模型调用。
- 这次修复尚待根代理独立验收与修复后的完整 CI；工作代理仍未提交、推送或访问生产。

## 根代理最终验收（2026-10-22）

- 独立审查最初指出最后/唯一条目在重试预算终止时漏告警；补红绿回归并修复，复审确认已关闭，无 Critical / Important。
- 非阻塞取舍：预算未解除时暂停整个 `reasons_missing` 的自动恢复，包括已有普通缺理由告警；这样同类预算告警不会因重生成保留旧理由、缺失数为零而立即被恢复。PRD R-9.8 已明确此统一预算条件，PR 描述保留说明。原有全局恢复范围不扩大。
- 最终完整 `bin/ci` 通过（64.25秒）：454前端测试，870 Rails测试/3846断言，77系统测试/8044断言；首屏264.56/300 KB。日志 `/tmp/lowpass-reasons-output-contract-final-ci-20261022.log`，全部供应商请求由测试桩隔离，没有真实模型调用。
- 主工作区保持原分支；本契约仅在隔离工作树提交。PR #68 已独立完成生产验收，本契约未经新的发布授权不合并/部署。
