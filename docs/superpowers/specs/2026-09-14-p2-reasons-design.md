# P2-④ 推荐理由与兴趣画像设计

日期：2026-09-14 · 状态：草案（产品负责人设定了「实现 P2」的目标并要求不打断；本文档里需要选择的地方按 §15「默认决定」定，全部可推翻）
依据：PRD `docs/superpowers/specs/2026-09-08-mvp-prd.md` 5.9（D16、R-9.1 到 R-9.9、AC-9.1 到 AC-9.4）、5.6 设置页一行、5.7「推荐理由缺失」、7.2 的 `reason` / `interest_tag` / `reason_generated_at`、附录 A 的 InterestArea、D17 / D18 / D19 / D23、N-10；ADR T8（2026-09-11：接入层按可切换供应商设计，密钥只从环境读，自托管不在 P2）
前置：P2-①（登录）、P2-②（管理后台）、P2-③（告警的 `reasons_missing` kind）

> **历史设计与现行契约。** 本文保留2026-09-14设计及后续决定的来源，不将新细节追认为当时已批准。2026-10-22的D37取代超长截断；2026-10-23产品负责人已批准D38完整本地候选方案，取代下文“每条必须有理由”、旧无decision协议、仅凭reason计缺失、全局理由告警恢复及旧后台状态。当前规范统一以 `2026-09-08-mvp-prd.md` §5.7、§5.9、D25/D37/D38、AC-9.9–AC-9.18和 `2026-10-23-reason-abstention-design.md` 为准。D38尚处本地候选实现/离线验收阶段，本文不证明已实现、通过或部署。

## 1. 范围

做：兴趣画像（`interest_areas` 表，初始 10 个领域，后台增删改）；模型接入层（OpenAI 兼容的 chat completions 协议，地址、模型名、单价与月费用上限在后台配，密钥只从环境读）；日刊发布后异步给每条条目生成 20 到 60 字的中文理由与一个兴趣标签（单条重试 2 次，缺领域名判失败）；调用账本（次数、token、费用；月上限到了就停并告警）；后台：设置页「兴趣画像」「推荐理由」两节，期页每期「理由缺失 N 条」与「重生成理由」，读者页管理员可见的单条「重生成」；期发布 30 分钟后仍缺理由的告警（③ 的 `reasons_missing`）；文档与附录 B。

上段为原范围记录。“每条生成”现由D38改为先判断证据，合法不足不写理由但不减少刊登条目；旧后台状态由四类真实计数取代。本文不新增读者端重生成入口。

> 2026-09-17 后续产品决策：读者页移除单条重生成入口，避免误触产生模型费用；后台期页的整期重生成和受保护的单条后端接口保留。下文关于读者页入口与 C6 的记录由此决策取代。

> 2026-09-27 后续产品决策（PRD D25，取代 D17）：日刊条目在同一次调用里加产简体中文译文，原文保留、译文排在它译的原文下方。Hacker News 与 Hackaday 译标题，存 `items.title_zh`（string(300) + CHECK），要不要译看 `Source#translates_titles?`（日刊的 `hacker_news` 与 `rss`）且标题不含汉字（`Item#translate_title?`）；GitHub Trending 的标题是仓库名，译说明也就是仓库简介，存 `items.summary_zh`（string(500) + CHECK），看 `Source#translates_summaries?`（日刊的 `github_trending`）且简介非空、不含汉字（`Item#translate_summary?`）。系统提示按要译的那几段拼上翻译要求，输出多出 `title_zh` / `summary_zh`；`max_tokens` 在 200 之上按段放宽（标题 +120、简介 +400），不译的条目提示词与上限逐字不变。译文不合规（缺、不是字符串、不含汉字、超过上限）只当没有，不判 `invalid`、不重试，理由照写；「缺理由」的计数、告警与 `only_missing` 仍只看 `reason`。跨天沿用要求前一条原文（标题或简介）相同且带译文，否则整条重新生成；重生成时这一次没译出来就保留旧译文。下文「不做：标题译文（D17）」由此取代。

