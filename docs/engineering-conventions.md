# 工程约定的来源与取舍（借鉴 basecamp/fizzy）

这是 AGENTS.md 的展开版：每条做法的出处、改造理由与不采用的清单。AGENTS.md 只保留代理每次都要看的默认值；改约定时两边一起改。

lowpass 是个人技术刊物站：每天 06:00（Asia/Shanghai）把 Hacker News、GitHub Trending、Hackaday
装订成一期不可变的日刊，每周把阮一峰科技爱好者周刊收进周刊；信息源可配置，历史内容可搜索，
Google / GitHub 登录，单租户。

这些说明是"带理由的默认值"，不是法律：眼前的代码与之冲突时，走更好的路并指出冲突；
不变量（数据丢失、安全、CI 门禁）要摆到台面上，不能悄悄绕过。提交前先攻击自己的 diff。

> 本文件的多数做法借自 basecamp/fizzy（37signals 的开源 Rails 应用），每条都标了来源与取舍：
> 「采用」直接照做；「改造」按 lowpass 的选型改过。四个原本待定的点已由产品负责人于 2026-09-09 定下（ADR T9 到 T12）。

## 先读什么

- 需求唯一来源：`docs/superpowers/specs/2026-09-08-mvp-prd.md`（编号 F 功能、R 规则、AC 验收、D 决策、N 非功能）。
- 技术决议：`docs/adr/0001-mvp-tech-stack.md`——Rails 8 + Inertia.js + React + shadcn/ui + TypeScript，
  PostgreSQL，Solid Queue / Cache / Cable，Kamal 部署到香港 VPS（2 vCPU 4 GiB）。T8（推荐理由的模型服务）待定。
- 代码风格：`STYLE.md`（37signals 风格：vanilla Rails、CRUD 资源、thin controller + rich model、`_later` / `_now`）。
- 界面：`.claude/skills/lowpass-design-taste/`（设计口味与令牌）、`docs/design/`（画板源码与每轮决定）。

## 部署

默认分支 `main`。Kamal 按 `config/deploy.yml` 部署：起步是 `web` 单容器，Solid Queue 以 Puma 插件跑在里面（ADR T4 的 A），
拆 `job` 角色是配置级变更；PostgreSQL 作为 Kamal accessory；镜像仓库 Docker Hub（T5）；kamal-proxy 做 Let's Encrypt，
与同一台机器上的另一个 Kamal 应用共用，按域名分流。每日 `pg_dump` 推到对象存储（T3）还没做。操作步骤见 `docs/development.md`「部署」。
内存预算写在 ADR 里，新增常驻进程前先改预算。〔改造自 fizzy 的 Kamal 部署与 `docs/kamal-deployment.md`〕

## 改动前先看的不变量

- 期不可变（R-1.4）：发布后条目不再变化，地址永久稳定。例外只有两个：管理员对"某期某源"重抓整栏替换并记 `revised_at`（R-1.5）；
  推荐理由与兴趣标签可在发布后补写（R-9.7）。
- 一日一期、周期键（3.2）：日刊 `YYYY-MM-DD`，周刊 ISO 周 `YYYY-Www`；展示按 Asia/Shanghai，存储 UTC；
  周期键的计算只在一处，且有跨日（23:59 / 00:00）与服务器时区非上海的测试。
- 调度是每分钟一次的 tick（ADR T2），读数据库里的生成时间，到点入队、缺期补跑（R-1.1、R-1.7）；不是静态 cron。
- 某个源失败只告警，不阻塞当期发布（R-1.3）；推荐理由的生成与发布解耦（R-9.1）；周刊条目不生成理由（D19）。
- 条目契约（7.2）：适配器只产出规范化条目，期生成器不知道源的细节。新源 = 新适配器 + 字段映射（7.3），不改生成器。
- 权限：登录后可读（D1）；`/admin` 只给 admin，非 admin 返回 403 而不是跳登录页（AC-3.5）；
  管理员由已验证邮箱白名单推导（R-5.5）。
- 单租户：没有 Account，没有 URL 租户前缀。fizzy 的多租户中间件、`Current.account`、按账户分片都不适用。

## UUID 主键

所有表用 UUIDv7 主键，base36 编码为 25 个字符。Fixture 的 UUID 生成得比任何运行时记录都"老"，
所以测试里 `.first` / `.last` 是确定的——不要通过比较插入顺序与 id 顺序来"修正"排序。〔采用自 fizzy〕

