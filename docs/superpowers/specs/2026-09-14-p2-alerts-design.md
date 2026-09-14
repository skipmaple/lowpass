# P2-③ 告警设计

日期：2026-09-14 · 状态：草案（产品负责人设定了「实现 P2」的目标并要求不打断；本文档里需要选择的地方按 §14「默认决定」定，全部可推翻）
依据：PRD `docs/superpowers/specs/2026-09-08-mvp-prd.md` 5.7（F-25、R-7.1 到 R-7.4、AC-7.1、AC-7.2）、5.1 异常（丢弃比例 > 50%）、AC-1.2 / AC-1.4 / AC-3.3 / AC-2.2、5.6 设置页一行、附录 A 的 AlertEvent、10.1 P2 出口「告警去重与恢复通知验证」「渠道配置完成，发送测试告警收到消息」
前置：P2-①（登录）、P2-②（管理后台：设置页与审计日志）

## 1. 范围

做：`alert_events` 表与 `Alerts` 门面（触发、按日去重、恢复）；两个渠道（邮件、IM webhook）各自从环境变量读配置，配一个或两个；投递 job（失败最多重试 3 次，写日志）；六个触发点接进现有代码（源抓取终态失败、解析退化、空刊、日刊延迟生成、搜索不可用、备份失败的调用口）；设置页「告警」一节（渠道状态、「发送测试告警」）；告警事件保留 90 天；读者页面「今日抓取失败，已通知管理员」这句从此为真。

不做：告警列表界面（PRD 没要）；备份任务本身（仓库里没有备份任务，只留 `Alerts.backup_failed!` 的调用口）；推荐理由缺失的触发（④ 接，本项目只定义 `reasons_missing` 这个 kind）；渠道在后台可编辑（R-5.5 同款：由环境配置，后台只读显示）；短信 / Push / 电话。

## 2. 决策

- 渠道是协议不是厂商：邮件走 SMTP（环境变量），webhook 走 HTTPS JSON POST；webhook 的报文形状用 `ALERT_WEBHOOK_FORMAT` 选（`generic` 默认、`feishu`、`wecom`、`dingtalk`），四种都只是三行的报文拼装，没有任何厂商 SDK。
- 去重与恢复以 `alert_events` 为准（附录 A）：同一 kind、同一范围（源 / 期 / 全局）、同一上海自然日只发一条（R-7.1）；有「恢复」语义的 kind 在条件消失时对每条未恢复的事件各发一条「已恢复」。
- 触发点只在事实发生处调用 `Alerts.<kind>!`，门面自己负责去重、建记录、入队投递；调用方永远不会因为告警失败而失败（`Alerts` 内部 rescue 并 `Rails.error.report`）。
- 投递异步（Solid Queue），所以「1 分钟内收到」（AC-7.1）取决于 jobs 进程在跑；设置页把这一点写成事实句。
- 链接的站点地址复用已有的 `BASE_URL`（`Adapters::Http::USER_AGENT` 已经在读它），不再引入新的变量。

## 3. 数据模型

### 3.1 `alert_events`（附录 A 的 AlertEvent）

| 列 | 类型 | 说明 |
|---|---|---|
| id | string(25) | UUIDv7 base36，与全库一致 |
| kind | string(40) | CHECK 在 KINDS 里：`source_failed` `parse_degraded` `issue_empty` `issue_late` `search_unavailable` `backup_failed` `reasons_missing` `test` |
| level | string(10) | CHECK：`warning` `critical` `info` |
| source_id | string(25) null | FK sources，`on_delete: :nullify` |
| issue_id | string(25) null | FK issues，`on_delete: :nullify` |
| summary | string(200) | R-7.2 错误摘要，截 200 |
| url_path | string(200) | 指向后台页面的站内路径（发送时拼 `BASE_URL`） |
| dedup_key | string(120) | 唯一索引；`"#{kind}:#{scope}:#{day}"`，scope 是 source_id / 期 period_key / `-`；`test` 用 `"test:#{id}"`（不去重） |
| delivered | jsonb 默认 `[]` | 已成功投递的 `"渠道:阶段"` 列表（重试时跳过已成功的，不重复发） |
| sent_at | datetime null | 第一次有渠道成功投递的时间 |
| recovered_at | datetime null | 恢复条件出现的时间 |
| recovery_sent_at | datetime null | 「已恢复」第一次投递成功的时间 |
| delivery_error | string(200) null | 最后一次投递失败的原因（重试耗尽后留着） |
| attempts | integer 默认 0 | 投递尝试次数 |
| created_at / updated_at | datetime | |

