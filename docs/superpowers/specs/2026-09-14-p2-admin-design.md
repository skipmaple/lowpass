# P2-② 管理后台 设计文档

| 状态 | 日期 | 依据 |
|---|---|---|
| 产品负责人已批准 P2 的拆分与顺序（2026-09-13）；本子项目按「实现 P2」的目标由代理按 PRD 与画布设计，需要拍板的地方记在第 15 节默认决定，可推翻 | 2026-09-14 | PRD v0.3.9 第 5.3 节（F-09 到 F-12、R-3.1 到 R-3.11、AC-3.1 到 AC-3.6）、5.6 管理后台、5.1 R-1.5 / R-1.6 / R-1.7、5.2 R-2.8、7.6、7.7 回填、7.8 保留、附录 A（AuditLog）、附录 B；ADR T2 / T12；AGENTS.md 不变量；画布 `docs/design/src/pages_site.py` 的 `admin_nav`、`admin_sources`、`admin_source_form`、`admin_source_forms`、`admin_runs`、`admin_issues`、`admin_users`、`admin_settings`、`dialog`、`toast`、`admin_dialogs`；子项目 ① 的 `Admin::BaseController` 与 `Audit`-less 现状 |

需求以 PRD 5.3 与 5.6 为准，本文只写实现设计。前置：子项目 ①（分支 `p2-login`，PR #15）——登录墙、`Admin::BaseController`、`Current`、头像菜单。本子项目在它之上（分支 `p2-admin`）。

## 1. 范围

做：`/admin` 四个分页（信息源、期、用户、设置）与后台索引条；源的新建 / 编辑 / 启停 / 排序 / 测试抓取（R-3.1 到 R-3.8）；每源抓取记录页与手动重抓（R-3.9、R-3.10）；期列表、对某期某源重抓、补生成缺期（含 7.7 的回填：HN 经 Algolia、RSS 按 feed 窗口、GitHub 标「该来源无法回填」）、立即生成今日日刊（R-3.11）；用户只读列表；设置页的调度时间与白名单只读；写操作的审计日志（附录 A 的 AuditLog，保留 90 天）；报头「管理」改指 `/admin/sources`。

不做：告警渠道与「发送测试告警」（③）、兴趣画像与模型供应商（④）、审计日志的查看界面（PRD 5.6 列为 P2 优先级）、删除源（R-3.7）、用户订阅（F-13）、条目下架界面（F-29，P1）、feed 自动发现（PRD 5.3 异常）、周刊按期号补抓历史期（只支持对已有周刊期的某源整节重抓，R-2.8）。

## 2. 决策

- 后台页面也是 Inertia 页，控制器是 CRUD 资源（AGENTS.md）；全部继承 `Admin::BaseController`。
- 测试抓取是一个 JSON 端点（`POST /admin/sources/test_fetch`），页面用 `fetch` 调它、在客户端画预览：Inertia 对 POST 的回应要么是重定向要么是整页，都不适合「表单不离开、下面多出一块预览」；30 秒超时在请求内同步等（`Adapters::Base::TEST_TIMEOUT`），单管理员用，不值得为它起 job 与轮询。
- 手动重抓走已有的 `FetchSourceJob`（`trigger: "manual"`），异步；页面靠 flash 提示「正在重抓 …」，并在有进行中的手动任务时每 5 秒 `router.reload` 一次，抓取结束后由页面据 props 里刚结束的任务弹「已更新 …」或「重抓失败 …」。同一期同一源同时只允许一个任务由 `FetchSourceJob` 的 `limits_concurrency` 保证，控制器再查一次 queued / running 的记录避免重复入队（R-3.10）。
- 补生成（R-1.6）的回填能力在适配器里：`Adapters::Base#backfill(date)` 默认抛 `Adapters::NoBackfill`；Hacker News 用 Algolia 按日期查 `front_page`；RSS 按 feed 里落在该日的条目；GitHub Trending 不实现，该栏固化为 `no_backfill` 并在读者页显示「该来源无法回填」。补生成的期标 `generated_late`（它确实晚于该日生成）。
- 表单校验在模型层（`Source::Config` 按适配器的模式），错误信息中文、由控制器经 Inertia 的 `errors` 回到表单；名称唯一与 RSS feed 地址在同刊物内唯一都落到数据库唯一索引，模型校验只是先一步给出可读提示。
- 审计日志是一张表加一个 `Audit.record!`，在控制器写操作成功后调用；没有界面。