> 2026-10-23后续决定（D38）：上段中“不译时提示词逐字不变”和“只看reason”为D25当时记录，不再是新候选约束。新候选Prompt与严格Parser必须同批交付，token预算200 / 标题+120 / 简介+400不变；只有同次合法generated可保存需要且合规的译文，拒写不单独保存译文。待处理改为可见日刊、reason为nil且无ReasonAbstention；成功复用候选须无marker且继续满足D25原文/译文前提。

不做：标题译文（D17）、每用户画像（P1 的 D2）、自托管模型（T8 的 C）、周刊条目（D19）、理由的人工编辑界面（PRD 没要）、流式输出、按条目缓存到跨天以外的范围（R-1.11 的「跨天重复沿用前一日理由」按同 `url_hash` 查上一期即可）。

## 2. 决策

- **协议不是厂商**：接入层只实现 OpenAI 兼容的 `POST {base_url}/chat/completions`（`Authorization: Bearer`，JSON 请求与响应，`usage` 计 token）。OpenAI、DeepSeek、Moonshot、通义、智谱、OpenRouter、Ollama 都提供这个协议；产品负责人只需在设置页填地址与模型名，密钥放 `MODEL_API_KEY`。切换供应商 = 改两个字段与一个环境变量。
- **费用由本地算**：接口返回的 `usage.prompt_tokens` / `completion_tokens` 乘以后台填的单价（每百万 token 的输入价、输出价，货币与月上限一致）。上限到了就停止生成、告警一次；次月自动恢复。
- **生成与发布解耦**（R-9.1）：`Issue::Finalization#finalize!` 置为 published 后入队 `GenerateReasonsJob(issue)`；手动重抓（`revise!`）后再入队一次，只补没有理由的条目；后台「重生成」是整期覆盖。读者页刷新即见，不做推送。
- **一期一个 job，条目顺序处理**：30 条 × 最多 20 秒 ≤ 5 分钟（R-9.8）由单条超时保证；`limits_concurrency` 按期。

## 3. 数据模型

### 3.1 `interest_areas`（附录 A 的 InterestArea）

| 列 | 类型 | 说明 |
|---|---|---|
| id | string(25) | UUIDv7 base36 |
| name | string(20) | 唯一（不区分大小写的表达式索引）；就是条目的 `interest_tag`（7.2 限 20 字符） |
| keywords | string(200) | 顿号或逗号分隔的关键词，原样进提示词 |
| sort_order | integer | 默认 0 |
| enabled | boolean | 默认 true；停用的领域不进提示词，但已生成的标签不动 |
| created_at / updated_at | | |

初始 10 个领域按 PRD 5.9 的表进 `db/seeds.rb`（幂等：按名称 `find_or_create_by!`）；`bin/rails db:seed` 在 `bin/setup` 与 Kamal 首次 `db:prepare` 时跑，`Tests: Seeds` 已在门禁里。

### 3.2 `model_calls`（调用账本，R-9.8「每日调用次数与费用在后台可见」）

| 列 | 类型 | 说明 |
|---|---|---|
| id | string(25) | |
| issue_id / item_id | string(25) null | FK，`on_delete: :nullify` |
| status | string(10) | 原CHECK为ok / failed / timed_out / invalid；D38候选扩充校验与CHECK以接受abstained，列长不变 |
| prompt_tokens / completion_tokens | integer 默认 0 | 来自真实usage，invalid / abstained也计实际用量；未返回usage时沿用0，未发请求不建账本（D37/D38） |
| cost | decimal(10,4) 默认 0 | 本地按单价算 |
| duration_ms | integer | |
| error_summary | string(200) null | |
| created_at | | 索引；保留 90 天（`ModelCall.cleanup` 挂进 tick） |

### 3.3 `Setting` 新键

`model_base_url`（默认空）、`model_name`（默认空）、`model_input_price`、`model_output_price`（每百万 token，默认 `0`）、`model_monthly_cap`（默认 `0` = 未设上限，`0` 时费用照记不拦）。密钥不进库：`MODEL_API_KEY` 只从环境读，设置页只显示「已配置 / 未配置」。「已配置供应商」= `model_base_url`、`model_name`、`MODEL_API_KEY` 都非空。