索引：`dedup_key` 唯一；`(kind, source_id, recovered_at)`（找未恢复事件）；`created_at`（清理）。保留 90 天：`AlertEvent.cleanup` 挂进 `Scheduler#cleanup_if_due`。

### 3.2 不改的表

`sources`、`issues`、`fetch_runs` 不加列。搜索连续失败的计数放 `Rails.cache`（production 是 solid_cache，多进程共享），键 `alerts:search_failures`，成功即清零。

## 4. 触发点

| kind | 级别 | 触发处 | 范围（去重） | 恢复条件 |
|---|---|---|---|---|
| `source_failed` | warning | `FetchSourceJob`：可重试错误的第 3 次失败（`retry_on` 的耗尽回调）、`discard_on` 的 429/403 与解析不到公网 IP、其它非重试异常（`rescue StandardError` 后再抛） | 源 + 日 | 同源下一次 scheduled / manual 抓取成功 |
| `parse_degraded` | warning | `Source::Fetching#fetch_now`：`dropped > kept` 且总数 > 0（PRD 5.1「丢弃比例超过 50%」）；`Issue::Weekly` 的 `RuanyfWeekly::Degraded` 分支（AC-2.2） | 源 + 日 | 同源下一次成功抓取且丢弃比例 ≤ 50% |
| `issue_empty` | critical | `Issue::Finalization#finalize!` 结果为 `empty`（AC-1.4） | 期 + 日 | 之后任一日刊 `finalize!` 为 `published`，或该期经手动重抓 `revise!`（它已把期置回 published） |
| `issue_late` | critical | `Scheduler#generate_daily_if_due`：补跑时 `@now - due_at > 30.minutes`（PRD「06:30 仍无当日期记录」以 06:00 计） | 期 + 日 | 无（一次性事实） |
| `search_unavailable` | critical | `Search::Runner#call` 之后：结果 `timeout` / `error` 连续 3 次（缓存计数） | 全局 + 日 | 下一次搜索成功 |
| `backup_failed` | critical | 只提供 `Alerts.backup_failed!(summary)`，仓库里还没有备份任务 | 全局 + 日 | 无 |
| `reasons_missing` | warning | ④ 调用 | 期 + 日 | ④ 定 |
| `test` | info | 后台「发送测试告警」 | 不去重 | 无 |

`FetchSourceJob` 的 `trigger == "test"` 永远不进这里（测试抓取不走 job）；`Adapters::NoBackfill` 不告警（设计上的「不能」）；`trigger == "manual"` 的失败也告警——管理员虽在看页面，按日去重之后代价只有一条。

## 5. 门面 `Alerts`

```ruby
Alerts.source_failed!(source, issue, summary)       # → AlertEvent 或 nil（当天已发）
Alerts.parse_degraded!(source, issue, summary)
Alerts.issue_empty!(issue)
Alerts.issue_late!(issue, minutes)
Alerts.search_unavailable!(summary)
Alerts.backup_failed!(summary)
Alerts.reasons_missing!(issue, count)
Alerts.test!(user)                                   # 不去重
Alerts.recover!(kind:, source: nil)                  # 关掉未恢复的事件并各发一条「已恢复」
Alerts.search_status(status)                         # 计数、到 3 触发、成功恢复
Alerts.configured?                                   # 任一渠道已配置
```