## 3. 数据模型

### 3.1 `audit_logs`（附录 A 的 AuditLog）

| 列 | 类型 | 说明 |
|---|---|---|
| `user_id` | string 25, 可空, FK `on_delete: :nullify` | 操作者；用户注销（P1）后记录留着、操作者置空 |
| `action` | string 50, not null | `source.create`、`source.update`、`source.enable`、`source.disable`、`issue.refetch`、`issue.backfill`、`issue.generate_today`、`settings.update` |
| `target` | string 100, not null | `Source#<id>`、`Issue#2026-09-08`、`Setting#daily_time` |
| `payload` | jsonb, default {} | 变更内容：源的 `saved_changes`（去掉 `updated_at`）、重抓的 `source_id` / `source_name`、设置的旧值新值 |
| `created_at` | datetime | 索引 |

`AuditLog.cleanup`（90 天，7.8）挂进 `Scheduler#cleanup_if_due`。`Audit.record!(action, target, payload = {})` 读 `Current.user`。

### 3.2 `sources`

不加列。加唯一索引（R-3.8）：`CREATE UNIQUE INDEX index_sources_on_publication_and_feed_url ON sources (publication, (config->>'feed_url')) WHERE adapter = 'rss'`。`name` 已唯一。

### 3.3 `issues.source_states`

值域加 `no_backfill`（补生成时不支持回填的源）。`Issue::Daily#source_state` 在 `generating?` 时先看 `source_states` 里已固化的值，再按最近一次抓取推导；`finalize!` 照旧把 `source_state` 的结果写进去，`no_backfill` 因此保得住。发布判定不变：有 `ok` 或 `empty` 才 published。

### 3.4 `fetch_runs`

不加列。测试抓取只在源已保存时记一条 `trigger: "test"`、`issue: nil` 的记录（R-3.9 的触发方式含「测试」）；未保存的源没有记录可挂。

## 4. 源配置 `Source::Config`

每个适配器一份模式（`app/models/source/config.rb`）：字段、类型、范围、默认值、是否必填；`Source::Config.for(adapter)`。`Source` 加 `validate :config_conforms`，把参数归一（整数转型、去空白、语言列表拆逗号）后再校验，错误写到 `errors[:config]` 之下按字段名（`errors.add(:"config.count", "1 到 100")`），页面据字段名放到对应输入框下。

| 适配器 | 刊物 | 字段（默认） | 校验 |
|---|---|---|---|
| `hacker_news` | 只能日刊 | `list`（top）、`count`（10）、`min_score`（0） | `list` ∈ top / best；`count` 1 到 100；`min_score` ≥ 0 |
| `github_trending` | 只能日刊 | `languages`（[]）、`count`（10；有语言时默认 5） | 最多 3 个；每个匹配 `\A[A-Za-z0-9+#.\- ]{1,40}\z`；`count` 1 到 25 |
| `rss` | 日刊或周刊 | `feed_url`（必填）、`count`（10）、`window_hours`（24，只有日刊有） | `feed_url` 是 http(s) 且有主机；`count` 1 到 50；`window_hours` 1 到 72 |
| `ruanyf_weekly` | 只能周刊 | `min_items`（5） | ≥ 1 |

`publication` 与适配器不符（HN 配成周刊）→ `errors[:publication]`「这个适配器只能是日刊」。名称：`presence`、`length ≤ 100`、`uniqueness`（message「名称已存在」，AC-3.6）。RSS feed 地址同刊物内唯一（message「这个 feed 地址已经在同一刊物里」）。`sort_order`：整数 ≥ 0。