已定（ADR T9）：照搬 fizzy 的做法，主键与外键都是 25 字符的 base36 字符串列（`string, limit: 25`），
不用 PostgreSQL 原生 `uuid` 列型；生成逻辑照 `lib/rails_ext/active_record_uuid_type.rb` 的 `generate`
（`SecureRandom.uuid_v7` → 十六进制 → base36 左补零到 25 位），默认值由模型层在建记录时填入
（照 `config/initializers/uuid_primary_keys.rb`），fixture 用 `ActiveRecord::FixtureSet.identify(label, :uuid)` 的同款生成器。

## 搜索在数据库里

PostgreSQL 内建搜索（ADR T7：`pg_trgm` 做拉丁前缀与拼写容错，`ILIKE` 做中文子串，权重求和放进 SQL 由数据库排序分页，
高亮在应用层（ADR 2026-09-11 补记）），不引入搜索引擎；上线前用 50 条真实查询验证，不达标再谈替换。

结构借 fizzy：`Searchable` concern 用 `after_save_commit`（建与改；同名的 after_create_commit / after_update_commit
会被 Rails 去重成一个；删除由外键级联）维护一张独立的 `Search::Record` 表（标题、板块、来源、摘要各占一列，
权重 标题 > 板块 = 来源 > 摘要，R-4.3），提供 `bin/rails search:rebuild` 与重建 job；下架条目（F-29）从索引删除；
停用源的历史条目保留可搜（R-4.8）。
不要为了搜索改条目表本身。〔改造自 fizzy `app/models/concerns/searchable.rb` 与 `app/models/search/`〕

## 抓取与出站 HTTP

- 适配器放在模型层（`app/models/<source>/…`），输出 7.2 契约的规范化条目；网络 I/O 与解析分开，解析可以拿固定样本单测。
- 每个出站请求都有：超时（单源单次 60 秒，R-1.2）、明确的重试次数与间隔（3 次，30 / 120 秒）、标明 lowpass 的 User-Agent、
  响应体大小上限；收到 429 / 403 按失败处理，不追加重试（5.3 异常）。
- 管理员填的 feed 地址是不可信输入：连接前把主机解析成公网 IP，拒绝回环、内网、链路本地地址，重定向也要再检查。
  直接引入 fizzy 的 `surfguard` gem（ADR T10）：连接前 `Surfguard.resolve_public_ips(host)`，`Surfguard::Unresolvable` 按失败处理。
- 测试不碰网络：HN JSON、Trending HTML、RSS、阮一峰 Markdown 都放 `test/fixtures/files/`，用 WebMock / VCR 拦截；
  阮一峰解析规则用近 20 期样本做回归（R-2.3），规则调整不改写历史已发布内容。〔采用自 fizzy 的 VCR + WebMock 做法〕

## 后台任务

- Solid Queue。Job 类保持"浅"，逻辑放模型；`_later` 入队、`_now` 同步（STYLE.md）。〔采用〕
- 周期任务写在 `config/recurring.yml`：每分钟一次的调度 tick；周刊 09:00 检查（R-2.1）；清理任务作为模型类方法
  `Model.cleanup`，分批 `delete_all`（抓取记录 30 天、搜索日志 30 天、审计日志 90 天、`SolidQueue::Job.clear_finished_in_batches`）。
  〔改造自 fizzy `config/recurring.yml` 与 `Webhook::Delivery.cleanup`〕
- Job 必须幂等：tick 可能重复触发；"某期 + 某源"同时只允许一个重抓任务（R-3.10）。
- 推荐理由生成是独立 job，失败不影响发布；单条重试 2 次，缺失在后台可见（R-9.6）。
- 后台（P2-②）：`Admin::` 控制器是 CRUD 资源（启停是 `enablement`，重抓 / 补生成 / 立即生成各是一个资源，STYLE.md），
  写操作成功后 `Audit.record`；手动重抓复用 `FetchSourceJob`（`trigger: "manual"`），页面轮询 `FetchRun.manual_recent`；
  测试抓取是同步的 JSON 端点（30 秒超时）；源配置的模式与中文校验在 `Source::Config`。〔P2-② 设计文档〕
- 告警（P2-③）：触发点只调 `Alerts.<kind>!`，去重（`alert_events.dedup_key`：kind + 范围 + 上海日）、建记录、`DeliverAlertJob` 入队都在门面里，
  门面从不让业务路径失败；渠道只从环境读（`Alerts::Config`），邮件走 SMTP、webhook 走 HTTPS JSON（四种报文形状）；投递按渠道记已送达，重试不重发。〔P2-③ 设计文档〕