- `raise!` 的流程：算 `dedup_key` → `AlertEvent.create!`（唯一索引撞了就返回 nil，不是异常）→ `DeliverAlertJob.perform_later(event, "alert")`。整个门面 `rescue StandardError` → `Rails.error.report(handled: true)`，调用方不受影响（告警是记账，不能让抓取或定稿失败）。
- 「恢复」只对 `recovered_at` 为空的事件做；每条各发一条「已恢复」（`DeliverAlertJob.perform_later(event, "recovery")`）。
- `summary` 统一 `to_s.lines.first.to_s.strip[0, 200]`（与 `fetch_now` 记 `error_summary` 一致）。
- `url_path`：源事件 `/admin/sources/:id/runs`；期事件 `/admin/issues?month=YYYY-MM`；搜索 `/search`；备份与测试 `/admin/settings`。

## 6. 内容（R-7.2）

纯文本，一行一项，邮件与 webhook 同一份：

```
[lowpass] 警告 · 源抓取失败
来源：GitHub Trending
期：2026-09-08
摘要：连接超时
https://lowpass.example.com/admin/sources/01j…/runs
```

恢复：

```
[lowpass] 已恢复 · 源抓取失败
来源：GitHub Trending
https://lowpass.example.com/admin/sources/01j…/runs
```

事件名（`Alerts::Message::KIND_LABELS`）：源抓取失败 · 解析退化 · 空刊 · 日刊延迟生成 · 搜索不可用 · 备份失败 · 推荐理由缺失 · 测试告警。级别：警告 · 严重 · 提示。没有的行不画（测试告警没有来源与期）。链接 = `BASE_URL` + `url_path`（production 必填；development 默认 `http://localhost:3000`），`config.action_mailer.default_url_options` 也从它推导。

## 7. 渠道

### 7.1 邮件 `Alerts::Channels::Email`

- 配置：`ALERT_EMAIL_TO`（逗号分隔，可多个）、`ALERT_EMAIL_FROM`（默认 `lowpass@<BASE_URL 的主机名>`）、`SMTP_ADDRESS`、`SMTP_PORT`（默认 587）、`SMTP_USERNAME`、`SMTP_PASSWORD`、`SMTP_DOMAIN`（默认 BASE_URL 主机名）、`SMTP_AUTHENTICATION`（默认 `plain`）、`SMTP_STARTTLS`（默认 `true`）。已配置 = `ALERT_EMAIL_TO` 与 `SMTP_ADDRESS` 都非空。
- `config/environments/production.rb`：`delivery_method :smtp`，`smtp_settings` 全部从 ENV 读，`raise_delivery_errors = true`（不然投递失败静默）。development 与 test 用 `:test`（`bin/rails console` 里看 `ActionMailer::Base.deliveries`）。
- `AlertMailer#event(event, phase)`：主题 `[lowpass] 警告 · 源抓取失败 · GitHub Trending`（恢复：`[lowpass] 已恢复 · …`），正文就是 §6 的文本；`deliver_now`（job 里同步发，重试由 job 管）。

### 7.2 Webhook `Alerts::Channels::Webhook`

- 配置：`ALERT_WEBHOOK_URL`（必须 `https://`）、`ALERT_WEBHOOK_FORMAT`（`generic` 默认）。已配置 = URL 非空且合法。
- 报文：`generic` → `{ "text": <全文>, "title": <首行>, "level": "warning", "kind": "source_failed", "url": <链接> }`（Slack incoming webhook 读 `text`，通用接收端拿全部字段）；`feishu` → `{ "msg_type": "text", "content": { "text": <全文> } }`；`wecom` → `{ "msgtype": "text", "text": { "content": <全文> } }`；`dingtalk` → `{ "msgtype": "text", "text": { "content": <全文> } }`（钉钉的关键词模式下首行含「lowpass」即可通过）。
- 发送：`Net::HTTP`，open / read 各 5 秒，`Content-Type: application/json`，`User-Agent` 复用 `Adapters::Http::USER_AGENT`，不跟重定向，2xx 算成功，其它状态或异常抛 `Alerts::DeliveryError`（含状态码与响应前 200 字）。URL 由运维在环境里配（可信输入），不过 surfguard；但只接受 `https://`，`config/initializers/alerts.rb` 启动时读一次配置、非法就 `warn` 并视为未配置。