编辑不能改适配器（模式不同，历史条目的 meta 形状也不同）；表单在编辑态把适配器画成文字。

## 5. 测试抓取 `Source::TestFetch`

`Source::TestFetch.call(attrs)`（`attrs` = 表单当前的 `adapter`、`publication`、`name`、`config`）：

1. 用 `Source.new(attrs)` 建一个不保存的源，校验 `config`（校验不过直接返回错误，不发请求）。
2. `adapter_class.new(source).test_fetch`（`Adapters::Base#test_fetch`：30 秒超时，前 5 条）。RSS 适配器另外暴露 `feed_title`（解析一次 feed 后记住），给「名称默认取 feed 标题」用。
3. 结果 `Result = Data.define(:ok, :entries, :warnings, :parsed, :dropped, :duration_ms, :feed_title, :error)`：
   - `entries`：前 5 条的 `title`、`url`、`summary`（前 120 字）、`author`、`published_label`（`MM-DD HH:MM`）、`meta`（分数 / 评论 / 语言 / star）。
   - `parsed` = 适配器返回的条数：`Adapters::Base#test_fetch` 改成在 30 秒超时内返回全部 `Entry`（不再截前 5），`TestFetch` 自己截前 5 条做预览、数总数。
   - `dropped` = `valid?` 为假的条数；`warnings` = `["N 条缺标题或链接，已丢弃"]`（N > 0 时）、`["N 条无发布时间，已用抓取时间代替"]`（RSS `meta.time_from_fetch` 的条数）。
   - 错误映射（可读，P2 退出条件）：`Adapters::Rss::ParseError` → 「不是有效的 RSS/Atom，请检查地址。」；`Timeout::Error` → 「连接超时（30 秒），请检查地址或稍后重试。」；`Adapters::Http::Blocked` → 「源站拒绝了请求（429 / 403）。」；`Adapters::Http::Unresolvable` → 「地址解析不到公网 IP。」；`Adapters::Http::TooLarge` → 「响应超过 2 MB。」；其他 `Adapters::Http::Error` / `Adapters::GithubTrending::ParseError` / `Adapters::RuanyfWeekly::Degraded` → 「抓取失败：{首行，不超过 120 字}」。
4. 源已保存时（`attrs[:id]` 有值）记一条 `FetchRun(trigger: "test", issue: nil, status: ok ? "succeeded" : "failed" / "timed_out", item_count: parsed, dropped_count: dropped, duration_ms:, error_summary:)`。

端点 `POST /admin/sources/test_fetch`（JSON，`Admin::SourcesController#test_fetch`）：入参同表单；回 `{ ok, entries, warnings, parsed, dropped, duration_ms, feed_title, error }`，HTTP 200（失败也是 200，`ok: false`；只有 admin 之外的人才 403）。`rate_limit to: 10, within: 1.minute, by: -> { Current.user.id }`（每次最长 30 秒，防手抖连点）。

## 6. 抓取记录与手动重抓

### 6.1 记录页 `/admin/sources/:source_id/runs`

最近 50 次（R-3.9），`?status=` 筛选：`all`（默认）、`succeeded`、`failed`（含 `timed_out`）。列：开始时间（`M月D日 HH:MM:SS`）、耗时（秒，一位小数）、状态（记号 + 成功 / 失败 / 超时 / 排队 / 运行中）、尝试（`n / 3`）、条目、丢弃、错误摘要、触发（调度 / 手动 / 测试）。表下方「最近 50 次 · 保留 30 天 · N 条」。

期头：源名（`PageHead big`）、适配器（`top`）、「抓取记录」（`bottom`）；右端「返回列表」描边 +「重抓 {最新一期}」反白（日刊源指最新一期日刊，周刊源指最新一期周刊；没有期时不画）。

### 6.2 重抓（R-3.10、R-1.5、R-2.8）

