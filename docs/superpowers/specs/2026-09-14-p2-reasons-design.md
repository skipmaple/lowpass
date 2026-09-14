# P2-④ 推荐理由与兴趣画像设计

日期：2026-09-14 · 状态：草案（产品负责人设定了「实现 P2」的目标并要求不打断；本文档里需要选择的地方按 §15「默认决定」定，全部可推翻）
依据：PRD `docs/superpowers/specs/2026-09-08-mvp-prd.md` 5.9（D16、R-9.1 到 R-9.9、AC-9.1 到 AC-9.4）、5.6 设置页一行、5.7「推荐理由缺失」、7.2 的 `reason` / `interest_tag` / `reason_generated_at`、附录 A 的 InterestArea、D17 / D18 / D19 / D23、N-10；ADR T8（2026-09-11：接入层按可切换供应商设计，密钥只从环境读，自托管不在 P2）
前置：P2-①（登录）、P2-②（管理后台）、P2-③（告警的 `reasons_missing` kind）

## 1. 范围

做：兴趣画像（`interest_areas` 表，初始 10 个领域，后台增删改）；模型接入层（OpenAI 兼容的 chat completions 协议，地址、模型名、单价与月费用上限在后台配，密钥只从环境读）；日刊发布后异步给每条条目生成 20 到 60 字的中文理由与一个兴趣标签（单条重试 2 次，缺领域名判失败）；调用账本（次数、token、费用；月上限到了就停并告警）；后台：设置页「兴趣画像」「推荐理由」两节，期页每期「理由缺失 N 条」与「重生成理由」，读者页管理员可见的单条「重生成」；期发布 30 分钟后仍缺理由的告警（③ 的 `reasons_missing`）；文档与附录 B。

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
| status | string(10) | CHECK：`ok` `failed` `timed_out` `invalid`（输出不合规） |
| prompt_tokens / completion_tokens | integer 默认 0 | 来自 `usage`，失败为 0 |
| cost | decimal(10,4) 默认 0 | 本地按单价算 |
| duration_ms | integer | |
| error_summary | string(200) null | |
| created_at | | 索引；保留 90 天（`ModelCall.cleanup` 挂进 tick） |

### 3.3 `Setting` 新键

`model_base_url`（默认空）、`model_name`（默认空）、`model_input_price`、`model_output_price`（每百万 token，默认 `0`）、`model_monthly_cap`（默认 `0` = 未设上限，`0` 时费用照记不拦）。密钥不进库：`MODEL_API_KEY` 只从环境读，设置页只显示「已配置 / 未配置」。「已配置供应商」= `model_base_url`、`model_name`、`MODEL_API_KEY` 都非空。

### 3.4 `items`

不加列：`reason`（120）、`interest_tag`（20）、`reason_generated_at` 已在 P0 建好；读者页 `ItemRow` 已渲染。

## 4. 生成

### 4.1 输入（R-9.2）

标题、说明（`summary`，可空）、来源名、元数据里可读的部分（分数 / 评论数 / star / 语言，从 `meta` 取已知键）、兴趣画像全文（启用的领域按 `sort_order`：`名称：关键词`）。不抓原文。

### 4.2 提示词与输出（R-9.3）

系统提示（中文）：你是技术刊物编辑；给出 20 到 60 字的中文推荐理由，必须点名下列领域之一，相关度低就直说「相关度中等」或「相关度较低」，不得编造关联；输出 JSON `{"reason": "...", "interest_tag": "<领域名>"}`。用户消息：画像 + 条目字段。请求参数：`temperature 0.3`、`max_tokens 200`、`response_format: { type: "json_object" }`（不支持的端点会忽略，解析仍按「找到第一个 JSON 对象」兜底）。

校验：`reason` 去首尾空白后 20 到 60 个字符（按 `String#length`，中文一字一算；超过 60 截到 60，短于 20 判失败）；`interest_tag` 必须等于某个启用领域的名称（判失败）；失败重试最多 2 次（共 3 次调用），仍失败记 `invalid`、该条留空。

### 4.3 `Reasons::Generator`

```ruby
Reasons::Generator.generate!(issue, only_missing: true)   # 整期；后台「重生成」传 only_missing: false
Reasons::Generator.generate_item!(item)                    # 单条（后台「重生成」单条）
```