### 7.3 投递 `DeliverAlertJob`

- `perform(event, phase)`，`phase` 是 `"alert"` 或 `"recovery"`。对每个已配置渠道：已在 `event.delivered`（按 `"#{channel}:#{phase}"` 记）就跳过；否则发送，成功就追加进 `delivered` 并（首次）写 `sent_at` / `recovery_sent_at`；失败记 `delivery_error`、`attempts += 1`，最后统一抛 `Alerts::DeliveryError` 让 `retry_on` 接手。
- `retry_on Alerts::DeliveryError, wait: [ 30.seconds, 120.seconds ], attempts: 3`；耗尽后回调里 `Rails.logger.error` 一行（R-7.3「发送失败写日志，最多重试 3 次」），事件留在库里带 `delivery_error`。
- 没有任何渠道配置：不入队，事件 `delivery_error = "未配置渠道"`，仍然记录（去重与恢复照常，渠道配好后不会补发历史）。

## 8. 设置页 `/admin/settings`「告警」一节（PRD 5.6 那行的「告警渠道状态」「发送测试告警」）

- props 加 `alerts: { email: { configured: boolean, label: string }, webhook: { configured: boolean, label: string } }`。`label`：邮件已配置时是收件地址脱敏（`d***@example.com`，多个用 ` · ` 连），未配置是「未配置」；webhook 已配置时是主机名加格式（`open.feishu.cn · feishu`），未配置是「未配置」。
- 画法：两行键值（`.kv-row` / `.kv-key` / `.kv-value` 装置）：「邮件」「Webhook」；下面一个 `.btn-primary`「发送测试告警」（POST `/admin/test_alert`），两渠道都未配置时按钮禁用，旁边一句 `field-note`「渠道由环境配置，见 docs/development.md」。
- 结果用 flash：`已发送测试告警`（notice）/ `告警渠道未配置`（alert）。

## 9. 路由与控制器

```ruby
namespace :admin do
  resource :test_alert, only: :create      # POST /admin/test_alert
end
```

`Admin::TestAlertsController#create`：`Alerts.configured?` 为假 → `redirect_to admin_settings_path, alert: "告警渠道未配置"`；否则 `event = Alerts.test!(Current.user)` → `Audit.record("alert.test", "AlertEvent##{event.id}")` → `redirect_to admin_settings_path, notice: "已发送测试告警"`。`rate_limit to: 5, within: 1.minute, by: -> { Current.user.id }`（一次测试一封，别刷）。非 admin 403（`Admin::BaseController`）。

## 10. 现有代码的改动点