`POST /admin/issues/:period_key/refetch`，参数 `source_id`。控制器：

1. 找期（按 `period_key` 形状判断日刊 / 周刊）与源；源必须属于该期的 `source_states` 或（生成中时）启用的同刊物源，否则 404。
2. 已有 `queued` / `running` 的 `FetchRun(issue:, source:)` → 只 flash「正在重抓 {source}…」，不再入队。
3. 否则 `source.refetch_later(issue)`（先写下 `queued` 记录再入队，页面一落地就能轮询），`Audit.record!("issue.refetch", "Issue#…", { source_id:, source_name: })`，flash「正在重抓 {source}…」，重定向回来路（`redirect_back_or_to admin_issues_path`）。

`FetchSourceJob#perform`：日刊期照旧 `source.fetch_now`；周刊期改调 `Issue::Weekly.refetch!(issue, source)`（新）：阮一峰按该期里这个源已有的期号逐一 `adapter.fetch_issue(number)` 后 `write_section!(source, entries, issue_no: number)` 整节替换；RSS 周刊源 `adapter.fetch(period_key:)` 后 `write_section!(source, entries, append: false)`；`Degraded` 与其他错误记 `failed`、原内容保留。

`Source#fetch_now` 在 `trigger == "manual"` 且期已定稿时成功后调 `issue.revise!(self, run)`（R-1.5 的 `revised_at`）；`Issue.regenerate_source!` 退化为「同步版」，只剩测试用。

`FetchRun` 加 `scope :manual_recent`（`trigger: "manual"`，且「还在 queued / running」**或**「`updated_at` 在 60 秒内」——抓取本身就允许 60 秒，进行中的不设时间窗），期页与记录页把它们放进 props（`active_runs`：queued / running；`finished_runs`：其余，但同一源同一期还有重试在排队时先不算结束）供轮询与提示。

### 6.3 进度与反馈

页面（期列表、记录页）props 带 `active_runs: [{ id, source_name, period_key }]`；有内容时 `usePolling` 每 5 秒 `router.reload({ only: ["rows", "active_runs", "finished_runs"] })`，并把对应行的重抓按钮画成禁用态「进行中」（R-3.10）。`finished_runs: [{ id, source_name, status, item_count, error_summary }]` 里页面没见过的 id 弹一次 `Toast`：成功「已更新 {source}（{n} 条）」、失败「重抓失败：{reason}。已保留原内容。」（附录 B）。

## 7. 期管理 `/admin/issues`

### 7.1 列表

`?kind=`（`all` 默认 / `daily` / `weekly`）、`?month=YYYY-MM`（默认当月，前后月导航同日刊归档的 `month_nav`）。行：

- 日刊：该月从最早一期（或月初）到今天的每一天，缺期也占一行（同 `daily_archive_props` 的 `archive_days`）。
- 周刊：与该月有重叠的每一周（周一或周日落在该月），有期才列（R-2.7 没期不建），没期的周不列。

列：刊物（描边小签）、周期键（Maple）、状态（记号 + 「已发布」/「已发布 · 延迟」/「已发布 · 已修订」/「空刊」/「生成中」/「缺期」）、生成时间（`HH:MM`；修订过的 `HH:MM / HH:MM`；周刊 `M月D日 HH:MM`）、各源结果（「HN 10 · GH 失败 · HAD 8」，同归档的 `mark`，`no_backfill` 写「无法回填」）、操作。

操作：缺期 → 「补生成」反白小按钮（32px）；有期 → 「重抓某源」（打开对话框选源：源列表用 `SegButtons`，确认后 POST refetch）、「查看」（链到读者页）；生成中 → 只有「查看」。表上方右侧「M 月 · N 期 · N 空刊 · N 缺期」。

期头右端「立即生成今日日刊」反白按钮（R-3.11）。

### 7.2 补生成 `POST /admin/issues/:period_key/backfill`（日刊）