- 推荐理由（P2-④）：`Reasons::Provider` 只做 OpenAI 兼容协议（地址、模型名、单价、上限在 `settings`，密钥只从环境读）；`Reasons::Generator` 一期顺序生成、单条重试 2 次、补缺时跨天沿用；`GenerateReasonsJob` 按期限并发；账本 `model_calls` 90 天；缺理由由 tick 检查后走告警。
  模型端点与 feed 地址不同：它是管理员在后台填的可信地址，只要求 https（本机 http 允许，给本地 Ollama），**不经 surfguard**——这是对上面「出站 HTTP」那条不变量的明示例外，理由是它不是从源站内容里读来的地址，且请求体里带着密钥，不能被重定向到别处。401 / 403 与 429 都不追加重试，本期停止（`Rejected` / `Limited`）；没配供应商或画像为空（`Reasons.ready?`）一律不调模型。〔P2-④ 设计文档〕

## 认证、会话与请求上下文

- 登录方式是 Google / GitHub OAuth（5.5），不是 fizzy 的邮箱验证码 / 通行密钥。〔不采用其登录方式〕
- 形状借 fizzy：`Session` 记录 + 签名 cookie `session_token`；`Current` 保存 session、user 与请求属性（request_id、ip、user_agent）；
  `Authentication` concern 只提供 `allow_unauthenticated_access` 一个类方法（反向那条没有：已登录访问登录页跳首页，
  是 `SessionsController` 自己的 `before_action :redirect_signed_in`）；未登录跳 `/login?next=`，`next` 只接受站内相对路径（R-5.7）。〔改造〕
- 搜索与点击上报用 Rails 8 的 `rate_limit`（每用户每分钟 60 次，R-4.10）；登录回调不是——它在 OmniAuth 之前的 Rack 中间件里（见下条）。〔采用〕
- `Rails.error.set_context(user_id:)` 往错误上下文里加 user id（`Authentication#find_session_by_cookie` 续上会话时调）；`allow_browser versions: :modern`；
  CSP 用 nonce（Inertia 的 script 需要 nonce），来源列表可由环境变量覆盖。〔采用自 fizzy `error_context.rb`、`content_security_policy.rb`〕
- OAuth 客户端用 OmniAuth（`omniauth`、`omniauth-google-oauth2`、`omniauth-github`、`omniauth-rails_csrf_protection`），
  只负责从 provider 拿资料；匹配与合并在 `Identity::Resolution`。回调限流（R-5.9）是 OmniAuth 之前的一层 Rack 中间件
  `Auth::CallbackRateLimit`（`lib/middleware/`，不在自动加载路径里）：换 token 发生在 OmniAuth 的中间件里，控制器上的
  `rate_limit` 拦不住那一步。development 加 `developer` 策略做开发登录。〔P2-① 设计文档〕

## 前端

Inertia + React + TypeScript + shadcn/ui（ADR T1、T6），不是 fizzy 的 Hotwire / importmap。〔不采用其前端〕
仍然适用的：控制器是 CRUD 资源、动作只做一件事并渲染一个 Inertia 页面；props 是前后端唯一契约，必须有类型；
首屏资源不超过 300 KB（N-1）；颜色、字体、字号只从设计 skill 的令牌取。

## 数据库与迁移

- 只支持 PostgreSQL，不写双适配器分支。〔不采用 fizzy 的 SQLite / MySQL 双栈〕
- 借 fizzy 的"列长度显式化"：每个 `string` / `text` 列在迁移里写明 `limit`，值来自 7.2（title 300、url 2048、summary 500、
  section 100、author 100），并加 CHECK 约束；唯一性放数据库（`(source_id, issue_id, url_hash)`、`(type, period_key)`、
  `(provider, provider_uid)`）。〔改造自 `table_definition_column_limits.rb`〕
- 生产不在迁移后 dump schema（`dump_schema_after_migration = false`）；`schema.rb` 随代码提交。

## 测试

- Minitest + fixtures（`fixtures :all`，并行 worker），`bin/rails test` 做快速循环。〔采用〕
- `bin/ci` 是完整门禁，用 `ActiveSupport::ContinuousIntegration` 按步骤跑：setup、agent 说明文件校验、rubocop（rubocop-rails-omakase）、
  bundler-audit、brakeman、前端依赖审计、gitleaks、单元与集成测试、系统测试（`PARALLEL_WORKERS=1`）。全绿才能合并与部署。〔采用〕