### 3.4 `items`

不加列：`reason`（120）、`interest_tag`（20）、`reason_generated_at` 已在 P0 建好；读者页 `ItemRow` 已渲染。

### 3.5 D38候选：`reason_abstentions`

独立一对一ReasonAbstention，字段为25字符UUIDv7 base36 id、非空且数据库唯一的25字符item_id、非空UTC assessed_at与自身created_at/updated_at；item FK删除CASCADE，确保重抓delete_all也清理。只保存最后完成并提交的合法不足判断，不存自由诊断/原回复，不touch Item/Issue，无历史回填；与Item同寿命，90天ModelCall清理不影响marker。合法generated在同一Item锁事务内更新内容并删marker；合法不足只新建/更新marker，新旧Item全部字段保留。数据库业务写入失败仍保留已记的真实请求账本，不额外重试模型。

## 4. 生成

### 4.1 输入（R-9.2）

标题、说明（`summary`，可空）、来源名、元数据里可读的部分（分数 / 评论数 / star / 语言，从 `meta` 取已知键）、兴趣画像全文（启用的领域按 `sort_order`：`名称：关键词`）。不抓原文。

### 4.2 提示词与输出（R-9.3）

以下两段保留旧协议与旧截断决定的历史，已被D37/D38取代，不能用于新候选Parser或Prompt。

系统提示（中文）：你是技术刊物编辑；给出 20 到 60 字的中文推荐理由，必须点名下列领域之一，相关度低就直说「相关度中等」或「相关度较低」，不得编造关联；输出 JSON `{"reason": "...", "interest_tag": "<领域名>"}`。用户消息：画像 + 条目字段。请求参数：`temperature 0.3`、`max_tokens 200`、`response_format: { type: "json_object" }`（不支持的端点会忽略，解析仍按「找到第一个 JSON 对象」兜底）。

校验：`reason` 去首尾空白后 20 到 60 个字符（按 `String#length`，中文一字一算；超过 60 截到 60，短于 20 判失败）；`interest_tag` 必须等于某个启用领域的名称（判失败）；失败重试最多 2 次（共 3 次调用），仍失败记 `invalid`、该条留空。

现行候选输出必须明确decision。generated要求reason/tag为字符串，归一化20–60字不截断、含汉字且正文点名标签对应的启用领域；仅按条目所需接受同次合规译文。另一合法结果完整对象只有 `{"decision":"insufficient_evidence"}`，任何附带字段（包括null/空字符串）都invalid。缺/未知decision、非对象、空响应、混合分支、解析异常或技术失败不能改判为不足；两分支沿用相同外层JSON提取兼容方式后严格验收。证据规则及A1–A10以现行PRD和D38完整设计为准，Parser合规不等于事实核验。

### 4.3 `Reasons::Generator`

```ruby
Reasons::Generator.generate!(issue, only_missing: true)   # 整期；后台「重生成」传 only_missing: false
Reasons::Generator.generate_item!(item)                    # 单条（后台「重生成」单条）
```

- 前置：`Reasons.ready?`（供应商配好 + 画像里有启用的领域，C12），否则直接返回（读者页不提示，后台显示「未配置模型供应商」或「兴趣画像为空」）；`Reasons::Budget.exhausted?` 则返回并 `Alerts.reasons_missing!(issue, 缺理由数)`（摘要「本月费用已达上限」）。
- 补缺候选（D38）：只取统一待处理范围；跨天同url_hash成功复用必须无marker，仍检查D25同原文/合规译文；不复制不足判断。`only_missing: false`及显式单条重新评估可见日刊条目，不因marker跳过。
- 每条候选：Provider → Parser → 按真实请求写账本 → 受Item锁保护保存合法结果。generated记ok并原子保存内容/删marker；合法不足记abstained后只保存判断并立即终止；失败保留旧内容/marker，仍受D37有限重试与预算约束。旧“update_columns后写账本”说明不适用。
- 返回候选：单条明确generated / abstained / failed；整期Outcome分别计generated / reused / abstained / failed，skipped只表示供应商或画像未准备好。不得把合法不足计作成功生成、失败或未调用。
- 完成候选：共用待处理范围为0且预算未耗尽时，只恢复该issue已有reasons_missing；旧不带issue的全局恢复语义已被D38取代。