- 今天：等同「立即生成」的无期分支。
- 过去的日子：`Issue.backfill_daily!(period_key)`：建期（`state: generating`、`generated_late: true`），对每个启用的日刊源：适配器支持回填 → `fetch_later(issue, trigger: "manual", backfill: true)`；不支持 → `source_states[source.id] = "no_backfill"`（不建抓取记录）。然后 `finalize_if_done!`（全都不支持时立刻收尾成 empty）。
- 未来的日子或已有期 → 422 回来路 + flash alert「这一天已有期」/「还没到这一天」。

`Source#fetch_now(issue, trigger:, attempt:, backfill: false)`：`backfill` 为真时调 `adapter.backfill(PeriodKey.date_of(issue.period_key))` 代替 `fetch`；`Adapters::NoBackfill` → 记录 `failed`、`error_summary: "该来源无法回填"`（防御，正常不会走到）。`FetchSourceJob.perform(source, issue, trigger, backfill = false)`。

适配器：

- `Adapters::HackerNews#backfill(date)`：Algolia `GET https://hn.algolia.com/api/v1/search?tags=front_page&numericFilters=created_at_i>=A,created_at_i<B&hitsPerPage=<count>`（A / B 是该上海日的 UTC 秒），按 `points` 降序取 `count` 条、跳过 `points < min_score`；条目字段与 `build` 相同（`objectID`、`title`、`url`、`author`、`points`、`num_comments`、`created_at_i`）。走 `Http.get`（surfguard 解析）。
- `Adapters::Rss#backfill(date)`：解析 feed，取发布日（上海）等于 `date` 的条目，按发布时间倒序取 `count` 条；feed 里没有就是 0 条（成功、空栏「今日无新内容」——7.7「有限」）。
- `Adapters::GithubTrending`、`Adapters::RuanyfWeekly`：不实现（基类抛 `NoBackfill`）。`Adapters::Base.backfill?` 类方法给 `Issue.backfill_daily!` 判断。

读者页：`SourceSummary.state` 加 `no_backfill`；索引条小字「无法回填」；栏内 `SourceState` 一句「该来源无法回填」（附录 B）；归档 `mark` 写「无法回填」。

### 7.3 立即生成今日日刊 `POST /admin/issues/generate_today`（R-3.11）

- 今天无期 → `Issue.generate_daily!(PeriodKey.today, late: <now > daily_time>, trigger: "manual")`，flash「已开始生成今日日刊」。
- 已有期且没带 `confirm=1` → 页面先弹对话框「今日日刊已存在。要对所有来源重抓吗？」（附录 B），确认后带 `confirm=1` 再 POST：对该期 `source_states` 里的每个源（跳过已在 queued / running 的）`fetch_later(issue, trigger: "manual")`，flash「正在重抓 N 个来源…」。
- 审计 `issue.generate_today`。

## 8. 用户 `/admin/users`

`User.includes(:auth_identities).order(last_login_at: :desc, created_at: :desc)`。列：显示名（Newsreader 15 500，`Mixed font="latin"`）、邮箱（Maple 13；无 → 文楷「无」）、角色（反白小签「管理员」/ 描边小签「成员」）、登录方式（「Google · GitHub」，Newsreader）、最近登录（`YYYY-MM-DD HH:MM`）。表下「N 个用户 · 只读」。没有写操作。

## 9. 设置 `/admin/settings`

分节（画布 `sec()`：文楷 22 标题、1px 线）：

- **调度**：`日刊生成时间`、`周刊检查时间` 两个 `field`（Maple 值，`HH:MM`，说明「Asia/Shanghai，精确到分」）+ 「保存」反白。`PATCH /admin/settings`，`Setting.set` 两个键，校验 `\A([01]\d|2[0-3]):[0-5]\d\z`（错误「格式是 HH:MM」），审计 `settings.update`（payload 旧值新值）。保存后 flash「已保存」。
- **管理员白名单（只读）**：`Identity::Whitelist.emails` 每行 Maple 13；下面文楷 13 次墨「白名单由环境配置，改动在下次登录生效。」；为空时「未配置」。
- ③ 加「告警」，④ 加「兴趣画像」「推荐理由」——各自的子项目往这一页加节。