- `app/jobs/fetch_source_job.rb`：`retry_on ... do |job, error| Alerts.source_failed!(*job.arguments.first(2), error.message) end`；`discard_on Blocked / Unresolvable do |job, error| ... end`；`perform` 的兜底 `rescue StandardError => e` 先 `Alerts.source_failed!` 再 `raise`（NoBackfill 除外，`Adapters::Http::Error` / `Timeout::Error` 交给 `retry_on`）。`ensure` 里的 `finalize_if_done!` 不变。
- `app/models/source/fetching.rb#fetch_now`：partition 之后 `Alerts.parse_degraded!(self, issue, "丢弃 #{dropped.size} / #{entries.size}")` 当 `dropped.size > kept.size && entries.any?`；成功写完之后 `Alerts.recover!(kind: "source_failed", source: self)`，丢弃比例 ≤ 50% 时再 `Alerts.recover!(kind: "parse_degraded", source: self)`。
- `app/models/issue/weekly.rb`：`Degraded` 分支 `Alerts.parse_degraded!(source, issue, "降级：#{e.message}")`；`ingest` 成功路径与 `refetch_weekly!` 成功路径 `Alerts.recover!(kind: "source_failed", source:)`。
- `app/models/issue/finalization.rb#finalize!`：`update!` 之后 `state == "empty" ? Alerts.issue_empty!(self) : Alerts.recover!(kind: "issue_empty")`。`Issue::Daily#revise!`（它已经把期置回 `published`）之后 `Alerts.recover!(kind: "issue_empty")`。
- `app/models/scheduler.rb#generate_daily_if_due`：`late` 且 `@now - due_at > Alerts::LATE_ALERT_AFTER (30.minutes)` → 生成之后 `Alerts.issue_late!(issue, minutes)`。`cleanup_if_due` 加 `AlertEvent.cleanup`。
- `app/models/search/runner.rb#call`：返回前 `Alerts.search_status(result.status)`（两条路径都调）。
- `config/environments/production.rb`：mailer 段按 §7.1；`config/deploy.yml` `env` 与 `.kamal/secrets` 加 `BASE_URL`（clear）、`ALERT_EMAIL_TO`、`ALERT_EMAIL_FROM`、`ALERT_WEBHOOK_URL`、`ALERT_WEBHOOK_FORMAT`、`SMTP_*`（secret）。
- `Audit` 复用；`Current` 不动。

## 11. 测试

- 模型：`Alerts.source_failed!` 同源同日第二次返回 nil、次日再发；`recover!` 只关未恢复的、各发一条恢复；`dedup_key` 的三种范围；`cleanup` 90 天；`test!` 不去重。
- 渠道（WebMock）：四种 webhook 报文形状各一例；非 2xx 与超时抛 `DeliveryError`；`http://` URL 视为未配置；邮件用 `ActionMailer::Base.deliveries` 断言主题、收件人、正文；`ALERT_EMAIL_TO` 多地址。
- 投递 job：一个渠道失败一个成功 → `delivered` 只记成功的、抛错重试、重试时不重发成功的渠道；三次耗尽 → `delivery_error` 留下、日志一行；未配置渠道不入队。
- 钩子：`FetchSourceJob` 耗尽三次 → 一条 `source_failed`；429 丢弃 → 一条；解析异常 → 一条；成功一次 → `recovered_at` 与恢复投递；`fetch_now` 丢弃 3 / 5 → `parse_degraded`，1 / 5 不告；`finalize!` 空刊 → `issue_empty` critical；`Scheduler.tick` 07:00 补跑 → `issue_late`，06:05 不告；`Search::Runner` 连续三次超时 → 一条，之后一次成功 → 恢复。
- 控制器：`POST /admin/test_alert` 已配置 → 302 + notice + AlertEvent + 入队；未配置 → alert；成员 403；限流。
- 前端（Vitest）：设置页「告警」一节两种状态、按钮禁用态、POST 路径。
- 系统测试：`admin_test.rb` 加一例：配置了 webhook（stub）时点「发送测试告警」看到「已发送测试告警」，`perform_enqueued_jobs` 后 `AlertEvent.last.sent_at` 非空、WebMock 收到一次请求。
- 全部不碰网络（WebMock + `:test` 邮件投递）。

## 12. 文案（进 PRD 附录 B，v0.3.11）

| 位置 | 文案 |
|---|---|
| 告警渠道状态 | 已配置 · 未配置 · 渠道由环境配置，见 docs/development.md |
| 发送测试告警 | 已发送测试告警 · 告警渠道未配置 |
| 告警正文 | [lowpass] {级别} · {事件名} · 来源：{name} · 期：{period_key} · 摘要：{summary} · [lowpass] 已恢复 · {事件名} |
| 事件名 | 源抓取失败 · 解析退化 · 空刊 · 日刊延迟生成 · 搜索不可用 · 备份失败 · 推荐理由缺失 · 测试告警 |
| 级别 | 警告 · 严重 · 提示 |

## 13. 迁移与运维