### 4.4 `Reasons::Provider`（接入层）

`Net::HTTP` POST `#{base_url}/chat/completions`，`open_timeout 5`、`read_timeout 20`（R-9.8 单条 20 秒），响应体边读边截、上限 64 KB（超了当场抛，不整段读进内存；同 `Adapters::Http#read_capped`），`User-Agent` 复用 `Adapters::Http::USER_AGENT`。地址必须 https，`localhost` / `127.0.0.1` 允许 http（本地 Ollama），发请求前再校验一次。5xx / 超时 → `Reasons::Provider::Error`（单条重试范围内）；401 / 403 → `Rejected`，摘要写「密钥被拒绝」，本期不再继续（其余条目都会一样失败）；429 → `Limited`，同样不重试、本期停止（C11）。

### 4.5 `GenerateReasonsJob`

`perform(issue, only_missing = true)`；`limits_concurrency to: 1, key: ->(issue, *) { issue.id }, duration: 10.minutes`；不用 `retry_on`（单条重试在 Generator 里）；异常记 `Rails.error.report` 后抛出（队列面板可见）。入队点：`finalize!` 置 published 之后、`revise!` 之后（都在锁外，与③同款）、后台「重生成」。

### 4.6 预算 `Reasons::Budget`

`month_cost` = 本月（上海时区自然月）`model_calls.sum(:cost)`；`exhausted?` = 上限 > 0 且 `month_cost >= 上限`。`today_calls` = 今日条数。设置页显示「本月 N 次 · 费用 X / 上限 Y」「今日 N 次」（数字走 Maple）。

## 5. 告警（复用③）

- 缺理由（D38候选）：当天发布满30分钟且ready，统计可见日刊、reason为nil且无ReasonAbstention的统一待处理范围后按期/日去重告警。tick不新增模型请求。
- 上限：每次真实请求前重查，真正预算阻止或最后失败耗尽预算时立即告警；摘要待处理数也共用该范围，0时写“本月费用已达上限，已停止生成”。最后合法generated或abstained完成且无需后续请求不另造终止事件。
- 恢复：只恢复该issue已有事件，条件为零待处理且预算未耗尽；不关闭别期或预算未解除事件。源抓取、搜索等原恢复语义不变。

## 6. 后台

### 6.1 设置页 `/admin/settings` 新增两节

「兴趣画像」：表格（名称 / 关键词 / 排序 / 启用），每行可改（`PATCH /admin/interest_areas/:id`）、可删（`DELETE`，有条目用着该标签也允许删，标签是文本快照）、末尾一行新增（`POST /admin/interest_areas`）；校验：名称必填 ≤ 20 字、唯一（「名称已存在」）、关键词 ≤ 200 字。

「推荐理由」：表单（接口地址、模型名、输入单价、输出单价、月费用上限；`PATCH /admin/settings` 的 `model` 组）+ 只读行「密钥」（值是「已配置 / 未配置」，来自 `MODEL_API_KEY`）+ 用量行「本月 N 次 · 费用 X / 上限 Y」「今日 N 次」+ 一句「未配置模型供应商」当三样缺一。

### 6.2 期页 `/admin/issues`

D38候选沿用理由格与刊物详情：可见条目分为“已有理由N条”“资料不足未写M条”“保留旧理由L条（本次资料不足）”“缺K条”，四类互斥合计等于可见日刊条目数，零可省略；只有K为待处理故障，最后不足判断时间显示为“最后处理”，不冒充生成时间。未配置/空画像保留真实计数与独立禁用原因，ready控制按钮。整期操作入口及“已开始”提示保持，不将拒写计入已生成；不改版、不增颜色/装饰。

### 6.3 读者页（管理员）

本节下段为已于2026-09-17撤回的入口历史，D38不恢复它。现行读者无单条重生成控件；新拒写不显示空标签、假译文、失败占位或诊断；有旧理由者保留原内容，不新增证据核验标识。受保护后端接口仍可用于管理，合法结果文案见§10并按现有路径审计实际结果。