## 10. 审计日志

`app/models/audit_log.rb` + `app/models/audit.rb`（`Audit.record!(action, target, payload = {})`：`AuditLog.create!(user: Current.user, action:, target:, payload:)`；`Current.user` 为空（console）时 `user: nil`）。控制器在事务成功后调；审计写失败不影响主操作（`rescue => e; Rails.error.report(e, handled: true)`）。

## 11. 路由与控制器

```
namespace :admin do
  root to: redirect("/admin/sources")
  resources :sources, except: :destroy do
    member { post :toggle }
    collection { post :test_fetch }
    resources :runs, only: :index                  # /admin/sources/:source_id/runs
  end
  resources :issues, only: :index, param: :period_key do
    member { post :refetch; post :backfill }
    collection { post :generate_today }
  end
  resources :users, only: :index
  resource :settings, only: [ :show, :update ]
end
```

放在子项目 ① 的 `mount MissionControl::Jobs::Engine, at: "/admin/jobs"` 之前、`match "admin(/*path)"` 兜底之前。`period_key` 用路由约束 `/\d{4}-\d{2}-\d{2}|\d{4}-W\d{2}/`。

控制器都继承 `Admin::BaseController`；每个动作渲染一个 Inertia 页或重定向；写动作成功后 `Audit.record!`。`Admin::SourcesController#test_fetch` 是唯一的 JSON 动作。

`Admin::BaseController` 加 `inertia_share admin_nav: [...]`？不加——索引条是静态四项，页面组件自己画，只传 `active`。

## 12. 页面与组件（按画布）

通用：后台页套 `Layout`，但不要页脚（画布后台页没有 `footer_site`）：`Layout` 的 `footer` 支持 `false`。期头用 `PageHead`：`big`「管理后台」、`top` Maple「admin」、`bottom` 分页名、`controls` 右端按钮。索引条 `AdminNav`（四项，56px，当前项反白，`aria-current`）。表格 `Table`（`.table`：表头文楷 12 次墨 + 1px 墨线，行间 35% 线；外层 `overflow-x: auto`，手机横向滚）。`Dialog`（40% 墨色遮罩、480px 纸卡、1px 墨线 + 2px 顶线、文楷 20 问句、右下「取消」描边 + 确认反白；`role="dialog"`、`aria-modal`、Escape 关闭、焦点进确认按钮）。`Toast`（页面顶部一行 44px、1px 墨线纸底、图标 + 文楷 15 + 关闭叉；`notice` 4 秒收起，`alert` 与失败不收起；`role="status"`）。`Field`（标签文楷 13、40px 描边框、Maple 值、说明与错误文楷 13 次墨，错误带警示图标）。`SegButtons`（表单里的选择：并排描边块，当前项反白，`aria-pressed`；与 `Seg` 的区别是它不是链接）。