- 前置：`Reasons::Provider.configured?`，否则直接返回（读者页不提示，后台显示「未配置模型供应商」）；`Reasons::Budget.exhausted?` 则返回并 `Alerts.reasons_missing!(issue, 缺理由数)`（摘要「本月费用已达上限」）。
- 跨天重复（R-1.11）：同 `url_hash` 在更早的日刊里已有理由的条目，直接复制理由与标签（不调模型，`reason_generated_at` 记现在）。
- 每条：`Reasons::Provider.chat(messages)` → `Reasons::Parser.parse(text)` → 校验 → 写 `items`（`update_columns` 不走校验回调即可，理由是发布后唯一可补写字段，R-9.7）；每次调用记一条 `model_calls`。
- 一期跑完：`Alerts.recover!(kind: "reasons_missing")` 当该期没有缺理由的条目。

### 4.4 `Reasons::Provider`（接入层）

`Net::HTTP` POST `#{base_url}/chat/completions`，`open_timeout 5`、`read_timeout 20`（R-9.8 单条 20 秒），响应体上限 64 KB，`User-Agent` 复用 `Adapters::Http::USER_AGENT`。地址必须 https，`localhost` / `127.0.0.1` 允许 http（本地 Ollama）。429 / 5xx / 超时 → `Reasons::Provider::Error`（单条重试范围内）；401 / 403 → 同样失败但摘要写「密钥被拒绝」，本期不再继续（其余条目都会一样失败）。

### 4.5 `GenerateReasonsJob`

`perform(issue, only_missing = true)`；`limits_concurrency to: 1, key: ->(issue, *) { issue.id }, duration: 10.minutes`；不用 `retry_on`（单条重试在 Generator 里）；异常记 `Rails.error.report` 后抛出（队列面板可见）。入队点：`finalize!` 置 published 之后、`revise!` 之后（都在锁外，与③同款）、后台「重生成」。

### 4.6 预算 `Reasons::Budget`

`month_cost` = 本月（上海时区自然月）`model_calls.sum(:cost)`；`exhausted?` = 上限 > 0 且 `month_cost >= 上限`。`today_calls` = 今日条数。设置页显示「本月 N 次 · 费用 X / 上限 Y」「今日 N 次」（数字走 Maple）。

## 5. 告警（复用③）

- 缺理由：`Scheduler#check_reasons_if_due`（每个 tick）：当天已发布超过 30 分钟、供应商已配置、仍有条目 `reason IS NULL` 的日刊 → `Alerts.reasons_missing!(issue, count)`（按期按日去重，③ 已定义 kind）。
- 上限：`Budget.exhausted?` 首次拦下生成时 → 同一 kind，摘要「本月费用已达上限」，范围按期。
- 恢复：整期补齐后 `recover!(kind: "reasons_missing")`。

## 6. 后台

### 6.1 设置页 `/admin/settings` 新增两节

「兴趣画像」：表格（名称 / 关键词 / 排序 / 启用），每行可改（`PATCH /admin/interest_areas/:id`）、可删（`DELETE`，有条目用着该标签也允许删，标签是文本快照）、末尾一行新增（`POST /admin/interest_areas`）；校验：名称必填 ≤ 20 字、唯一（「名称已存在」）、关键词 ≤ 200 字。

「推荐理由」：表单（接口地址、模型名、输入单价、输出单价、月费用上限；`PATCH /admin/settings` 的 `model` 组）+ 只读行「密钥：已配置 / 未配置（MODEL_API_KEY）」+ 用量行「本月 N 次 · 费用 X / 上限 Y」「今日 N 次」+ 一句「未配置模型供应商」当三样缺一。

### 6.2 期页 `/admin/issues`

日刊行加一格「理由」：`已生成 · 缺 N 条 · 未配置`（缺 N 条时反白小签）；操作加「重生成理由」（`POST /admin/issues/:period_key/reasons`，整期覆盖，入队后 flash 「已开始重生成理由」，进行中按③的轮询装置禁用）。

### 6.3 读者页（管理员）

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