日刊条目的理由区域：管理员登录时，理由下方（或缺理由时的位置）有一个 `link-button`「重生成」（`POST /admin/items/:id/reason`，同步调用一次模型，最多 20 秒，flash「已重生成」/「重生成失败：{reason}」）。普通读者看不到任何控件（R-9.6：读者页不提示）。

## 7. 路由

```ruby
namespace :admin do
  resources :interest_areas, only: [ :create, :update, :destroy ]
  resources :issues, only: :index, param: :period_key, constraints: {...} do
    resource :reasons, only: :create, module: :issues          # 整期重生成
  end
  resources :items, only: [] do
    resource :reason, only: :create, module: :items            # 单条重生成
  end
end
```

设置页的 `model` 组走现有的 `PATCH /admin/settings`（`params.permit(schedule: …, model: …)`）。

## 8. 页面与组件

复用②的 `Table`、`Field`、`SegButtons`、`Toast`、`usePolling`、`AdminPage`；新组件只有设置页里的可编辑表格行（`InterestAreaRow`）。字体：领域名与关键词中文走文楷，单价 / 次数 / 费用走 Maple，接口地址走 Maple；无新颜色。

## 9. 测试

下表为原实施范围，截断与读者端管理员控件测试已随后续决定被取代。当前D38候选必须完成现行PRD的AC-9.9–AC-9.18（完整设计A1–A10）：自动测试禁网，375/390px及桌面实际浏览器/键盘/减少动效验收，不用PDF；六条既有真实输入与十组正反语义卡保持私密、由非Prompt作者离线审查，不冒充实网模型通过。

- 模型：`InterestArea` 校验与唯一；`Reasons::Parser`（JSON、夹杂文本的 JSON、缺字段）；校验规则（20–60 字、截断、领域名匹配）；`Budget`（月界按上海、上限 0 不拦）；跨天沿用。
- 接入层（WebMock）：请求体形状（messages、response_format、model）、`Authorization` 头、`usage` 入账、429 / 5xx / 超时 / 401 的映射、http 非本地拒绝。
- 生成：一期 3 条全部生成；一条输出缺领域名重试 2 次后留空并记 `invalid`；上限到了不调模型且告警；`only_missing`；`recover!`。
- Job / 钩子：`finalize!` published 入队、`revise!` 入队、后台重生成入队；`limits_concurrency`。
- Scheduler：发布 31 分钟仍缺 → 告警一次；29 分钟不告。
- 控制器：兴趣画像 CRUD + 校验 + 审计；设置页 `model` 组校验（地址 https、单价与上限非负数字）；整期 / 单条重生成（admin、403、未配置时 alert）。
- 前端（Vitest）：设置页两节、期页「理由」格与按钮、读者页管理员控件（普通用户不渲染）。
- 系统测试：配置供应商（WebMock 假端点）→ 期页「重生成理由」→ `perform_enqueued_jobs` → 读者页看到理由与标签。
- 全部不碰网络。

## 10. 文案（附录 B，v0.3.13）

| 位置 | 文案 |
|---|---|
| 推荐理由状态（D38候选） | 已有理由 N 条 · 资料不足未写 M 条 · 保留旧理由 L 条（本次资料不足） · 缺 K 条 · 最后处理 YYYY-MM-DD HH:mm · 未配置模型供应商 · 兴趣画像为空 · 本月 N 次 · 费用 X / 上限 Y · 今日 N 次 · 密钥 · 已配置 · 未配置 |
| 重生成（D38候选） | 已开始重生成理由 · 已重生成 · 资料不足，未生成理由 · 本次资料不足，保留旧理由 · 重生成失败：{reason} · 本月费用已达上限，缺理由 N 条 · 本月费用已达上限，已停止生成 · 兴趣画像为空 · 未配置模型供应商 |
| 兴趣画像校验 | 名称已存在 · 最多 20 字 · 最多 200 字 · 必填 |
| 模型配置校验 | 地址必须是 https · 不小于 0 · 必填 · 最多 255 字 |