- **信息源列表** `Admin/Sources/Index`：表列同 6.1 画布（排序 Maple、名称 Newsreader 500、适配器 Newsreader、刊物描边小签、状态文楷、健康度记号 + 文楷、上次抓取 Mixed 13、下次计划 Mixed 13、操作三个文楷 13 链接：编辑 / 测试抓取 / 停用或启用）；表下「N 个来源 · N 个日刊 · N 个周刊」；期头右端「新建来源」反白（加号图标）。停用走对话框；「测试抓取」调 JSON 端点，只弹 Toast（「解析 N 条 · 丢弃 N 条 · 用时 N 秒」或错误句）。
- **新建 / 编辑** `Admin/Sources/Form`：适配器 `SegButtons`（新建）/ 文字（编辑）；按第 4 节的字段画 `Field`；刊物 `SegButtons`（只有 RSS 可选）；按钮行「测试抓取」描边 +「保存」反白 + 测试失败时的文楷 13「尚未通过测试，仍可保存。」；预览块见第 5 节（标题行「测试抓取 · 前 5 条」+ Maple「用时 · 解析 · 丢弃」，每行 Maple 序号 + Newsreader 标题 + Maple 元数据；警告行警示图标 + 文楷 13）。`useForm`（Inertia）提交，错误按字段显示。期头右端「返回列表」描边。
- **抓取记录** `Admin/Sources/Runs`：第 6.1 节。
- **期** `Admin/Issues/Index`：第 7.1 节；对话框两种（选源重抓、立即生成确认）。
- **用户** `Admin/Users/Index`：第 8 节。
- **设置** `Admin/Settings/Show`：第 9 节。
- **报头**：「管理」菜单项改成 Inertia `Link` 指向 `/admin/sources`。

新增前端类型（`types/lowpass.ts`）：`AdminSourceRow`、`AdminSourceForm`、`TestFetchResult`、`AdminRunRow`、`AdminIssueRow`、`AdminUserRow`、`AdminSettings`、`ManualRun`。路径（`lib/paths.ts`）：`ADMIN_SOURCES`、`adminSourceEditHref`、`adminSourceRunsHref`、`ADMIN_ISSUES`、`ADMIN_USERS`、`ADMIN_SETTINGS`、`ADMIN_TEST_FETCH`、`adminIssueRefetchHref`、`adminIssueBackfillHref`、`ADMIN_GENERATE_TODAY`。

## 13. 测试

- 模型：`Source::Config` 每个适配器的合法 / 越界 / 缺失；名称与 feed 地址唯一（含数据库索引兜底）；`Source::TestFetch` 用 `test/fixtures/files` 的样本（WebMock）覆盖成功、非 feed、超时、429、解析警告；`Issue::Weekly.refetch!` 两种源；`Issue.backfill_daily!`（HN Algolia 样本 JSON、RSS 按日、GitHub `no_backfill`、全不支持时收尾 empty）；`Source#fetch_now` 手动重抓后 `revised_at`；`AuditLog.cleanup`；`Scheduler` 清理加一项。
- 控制器（admin 与 member 各一遍：member 全部 403）：源列表 props、新建成功 / 校验失败（errors 形状）、编辑、启停 + 审计、测试抓取 JSON（成功与错误句）、记录页筛选、重抓（入队、重复入队只 flash、审计）、补生成（过去 / 今天 / 未来 / 已有期）、立即生成（无期 / 有期需确认）、用户列表、设置更新（校验、审计）。
- 前端（Vitest）：`AdminNav`、`Table`、`Dialog`（Escape、焦点）、`Toast`（自动收起用假计时器）、`Field`（错误行）、`SegButtons`；六个页面各一份 props 工厂。
- 系统测试：新建一个 RSS 源（WebMock 给样本 feed）→ 测试抓取看到 5 条 → 保存 → 列表出现 → 停用（对话框）→ 记录页；期页对某源重抓（`perform_enqueued_jobs`）→ 行变「已修订」。
- `bin/ci` 全绿。

## 14. 迁移与运维

- 两个迁移：`audit_logs`；`sources` 的 RSS feed 唯一索引（先检查现有数据没有重复——预置只有一个 RSS 源）。
- `db/seeds.rb` 不变。
- 部署后第一次进 `/admin/sources` 对四个预置源各点一次「测试抓取」（上线清单 10.3）。
- HN 回填多一个出站域名 `hn.algolia.com`（surfguard 解析）。

## 15. 默认决定（代理定，可推翻）