- 模型：`InterestArea` 校验与唯一；`Reasons::Parser`（JSON、夹杂文本的 JSON、缺字段）；校验规则（20–60 字、截断、领域名匹配）；`Budget`（月界按上海、上限 0 不拦）；跨天沿用。
- 接入层（WebMock）：请求体形状（messages、response_format、model）、`Authorization` 头、`usage` 入账、429 / 5xx / 超时 / 401 的映射、http 非本地拒绝。
- 生成：一期 3 条全部生成；一条输出缺领域名重试 2 次后留空并记 `invalid`；上限到了不调模型且告警；`only_missing`；`recover!`。
- Job / 钩子：`finalize!` published 入队、`revise!` 入队、后台重生成入队；`limits_concurrency`。
- Scheduler：发布 31 分钟仍缺 → 告警一次；29 分钟不告。
- 控制器：兴趣画像 CRUD + 校验 + 审计；设置页 `model` 组校验（地址 https、单价与上限非负数字）；整期 / 单条重生成（admin、403、未配置时 alert）。
- 前端（Vitest）：设置页两节、期页「理由」格与按钮、读者页管理员控件（普通用户不渲染）。
- 系统测试：配置供应商（WebMock 假端点）→ 期页「重生成理由」→ `perform_enqueued_jobs` → 读者页看到理由与标签。
- 全部不碰网络。

## 10. 文案（附录 B，v0.3.12）

| 位置 | 文案 |
|---|---|
| 推荐理由状态 | 已生成 · 缺 N 条 · 未配置模型供应商 · 本月 N 次 · 费用 X / 上限 Y · 今日 N 次 · 密钥：已配置 · 未配置 |
| 重生成 | 已开始重生成理由 · 已重生成 · 重生成失败：{reason} · 本月费用已达上限，已停止生成 |
| 兴趣画像校验 | 名称已存在 · 最多 20 字 · 最多 200 字 · 必填 |
| 模型配置校验 | 地址必须是 https · 不小于 0 · 必填 |

## 11. 运维

- 环境变量：`MODEL_API_KEY`（`.kamal/secrets`、`deploy.yml`）。
- `docs/development.md` 加「推荐理由」一节：本地用 Ollama（`http://localhost:11434/v1`，密钥随便填）或任一兼容端点；`db:seed` 建初始画像；怎么看账本。
- 内存预算：无新进程。

## 12. 默认决定（代理定，可推翻）

| 编号 | 决定 | 理由 |
|---|---|---|
| C1 | 接入层只做 OpenAI 兼容协议；供应商 = 地址 + 模型名 + 环境里的密钥 | T8「按可切换供应商设计」；不替产品负责人选厂商，主流国内外端点与本地 Ollama 都兼容 |
| C2 | 费用本地按后台填的单价算 | 各家计费接口不同；单价两格就够，且上限比价可控（N-10） |
| C3 | 一期一个 job 顺序生成，单条 20 秒超时，条内重试 2 次 | R-9.6 / R-9.8；30 条串行最坏 20 分钟但正常 1–2 分钟；并发对上游限流不友好 |
| C4 | 校验按字符数 20–60，超长截断、过短判失败 | R-9.3 与 5.9「输出超长截断到 60 字」 |
| C5 | 停用的领域不进提示词，已生成标签不动 | 画像修改只影响之后的生成（5.9 异常） |
| C6 | 单条重生成放在读者页（管理员可见的 link-button） | PRD 要「重生成单条」，后台没有条目列表；读者页本来就按条目排 |
| C7 | 缺理由告警由 tick 检查发布 30 分钟后的当天日刊 | 5.7 的表；不另起 job |
| C8 | 上限为 0 视为不限 | 默认不拦，让首次配置能跑起来 |
| C9 | 理由写入用 `update!`（走校验与 `after_save_commit`） | R-9.7 唯一可补写字段；`Searchable` 的注释本来就把「推荐理由补写」列为单条改动经回调同步索引的情形，索引本身不含 reason，重建一次无害 |
| C10 | 跨天重复直接复制上一期理由 | R-1.11 与 5.9「沿用前一日的理由」 |

## 13. 实现顺序

1. 迁移（`interest_areas`、`model_calls`）+ 模型 + seeds + `Setting` 新键 + `Reasons::Budget`
2. `Reasons::Provider`（接入层）+ `Reasons::Parser` + 校验
3. `Reasons::Generator` + `GenerateReasonsJob` + 钩子（`finalize!`、`revise!`）+ Scheduler 检查 + 告警
4. 后台：兴趣画像 CRUD、设置页 `model` 组与用量、期页「理由」格与整期重生成、读者页单条重生成
5. 前端页面（Vitest）
6. 文档、附录 B、部署变量、系统测试、`bin/ci`