## 11. 运维

- 环境变量：`MODEL_API_KEY`（`.kamal/secrets`、`deploy.yml`）。
- `docs/development.md` 加「推荐理由」一节：本地用 Ollama（`http://localhost:11434/v1`，密钥随便填）或任一兼容端点；`db:seed` 建初始画像；怎么看账本。
- 内存预算：无新进程。

D38第一阶段只交付完整本地候选、离线证据与未合并PR；Prompt/Parser/持久化/记账/后台/告警同批交付，不执行新付费试验，不变更模型/端点/价格/上限/token预算，不合并部署或自动重写历史。后续实网内容试验和发布须另行确定范围并取得授权。启用后若应用回退，先停止本轮理由任务并明确人工范围，保留reason_abstentions、marker与abstained账本及CHECK；不能删除新记录让旧代码继续跑，旧代码忽略marker可能重复收费/误告警，不是透明回退。具体步骤在获授权的发布候选阶段补齐。

## 12. 默认决定（代理定，可推翻）

| 编号 | 决定 | 理由 |
|---|---|---|
| C1 | 接入层只做 OpenAI 兼容协议；供应商 = 地址 + 模型名 + 环境里的密钥 | T8「按可切换供应商设计」；不替产品负责人选厂商，主流国内外端点与本地 Ollama 都兼容 |
| C2 | 费用本地按后台填的单价算 | 各家计费接口不同；单价两格就够，且上限比价可控（N-10） |
| C3 | 一期一个 job 顺序生成，单条 20 秒超时，条内重试 2 次 | R-9.6 / R-9.8；30 条串行最坏 20 分钟但正常 1–2 分钟；并发对上游限流不友好 |
| C4 | 历史决定：20–60字、超长截断。已被2026-10-22 D37的超长拒绝取代，D38再加入显式两分支/对应领域与证据规则 | 保留当时依据，不作为现行验收；以现行PRD §5.9为准 |
| C5 | 停用的领域不进提示词，已生成标签不动 | 画像修改只影响之后的生成（5.9 异常） |
| C6 | 单条重生成放在读者页（管理员可见的 link-button） | PRD 要「重生成单条」，后台没有条目列表；读者页本来就按条目排 |
| C7 | tick仍检查发布30分钟后的当天日刊；D38候选待处理排除marker、恢复按issue且预算未耗尽 | 5.7与D38；不另起job、不自动请求模型 |
| C8 | 上限为 0 视为不限 | 默认不拦，让首次配置能跑起来 |
| C9 | 理由写入用 `update!`（走校验与 `after_save_commit`） | R-9.7 唯一可补写字段；`Searchable` 的注释本来就把「推荐理由补写」列为单条改动经回调同步索引的情形，索引本身不含 reason，重建一次无害 |
| C10 | 历史决定为补缺时跨日复制成功理由，显式重生重新生成；D25加入同原文译文前提，D38候选再排除带marker的成功旧理由，不复制拒写结论 | 以现行PRD R-1.11、§5.9为准，旧内容保留不等于允许继续传播 |
| C11 | 429 与 401 / 403 一样不重试，本期停止 | 仓库不变量「429 / 403 不追加重试」；重试只会把上游的限流窗口拉得更长 |
| C12 | 画像里没有启用的领域就不生成（`Reasons.ready?`） | 画像为空时每条都会判「缺领域名」，三次调用三次白花钱；现有库里画像是空的（`db:prepare` 只给新建的库播种） |

## 13. 实现顺序

1. 迁移（`interest_areas`、`model_calls`）+ 模型 + seeds + `Setting` 新键 + `Reasons::Budget`
2. `Reasons::Provider`（接入层）+ `Reasons::Parser` + 校验
3. `Reasons::Generator` + `GenerateReasonsJob` + 钩子（`finalize!`、`revise!`）+ Scheduler 检查 + 告警
4. 后台：兴趣画像 CRUD、设置页 `model` 组与用量、期页「理由」格与整期重生成、读者页单条重生成
5. 前端页面（Vitest）
6. 文档、附录 B、部署变量、系统测试、`bin/ci`