| 编号 | 决定 | 理由 |
|---|---|---|
| A1 | 测试抓取是 JSON 端点，在请求内同步等 30 秒 | 单管理员、一次一个；起 job 与轮询是为了一个人省 30 秒 |
| A2 | 手动重抓异步 + 5 秒轮询 + 结束后客户端弹提示 | R-3.10 要「进行中显示进度并禁用重复点击」；同步等 60 秒 × 3 次会占死请求 |
| A3 | 列表里的「测试抓取」只弹 Toast，不画预览 | 预览是表单页的事；列表只回答「还能不能抓」 |
| A4 | 补生成实现三种回填：HN Algolia、RSS 按日、GitHub 标无法回填；阮一峰周刊不进日刊 | 7.7 的表；Algolia 是 PRD 点名的方式 |
| A5 | 补生成的期标 `generated_late` | 它确实晚于该日生成；期头「延迟生成于 hh:mm」是事实句 |
| A6 | 周刊重抓只对已有期的某源整节替换，不按期号补抓历史期 | R-2.8 的范围；期号补抓是 P0 搁置项，留给以后 |
| A7 | 后台新增的反馈文案：「已保存 {name}」「已停用 {name}」「已启用 {name}」「已开始生成今日日刊」「正在重抓 N 个来源…」「已补生成 {date}，正在抓取」「解析 N 条 · 丢弃 N 条 · 用时 N 秒」「格式是 HH:MM」「这个适配器只能是日刊/周刊」「这个 feed 地址已经在同一刊物里」「源站拒绝了请求（429 / 403）」「地址解析不到公网 IP」「响应超过 2 MB」「抓取失败：{reason}」「这一天已有期」「还没到这一天」 | 附录 B 没有；写进附录 B（v0.3.10），一句事实、不安抚 |
| A8 | 后台页不要页脚 | 画布后台页没有 `footer_site` |
| A9 | 编辑不能改适配器 | 模式与历史条目 meta 形状都不同 |
| A10 | 审计写失败只报告不阻塞 | 审计是记账，不该让管理员操作失败 |
| A11 | 重抓的确认不弹对话框，停用与「立即生成（已有期）」弹 | 附录 B 只给了这两句确认文案 |
| A12 | 「测试抓取」端点每用户每分钟 10 次 | 每次最长 30 秒 |
| A13 | 期页的周刊行按「与该月有重叠」取周，而不是「周一落在该月」 | 跨月的周在两个月的页上都出现（Task 5 裁定） |
| A14 | 手动重抓在入队前先建 queued 记录，页面一落地就能轮询并挡住重复点击；manual_recent 对进行中不设时间窗，重试排队时不提前弹失败（终审裁定） | 记录等 worker 才建，重定向回来的页面读不到它；抓取允许 60 秒，按时间窗筛会把跑得久的漏掉 |

## 16. 实现顺序（供计划拆任务）

1. `audit_logs` 迁移 + `AuditLog` / `Audit` + 清理；`sources` feed 唯一索引；`Source::Config` 校验与中文错误
2. `Source::TestFetch` + 适配器 `feed_title` + 错误映射（模型测试用样本）
3. `no_backfill` 状态、`Adapters::Base#backfill` / `NoBackfill`、HN Algolia 与 RSS 的 `backfill`、`Source#fetch_now(backfill:)`、`Issue.backfill_daily!`、`FetchSourceJob` 参数；读者页的「该来源无法回填」
4. 手动重抓：`fetch_now` 的 `revise!`、`Issue::Weekly.refetch!`、`FetchSourceJob` 周刊分支、`FetchRun.manual_recent`
5. `Admin::` 控制器与路由（sources / runs / issues / users / settings / test_fetch）+ 控制器测试（含 403）
6. 前端通用件：`AdminNav`、`Table`、`Dialog`、`Toast`、`Field`、`SegButtons`、`usePolling`、`Layout` 的 `footer: false`、类型与路径、`lib/admin.ts`（testFetch）
7. 页面：信息源列表 + 表单（含预览）
8. 页面：抓取记录 + 期列表（对话框、轮询、提示）
9. 页面：用户 + 设置；报头「管理」改指向
10. 系统测试、附录 B 文案、`docs/development.md` 后台一节、AGENTS.md 若有出入