- 测试辅助放 `test/test_helpers/`，例如 `sign_in_as`；时间敏感的测试用 `travel_to` 卡在 05:59 / 06:00 / 06:20 边界；不碰网络。
- 前端单元测试（Vitest + Testing Library，jsdom）里，`getByRole` 的 `name` 落在 `Mixed` / `HitText` 拆出的多段 `<span>` 上时
  用容忍空格的正则（`/^近\s*7\s*天$/`），不用字面串：jsdom 算可访问名会吃掉段边界上的空格（「近 7 天」算成「近7天」），
  真浏览器没这回事，不改 `Mixed` / `HitText` / `splitRuns` 迁就它。原因与识别方法见 `app/frontend/lib/typeset.tsx` 顶上的说明。

## 开发环境与脚本

- `bin/setup` 幂等：装依赖、`db:prepare`、库空时 `db:seed`、清日志。`bin/dev` 用 foreman 起 `Procfile.dev`（rails + vite）。〔采用〕
- 工具版本由 mise 管理（ADR T11）：`.mise.toml` 钉 Ruby 与 Node 版本，`bin/setup` 先确保 mise 再 `mise install`。〔采用自 fizzy〕
- `.githooks/pre-commit` 对暂存的 Ruby 文件跑 rubocop（`git config core.hooksPath .githooks`，由 `bin/setup` 设置）。〔采用；fizzy 的 prek 不引入，钩子用普通 shell 脚本〕
- `db/seeds.rb` 只在 development 生效，按主题拆到 `db/seeds/*.rb`；一次性运维脚本放 `script/`（补生成、导入样本），不进 `bin/`。〔采用〕
- `docs/development.md` 写清 setup、测试、邮件预览；`Brewfile` 列系统依赖（libvips 不需要，lowpass 不处理图片）。

## 生产配置

- `config/environments/production.rb` 从环境变量读：`BASE_URL`（推导 `default_url_options`）、`SMTP_*`、`FORCE_SSL` / `ASSUME_SSL`、
  `RAILS_LOG_LEVEL`；日志到 STDOUT，带 `request_id` 标签；`solid_cache_store`；Solid Queue 用独立的 `queue` 数据库配置。〔采用〕
- Dockerfile：`ruby:*-slim` + jemalloc + bootsnap 预编译 + `SECRET_KEY_BASE_DUMMY=1 assets:precompile` + 非 root 用户 + thruster；
  `bin/docker-entrypoint` 在 `web` 启动时跑 `db:prepare`。〔采用〕
- Kamal 别名 `console` / `shell` / `logs` / `dbc`；密钥只经 `.kamal/secrets` 从环境读取，仓库里没有任何密钥。〔采用〕
- 开发环境把队列跑成 `Procfile.dev` 里独立的 `jobs: bin/jobs` 进程，与生产 ADR T4 的独立 `job` 角色同形；
  不再用 `SOLID_QUEUE_IN_PUMA` 把 supervisor 塞进 Puma，两处都开会多出一份 supervisor 与一份周期调度器。
- 队列面板用 `mission_control-jobs`（ADR T12），挂在 `/admin/jobs`，只对 admin 开放，与 5.6 的后台同一套鉴权。〔采用自 fizzy〕

## 代理说明文件本身

- `.claude/CLAUDE.md` 只有一行 `@../AGENTS.md`，Claude Code 由此加载本文件；其他代理直接读 AGENTS.md。〔采用〕
- 本文件里复述的字面值（06:00、每源 10 条、30 天、60 秒）必须与 PRD 或配置一致；
  借 fizzy 的 `script/check_agents_docs` 思路，在 `bin/ci` 里加一步校验（待实现，校验项从 PRD 的 R 规则取）。
- AGENTS.md 保持短，讲"为什么"和"哪里看"；细节归 PRD、ADR、STYLE.md 与设计 skill，不在这里重复。

## 明确不采用

多租户与 URL 账户前缀、SaaS 模式与 `Gemfile.saas` 双清单、MySQL 分片搜索、SQLite / MySQL 双适配器、
账户级导入导出（流式 zip）、Web Push / VAPID、通行密钥、邮箱验证码登录、Action Text / 附件 / 图片处理（D9 不展示图片）。
prek 不引入。

## Coding style

Before editing or reviewing code, read STYLE.md.