- 迁移：`create_table :alert_events`（§3.1），全部 `string` 带 `limit` 与 CHECK，唯一索引与两个普通索引，两个 FK `on_delete: :nullify`。
- 内存预算：没有新常驻进程；投递走现有 jobs 进程。
- `docs/development.md` 加「告警」一节：环境变量表、本地怎么看（development 邮件在 `ActionMailer::Base.deliveries`，webhook 可指到一个自己的 https 接收端试）、AC-7.1 的验证步骤；`docs/engineering-conventions.md` 后台任务节加一条；`AGENTS.md` 不变量「某个源失败只告警，不阻塞发布」已经在，不改。
- 部署前（产品负责人）：选一个渠道，把变量放进部署机环境；`kamal deploy` 后到设置页点「发送测试告警」。

## 14. 默认决定（代理定，可推翻）

| 编号 | 决定 | 理由 |
|---|---|---|
| B1 | 渠道配置只在环境变量，后台只读显示 | 与白名单一致（R-5.5）；密钥不进库、不进仓库 |
| B2 | webhook 报文形状用 `ALERT_WEBHOOK_FORMAT` 四选一，默认 `generic`（Slack 兼容） | 不替产品负责人选厂商；四种形状各三行 |
| B3 | 「源抓取失败」= 一次抓取的终态失败（重试耗尽、429/403、解析异常），scheduled 与 manual 都算，test 不算 | PRD 5.7「一次调度内 3 次尝试均失败」的自然推广；按日去重后代价只有一条 |
| B4 | 「日刊未生成」实现为补跑时晚于 30 分钟才告警（06:00 → 06:30） | tick 自己会补跑，短暂重启（`LATE_AFTER` 1 分钟）只标「延迟生成」不告警 |
| B5 | 搜索不可用按连续三次失败的查询计数（缓存），不新建健康检查端点 | N-5 的健康检查端点是独立需求；这样 AC 可测且零新接口 |
| B6 | 备份失败只留调用口 | 仓库里没有备份任务 |
| B7 | 投递用一个 job、按渠道记已送达，重试不重发 | R-7.3 的重试与「一条只发一次」同时成立 |
| B8 | `issue_late`、`backup_failed`、`test` 没有「已恢复」 | 一次性事实，没有恢复语义 |
| B9 | 空刊的恢复 = 之后任一日刊正常发布或该期经重抓有了内容 | PRD 只说「恢复后」；这是最贴近读者体验的条件 |
| B10 | 告警从不让业务路径失败（门面全部 rescue + `Rails.error.report`） | 「某个源失败只告警，不阻塞发布」反过来也成立：告警坏了不能阻塞抓取 |
| B11 | 告警事件保留 90 天，随 04:00 清理 | 与审计日志同档 |
| B12 | 测试告警限流每用户每分钟 5 次 | 一次一封，别刷 |
| B13 | 正文纯文本、邮件与 webhook 同一份 | R-7.2 列的四项加链接就是全部；富文本各家不兼容 |
| B14 | 站点地址复用 `BASE_URL` | `Adapters::Http` 的 User-Agent 已经在读它，一个变量管一件事 |

## 15. 实现顺序（供计划拆任务）

1. 迁移 + `AlertEvent`（KINDS、LEVELS、`dedup_key`、`cleanup`）+ `Alerts` 门面（raise / recover / search_status / configured?）+ Scheduler 清理
2. `Alerts::Message`（文本与主题）+ `Alerts::Channels::Email`（mailer、production SMTP 配置）+ `Alerts::Channels::Webhook`（四种形状）+ `config/initializers/alerts.rb`（读配置、校验）
3. `DeliverAlertJob`（按渠道记送达、重试、耗尽日志）+ 恢复投递
4. 钩子：`FetchSourceJob`、`fetch_now`、`Issue::Weekly`、`finalize!` / `revise!`、`Scheduler`、`Search::Runner`（各带测试）
5. 后台：`POST /admin/test_alert`、设置页 props 与「告警」一节（Vitest）、审计
6. 文档、附录 B、`deploy.yml` / `.kamal/secrets`、系统测试一例、`bin/ci`
