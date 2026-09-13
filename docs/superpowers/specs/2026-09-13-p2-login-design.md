# P2-① 登录与会话 设计文档

| 状态 | 日期 | 依据 |
|---|---|---|
| 产品负责人已批准拆分、选型（OmniAuth、开发登录两者都要、无法合并提示落到设置页）与第 1 到 3 节；第 4 节起按「实现 P2」的目标由代理按 PRD 与画布定，见第 11 节默认决定 | 2026-09-13 | PRD v0.3.8 第 5.5 节（F-19 到 F-21、R-5.1 到 R-5.10、AC-5.1 到 AC-5.7）、5.6 权限、5.8 R-8.2 与 AC-8.3、6.1 权限列、6.2 登录页与设置页、AC-3.5、R-4.10 / R-4.11、D1、D11、附录 A、附录 B；ADR-0001 T12；AGENTS.md 与 `docs/engineering-conventions.md` 的认证一节；画布 `docs/design/src/pages_site.py` 的 `login_card`、`settings`，`pages_front3.py` 的 `menu_sheet`、`error_sheet` |

需求以 PRD 5.5 为准，本文只写实现设计。P2 拆成四个子项目：① 登录与会话（本文）→ ② 管理后台 → ③ 告警 → ④ 推荐理由；后三个各有自己的设计文档。

## 1. 范围

做：Google / GitHub OAuth 登录与登出（F-19）、同一已验证邮箱自动合并（F-20）、白名单推导管理员（F-21）、全站登录墙与 `next` 回跳（D1、R-5.7）、登录页与设置页（6.2）、报头头像菜单（R-8.2）、`/admin` 的 403 骨架并把队列面板挂到 `/admin/jobs`（AC-3.5、ADR T12）、登录回调限流（R-5.9）、搜索限流改按用户（R-4.10）、开发环境的开发登录。

不做：注销账号（F-22，优先级 P1，PRD 4 说明 P1 是 MVP 后第一个迭代；AC-5.x 里没有它）、源订阅（F-13，同上）、`/admin` 下除队列面板以外的页面（子项目 ②）、用户列表（②）、审计日志（②，登录事件不记审计）、告警（③）、500 页（P3 上线清单）。

## 2. 决策

- OAuth 客户端用 OmniAuth：`omniauth`、`omniauth-google-oauth2`、`omniauth-github`、`omniauth-rails_csrf_protection` 四个 gem（产品负责人 2026-09-13 定）。策略名 `google_oauth2`、`github`；development 再挂 `developer`。
- 开发环境两种登录都要：`developer` 策略始终有；真实 provider 的按钮在环境变量齐全时才出现（产品负责人定）。
- 无法合并的提示落到 `/settings` 页顶部，会话照建，`next` 丢掉（产品负责人定）。
- 会话形状借 fizzy / Rails 8 认证生成器：`Session` 记录 + 签名 cookie `session_token`；`Current` 承载 session、user 与请求属性；`Authentication` concern 提供 `allow_unauthenticated_access`。
- 回调限流放在 OmniAuth 之前的一层 Rack 中间件，而不是控制器的 `rate_limit`：OmniAuth 在中间件里就把 code 换成了 token，控制器的限流拦不住那一步。
- 身份匹配与合并规则独立成 PORO `Identity::Resolution`，三种合并情形在模型层测。

## 3. 数据模型

主键照旧：UUIDv7 编成 25 字符 base36 字符串；`string` 列写 `limit` 并加 CHECK。

### 3.1 `users`

| 列 | 类型 | 说明 |
|---|---|---|
| `display_name` | string 100, not null | 每次登录按本次 provider 的资料更新（R-5.2） |
| `email` | string 254, 可空 | 本次登录 provider 给的邮箱，只用于显示；是否已验证看身份表 |
| `avatar_url` | string 2048, 可空 | provider 头像地址，页面热链接；不做图片处理（AGENTS.md） |
| `role` | string 10, not null, 默认 `member` | CHECK ∈ {admin, member}；每次登录按白名单刷新（R-5.5） |
| `last_login_at` | datetime | |

没有唯一约束：邮箱可以重复——未验证的邮箱不参与合并，同一串可能挂在两个用户名下。

### 3.2 `auth_identities`（附录 A 的 AuthIdentity）

| 列 | 类型 | 说明 |
|---|---|---|
| `user_id` | string 25, not null, FK cascade | |
| `provider` | string 20, not null | CHECK ∈ {google, github, developer}；`developer` 只在 development 产生，但约束里必须列上，否则那条路走不通 |
| `provider_uid` | string 255, not null | |
| `email` | string 254, 可空 | |
| `email_verified` | boolean, not null, 默认 false | |
| `linked_at` | datetime, not null | |

唯一索引 `(provider, provider_uid)`；索引 `(email)`（合并匹配用）、`(user_id)`。库里存的 provider 是 `google` / `github`（PRD 用语），策略名 `google_oauth2` 只在 OmniAuth 一侧出现，`Identity::Resolution` 负责映射。

### 3.3 `sessions`

| 列 | 类型 | 说明 |
|---|---|---|
| `user_id` | string 25, not null, FK cascade | 用户删了会话跟着没 |
| `token` | string 24, not null | `has_secure_token`，唯一索引 |
| `last_seen_at` | datetime, not null | |
| `expires_at` | datetime, not null | `created_at + 90 天`，硬上限（D11） |

不存 ip / user_agent：附录 A 没有，设置页也不显示；`Current` 里带着就够。

### 3.4 Fixtures

`users.yml`：`drew`（admin，邮箱 `drew@example.com`）、`guest`（member，邮箱 `guest@example.com`）、`nomail`（member，无邮箱）。`auth_identities.yml`：`drew_google`（google，已验证 `drew@example.com`）、`guest_github`（github，已验证 `guest@example.com`）、`nomail_github`（github，无邮箱）。`sessions.yml`：空（会话在测试里由登录流程建）。测试环境 `ADMIN_EMAILS=drew@example.com`（`test_helper.rb` 里设，不依赖机器环境）。

## 4. 登录流程

### 4.1 路由

| 方法 路径 | 处理 | 登录墙 |
|---|---|---|
| `GET /login` | `sessions#new`，Inertia `Login/Show`；已登录访问跳 `/` | 放行 |
| `POST /auth/:provider` | OmniAuth 请求阶段（中间件），跳去 provider；表单带 `authenticity_token` 与可选 `origin` | 不经路由 |
| `GET /auth/:provider/callback` | OmniAuth 回调阶段（中间件）→ `sessions#create` | 不经路由（中间件之后路由到 create；create 自己放行） |
| `GET /auth/failure` | `sessions#failure`（由 `OmniAuth.config.on_failure` 直接调用动作，不经过重定向） | 放行 |
| `DELETE /session` | `sessions#destroy`，登出 | 需登录 |
| `GET /settings` | `settings#show`，Inertia `Settings/Show` | 需登录 |
| `GET /admin/jobs` 及其下 | `MissionControl::Jobs::Engine`，`base_controller_class = "Admin::BaseController"` | 需 admin |
| `GET /up` | 健康检查 | 放行 |

`config/routes.rb` 里的 `resource :session, only: [:new, :create, :destroy]` 不合适（`new` 的路径是 `/session/new`），改成显式五条：`get "login" => "sessions#new", as: :login`、`get "auth/:provider/callback" => "sessions#create", as: :auth_callback`、`get "auth/failure" => "sessions#failure"`、`delete "session" => "sessions#destroy", as: :session`、`get "settings" => "settings#show", as: :settings`；回调只认 `GET`（POST 由 OmniAuth 中间件的请求阶段接住，不落到这条路由），没有 `match … via: [:get, :post]`。

### 4.2 OmniAuth 配置（`config/initializers/omniauth.rb`）

- `OmniAuth.config.allowed_request_methods = [:post]`（omniauth-rails_csrf_protection 已默认如此），`silence_get_warning = true`。
- `OmniAuth.config.on_failure = ->(env) { SessionsController.action(:failure).call(env) }`，三个环境一样；不设 `failure_raise_out_environments`。
- `Rails.application.config.middleware.use OmniAuth::Builder do ... end`：
  - `provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], scope: "openid email profile", prompt: "select_account"`，两个变量都非空，或 `Rails.env.test?`（test 两家都挂，用占位凭证 `"test"`，让 mock 登录流程走得通）。
  - `provider :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], scope: "user:email"`，条件同上。
  - `provider :developer, fields: [:name, :email], uid_field: :email`，仅 `Rails.env.development?`。
- 已配置的策略名列表存进 `Rails.configuration.x.auth_providers`（本初始化器里设置），登录页 props 与中间件判定共用这一份，不是 `Identity::Providers.enabled`。一个都没有且不是 development 时 `Rails.logger.warn` 一句：登录页照样渲染得出来，只是没有按钮，没人登得进去。
- 中间件顺序：同一个初始化器里 `use OmniAuth::Builder` 之后再 `config.middleware.insert_before OmniAuth::Builder, Auth::CallbackRateLimit`；两者都在会话中间件之后，中间件里能读 `rack.session`。

### 4.3 回调限流中间件 `Auth::CallbackRateLimit`（`lib/middleware/auth/callback_rate_limit.rb`）

- 落在 `lib/middleware/`，不在自动加载路径里（`autoload_lib` 忽略了 `lib/middleware`）：初始化器里 `require "middleware/auth/callback_rate_limit"`。
- 只匹配路径 `%r{\A/auth/[^/]+/callback/?\z}i`（OmniAuth 认回调路径时会先去掉结尾的一个 `/`、再不分大小写比较，这里要认同样宽的一组，少认一种就等于给限流开了后门），其他请求直接透传。
- `Rails.cache.increment("rate-limit:auth-callback:#{remote_ip}", 1, expires_in: 1.minute)`，与 Rails 8 `rate_limit` 同一做法；超过 10 次：`request.flash[:alert] = "操作过于频繁，请稍后再试。"`（附录 B 搜索限流那句复用）、`request.commit_flash`，回 `[302, { "Location" => "/login" }, []]`，不进 OmniAuth。
- `remote_ip` 用 `ActionDispatch::Request#remote_ip`（信任 `config.action_dispatch.trusted_proxies` 的设定，kamal-proxy 在同机）。

### 4.4 `SessionsController`

```
allow_unauthenticated_access only: [:new, :create, :failure]
rate_limit 不在这里（见 4.3）

new      → 已登录 redirect_to root；否则 render Login/Show，props: { providers:, next: safe_next(params[:next]) }
create   → auth = request.env["omniauth.auth"]
           auth.nil? → 这个环境没挂这条策略（比如生产的 /auth/developer/callback），
                       Rails.logger.info 记 params[:provider].inspect（路由通配段、已解码，inspect 一下防换行伪造日志）、
                       redirect_to login_path, alert: "登录失败，请重试。"
           origin = request.env["omniauth.origin"].presence || params[:origin]   # 下面要换会话，先取到手上
           result = Identity::Resolution.call(auth)          # user + outcome
             rescue StandardError → Rails.error.report(e, handled: true) +
                                    redirect_to login_path, alert: "登录失败，请重试。"（不建会话，R-5.8）
           reset_session                                     # 登录这一刻换掉会话 id（会话固定，D11）
           start_session_for(result.user)
           case result.outcome
           when :unmergeable then redirect_to settings_path, alert: 附录 B「这个邮箱无法自动合并…」
           else redirect_to safe_next(origin) || root_path, allow_other_host: false
failure  → type = request.env["omniauth.error.type"]
           notice = type == :access_denied ? "已取消登录。" : "登录失败，请重试。"
           Rails.logger.info 记 type 与 error 类名（不记 token）
           redirect_to login_path, alert: notice
destroy  → Current.session.destroy; cookies.delete(:session_token); redirect_to login_path
```

`create` 的 `next`：真实 provider 的请求阶段把表单里的 `origin` 存进 `rack.session`，回调时经 `env["omniauth.origin"]` 交回；开发登录没有请求阶段、直接 GET 回调，`origin` 从 `params[:origin]` 来——两边都接：`request.env["omniauth.origin"].presence || params[:origin]`。都没有、或是站外地址时 `safe_next` 返回 nil，落到 `root_path`；`redirect_to` 再带 `allow_other_host: false` 兜底——正是 AC-5.7 要的。

### 4.5 `Identity::Resolution`（`app/models/identity/resolution.rb`）

输入 `OmniAuth::AuthHash`，输出 `Result = Data.define(:user, :outcome)`，`outcome ∈ {signed_in, created, linked, unmergeable}`。全部在一个事务里。

资料提取（`Identity::Profile.from(auth)`，`app/models/identity/profile.rb`）：

| 字段 | google_oauth2 | github | developer |
|---|---|---|---|
| provider | `google` | `github` | `developer` |
| uid | `auth.uid` | `auth.uid` | `auth.uid`（= 邮箱） |
| display_name | 三家相同：`info.name` → `info.nickname` → 邮箱 @ 前段 → 「读者」；截到 100 字 | 同左 | 同左 |
| avatar_url | `info.image` | `info.image` | nil |
| email / verified | `info.email`（策略只在已验证时才给值），`info.email_verified` | 只看 `extra.all_emails` 里 `primary && verified` 的那条；没有 → email nil、verified false。`info.email` 与 `raw_info.email` 一概不用（R-5.4） | `info.email`，视为已验证 |

三家的邮箱都经 `Profile.normalize`（`strip.downcase`）处理，再参与比较与入库。长度按 7.2 的列长度在 `Profile` 里就守住：display_name 截到 100；email 超过 254、avatar_url 超过 2048 一律当没有（截断的邮箱不是那个邮箱，合并也用不上，`email_verified` 跟着落空），免得 `Resolution` 的 `update!` 抛异常把登录变成 500。

规则（顺序即优先级）：

1. `AuthIdentity.find_by(provider:, provider_uid:)` 命中 → 更新该身份的 email / email_verified，更新用户 display_name / avatar_url / email → **signed_in**（R-5.2）。
2. 未命中，`verified && email.present?`，且存在 `AuthIdentity.where(email:, email_verified: true)` → 把新身份挂到那条身份的用户 → **linked**（R-5.3）。只跟已验证身份比，不跟 `users.email` 比：不然有人先用未验证的 a@x 建一个账号，真正的 a@x 之后用 Google 登录就被并进去了。
3. 未命中，`verified && email.present?`，没人有 → 新用户 + 新身份 → **created**（R-5.1，普通首次登录，不提示）。
4. 未命中，邮箱未验证或缺失 → 新用户 + 新身份 → **unmergeable**（R-5.3 / AC-5.3，提示）。

每种结果之后：`user.refresh_role!`（任一 `email_verified` 身份的邮箱在白名单 → admin，否则 member；比较前 `downcase.strip`）、`last_login_at = now`、`users.email` 取本次资料的邮箱（可为 nil）。白名单 `Identity::Whitelist.emails` 读 `ENV["ADMIN_EMAILS"]`（逗号分隔，忽略空白与大小写）。

### 4.6 会话

- `Session` 模型：`belongs_to :user`、`has_secure_token :token`（24 位）、`before_create` 设 `last_seen_at = now`、`expires_at = now + 90.days`。
- 有效 = `expires_at > now && last_seen_at > now - 30.days`；`Session.active` scope 就是这两个条件。
- `Authentication#resume_session`：读 `cookies.signed[:session_token]`，`Session.active.find_by(token:)`；找到就 `touch_last_seen!`（`last_seen_at < 1.hour.ago` 时才写库）；找不到当未登录并删掉 cookie。
- `start_session_for(user)`：`user.sessions.create!` 后 `cookies.signed[:session_token] = { value: token, httponly: true, same_site: :lax, secure: Rails.env.production?, expires: session.expires_at }`。
- 登出：删记录、删 cookie。`Session.cleanup`：`where(expires_at: ...now).or(where(last_seen_at: ...30.days.ago)).in_batches.delete_all`，挂进 `Scheduler#cleanup_if_due`。

### 4.7 `Current`

`ActiveSupport::CurrentAttributes`：`attribute :session, :request_id, :ip_address, :user_agent`；`delegate :user, to: :session, allow_nil: true`；`def admin? = user&.admin?`。`ApplicationController` 的 `before_action :set_current_request_details`（在 `require_authentication` 之前）。错误上下文：`resume_session` 找到会话后 `Rails.error.set_context(user_id: Current.user.id)`，`Rails.error.report` 的每条报告都带上它；不另写初始化器。

## 5. 登录墙、权限与 `next`

- `Authentication` concern（`app/controllers/concerns/authentication.rb`）：`included { before_action :require_authentication; helper_method 不需要（Inertia） }`；类方法 `allow_unauthenticated_access(**options)` = `skip_before_action :require_authentication, **options`。
- `require_authentication`：`resume_session || request_authentication`。`request_authentication`：GET/HEAD → `redirect_to login_path(next: request.fullpath)`；其他方法 → `redirect_to login_path`。Inertia 的 XHR 访问跟随 302，行为一致。
- `safe_next(value)`：`value.is_a?(String) && value.match?(%r{\A/(?![/\\])[^[:cntrl:]]*\z}) ? value : nil`（合法 = 单个 `/` 开头、第二个字符不是 `/` 或 `\`、不含任何控制字符；制表符之类同样骗得过前两关，却会让 `redirect_to` 抛异常）。只在两处用：登录页 props 的 `next`（进隐藏字段 `origin`）与回调（`omniauth.origin`）。
- 放行清单：`SessionsController` 的 `new / create / failure`、`Rails::HealthController`（`/up` 不经 ApplicationController，天然放行）。兜底 404 路由在墙内。
- `Admin::BaseController < ApplicationController`：`before_action :require_admin` → `render_forbidden` = `render inertia: "Errors/Forbidden", props: footer_props, status: :forbidden`（不跳登录页，AC-3.5）。`ErrorsController#forbidden` 复用它（供路由测试与将来 `/admin` 根）。
- mission_control-jobs：`config.mission_control.jobs.base_controller_class = "Admin::BaseController"`、`http_basic_auth_enabled = false` 移到 `config/application.rb`；路由改 `mount MissionControl::Jobs::Engine, at: "/admin/jobs"`，三个环境都挂；删掉 development 专用的 `/jobs`。引擎自己的控制器继承 `Admin::BaseController`，因此也过登录墙与 admin 检查。
- 限流：`SearchesController` 与 `Search::ClicksController` 的 `rate_limit ... by: -> { Current.user.id }`（登录墙保证非空）。
- `inertia_share`（`ApplicationController`）：`current_user: Current.user && { display_name:, avatar_url:, email:, admin: }`，`flash: { notice: flash[:notice], alert: flash[:alert] }.compact`。前端 `SharedProps` 类型加进 `types/lowpass.ts`；`Masthead` 用 `usePage<SharedProps>()` 读 `current_user`，删掉 `accountHref`。
- production：`config.force_ssl = true`、`config.assume_ssl = true`（kamal-proxy 终止 TLS；Secure cookie 需要）。

## 6. 页面（按画布）

### 6.1 `Login/Show`

props：`{ providers: ("google_oauth2" | "github" | "developer")[], next: string | null }`，加共享的 `flash`。不套 `Layout`（`Show.layout = page => <>{page}</>`，深色底 `.ground`；包一层 Fragment 是必须的：Inertia 3.7 会先拿 props 探测一次 layout 函数，恒等函数返回的是 props 对象、不是元素，会被当成 props 解析器而套上默认布局）。结构：400px `.login-card`（纸色，1px 墨线）：80px 墨带 + `.masthead-brand` 同款 LOWPASS；1px 框里 `<Sunrise>`（`Illustration.tsx` 已有的低通日出）；口号「滤掉噪音，留下信号。」文楷 20 居中；按钮列（gap 8）：每个 provider 一个 `<form method="post" action="/auth/<name>">`，隐藏 `authenticity_token`（读 `meta[name=csrf-token]`）与 `origin`（`next` 非空时），按钮 44px 描边、文楷 15：「使用 Google 登录」「使用 GitHub 登录」；developer 是同一个表单里多两个 `field`（显示名、邮箱，`name="name"` / `name="email"`）+ 按钮「开发登录」。提示行：`flash.alert` 存在时，警示图标（`Icon name="triangle-alert"`，14px 次墨）+ 文楷 13 次墨、行高 1.6。手机：卡宽 100%，外边距 24px。`<title>` 「登录 · Lowpass」。

### 6.2 `Settings/Show`

props：`{ user: { display_name, email, avatar_url, role, admin_reason: string | null }, identities: { provider: "google" | "github", linked_at_label: string | null }[], session: { logged_in_label, expires_label }, providers: (…)[] }` + `FooterData`，套 `Layout`（masthead 无 active）。
- `PageHead big="设置"`，`top` = Maple 13 邮箱（无邮箱不渲染），`bottom` = 显示名（Newsreader 20，`Mixed` 处理中文名），`controls` = 「登出」描边按钮（`Ctrl` 的按钮变体，icon `log-out`，`onClick → router.delete("/session")`）。
- 提示行（`flash.alert` 时）：与登录卡同款，放在期头底线下、键值行上。
- 键值行 `.kv-row`（grid 160px + 1fr，上下 18px，底线 35% 墨线）：
  - 头像与显示名：48px 圆（`avatar_url` 有就 `<img>`，`alt=""`；没有就 `Icon name="user"` 描边圆）+ 显示名 20。
  - 邮箱：Maple 13；nil → 文楷 13 次墨「无」。
  - 角色：`Chip` 反白「管理员」+ 文楷 13 次墨「邮箱在白名单中」；或 `Chip`「成员」。
  - Google、GitHub 各一行（只列 `providers` 里有的真实 provider；developer 不列）：已绑定 → 文楷 15「已绑定」+ Maple 13 次墨「· 2026-09-08 14:02」；未绑定 → 文楷 15 次墨「未绑定」+ POST 表单按钮「使用 Google 登录」（文楷 15 链接样式）。
  - 本次会话：Maple / 文楷混排「2026-09-09 08:12 登录 · 30 天内免登录 · 2026-12-08 到期」（`Mixed`）。
- `<title>` 「设置 · Lowpass」。

### 6.3 头像菜单（`Masthead`）

- `current_user` 为 null（登录页不套 Layout，实际不会出现，但类型上允许）→ 现在的非交互占位。
- 有 `current_user`：头像位是 `<button aria-haspopup="menu" aria-expanded aria-label="账户">`，32px 圆，`avatar_url` 有就 `<img>` 填满（`objectFit: cover`），没有就人形图标。
- 展开：`position: absolute; right: 0; top: 56px` 的 220px 纸卡（`.menu-card`：纸底、1px 墨线、**无阴影**——设计规则说纸面里不许有阴影，画布那层阴影不取），`role="menu"`；顶部 Maple 12 次墨的邮箱（无邮箱用显示名）+ 35% 线；项目文楷 15、44px 高、左右 16px：「设置」`Link`、「管理」`Link`（admin 才有，指 `/admin/jobs`）、「登出」`<button>`（`router.delete("/session")`）。Escape、点卡外、选中任一项都关闭；焦点进第一项。手机同一张卡。
- `types/lowpass.ts`：`CurrentUser = { display_name; avatar_url: string | null; email: string | null; admin: boolean }`，`SharedProps = { current_user: CurrentUser | null; flash: { notice?: string; alert?: string } }`。

### 6.4 `Errors/Forbidden`

与 `Errors/NotFound` 同一装置：文楷 20 事实句「你没有权限访问这个页面。」+「回到首页」链接；状态码 403。

### 6.5 图标与路径

`Icon.tsx` 加三个 24 网格描边路径：`triangle-alert`（提示行）、`user`（无头像时的人形，报头现在内联的那份搬进来）、`log-out`（登出按钮）；几何取 lucide 同名图标，与画布 `common.py` 的 `ICON_PATHS` 同源。

`lib/paths.ts`

加 `LOGIN = '/login'`、`SETTINGS = '/settings'`、`SESSION = '/session'`、`ADMIN_JOBS = '/admin/jobs'`、`authHref(provider) = `/auth/${provider}``。

## 7. 配置与部署

- 环境变量：`GOOGLE_CLIENT_ID`、`GOOGLE_CLIENT_SECRET`、`GITHUB_CLIENT_ID`、`GITHUB_CLIENT_SECRET`、`ADMIN_EMAILS`。全部只从环境读，仓库里没有值。`.kamal/secrets` 加五行 `X=$X`；`config/deploy.yml` 的 `env.secret` 列上五个。`docs/development.md` 写清本地怎么配（变量写进仓库根目录的 `.env`，`.gitignore` 已忽略 `/.env*`；`bin/dev` 用的 Foreman 会自动读它）与两家 OAuth 应用的回调地址 `http://localhost:3000/auth/google_oauth2/callback`、`http://localhost:3000/auth/github/callback`。
- `docs/development.md` 加「登录」一节：开发登录怎么用、白名单怎么设、真实 provider 怎么配。
- PRD 附录 B 加一行「登录限流 | 操作过于频繁，请稍后再试。（复用搜索限流句）」，修订记录 v0.3.9。
- AGENTS.md 认证那条不用改（已写的正是这套）；`docs/engineering-conventions.md` 认证一节补一句「回调限流在 OmniAuth 之前的 Rack 中间件」。
- 上线清单 10.3 的 OAuth 一项由产品负责人在部署前完成（回调地址、同意屏幕、`user:email` 范围）。

## 8. 测试

- 模型：`Identity::ResolutionTest` 覆盖 signed_in（资料更新）、linked（AC-5.2）、created、unmergeable 的三种情形（未验证、缺失、AC-5.3）、角色刷新（白名单命中 / 不命中 / 白名单大小写与空白）、GitHub 只认 primary+verified；`SessionTest` 覆盖 30 天滑动、90 天硬上限、`touch_last_seen!` 一小时内不写库、`cleanup`。
- 控制器（`OmniAuth.config.test_mode = true`，`mock_auth` 在 `test/test_helpers/authentication_test_helpers.rb` 里按 fixture 生成）：`sign_in_as(user)` = 设 mock 为该用户第一条身份 → `post "/auth/<strategy>"` → `follow_redirect!`。用例：AC-5.1、AC-5.2（设置页两方式已绑定）、AC-5.3（跳设置页并带提示）、AC-5.4（admin 能开 `/admin/jobs`，菜单 props `admin: true`）、AC-5.5（未登录访问 `/daily/2026-09-08` → `/login?next=/daily/2026-09-08`，登录后回到该页）、AC-5.6（`mock_auth = :csrf_detected` → 不建会话、flash「登录失败，请重试。」）、AC-5.7（`origin` 为站外地址与 `//evil`、`/\evil` → 首页）、取消（`:access_denied` → 「已取消登录。」）、限流（同一 IP 第 11 次回调 → 302 `/login` + flash）、登出（会话删除、cookie 清除、再访问受保护页跳登录）、已登录访问 `/login` 跳 `/`、非 admin 访问 `/admin/jobs` → 403 且组件 `Errors/Forbidden`（AC-3.5）、未登录访问 `/admin/jobs` → 跳登录、搜索限流按用户（两个用户各 60 次互不影响）。
- 现有控制器测试与系统测试：每个测试类 `setup { sign_in_as(users(:drew)) }`；`searches_controller_test` 的限流用例改按用户。
- 前端（Vitest）：`Masthead` 菜单开合（点击、Escape、点外面）、admin 才有「管理」、登出调用 `router.delete`；`Login/Show` 按 providers 渲染按钮与隐藏字段、flash 提示；`Settings/Show` 键值行与未绑定表单。
- 系统测试：开发登录在 test 不挂，所以走 mock：真的在浏览器里点「使用 Google 登录」→ 落到首页 → 打开头像菜单 → 登出 → 回到登录页。
- `bin/ci` 全绿是合并门禁。

## 9. 性能

`resume_session` 每请求一次 `SELECT` by token（唯一索引）；`last_seen_at` 至多每小时一次 `UPDATE`；`inertia_share` 不再查库（`Current.user` 已加载）。中间件的限流计数在 `Rails.cache`（production 是 Solid Cache，一次 upsert）。

## 10. 迁移与运维

- 三张表一个迁移；不用回填。
- 部署顺序：先在两家建 OAuth 应用、把五个环境变量放进 `.kamal/secrets` 的来源，再 `kamal deploy`；部署后第一次登录的人若邮箱在白名单即成 admin。
- `ADMIN_EMAILS` 为空 → 没人是 admin；页面照常，只是没有「管理」。

## 11. 默认决定（代理定，可推翻）

| 编号 | 决定 | 理由 |
|---|---|---|
| L1 | 菜单卡不加阴影 | 设计规则：纸面里不许有阴影；1px 墨线足够分层 |
| L2 | 「使用 GitHub 登录以绑定」改成「使用 GitHub 登录」 | PM 审核指出：邮箱不同时它会新建账号，不是绑定 |
| L3 | 403 页用 404 页同款状态行装置，不用画布 `error_sheet` 的 40px 大字 | 404 落地时已定，两页要一致 |
| L4 | 兜底 404 在登录墙内 | D1：站内什么都不给外人看；一致性 |
| L5 | `sessions` 不存 ip / user_agent | 附录 A 没有，页面不显示 |
| L6 | 登录限流提示复用附录 B 的搜索限流句 | 不新造文案 |
| L7 | `users.email` 只做显示，合并只看已验证身份 | 见 4.5 的安全理由 |
| L8 | developer 身份的邮箱视为已验证 | 只在 development，用来试白名单与合并 |
| L9 | `/admin/jobs` 三个环境都挂 | ADR T12；development 的 `/jobs` 免认证挂载废掉 |

## 12. 实现顺序（供计划拆任务）

1. gem 与迁移、三个模型与 fixtures、`Identity::Whitelist`
2. `Identity::Profile` + `Identity::Resolution`（模型测试）
3. `Session` 规则、`Current`、`Authentication` concern、`ApplicationController` 接入、`inertia_share`（全站登录墙生效；现有测试补 `sign_in_as`）
4. OmniAuth 初始化器、`Auth::CallbackRateLimit`、`SessionsController` 与路由、测试辅助 `sign_in_as`（控制器测试）
5. `Admin::BaseController`、`Errors/Forbidden`、mission_control 挂到 `/admin/jobs`、搜索限流按用户
6. 前端：`SharedProps`、`Masthead` 菜单、`Login/Show`、`Settings/Show`（Vitest）
7. `SettingsController`、系统测试、文档（development.md、PRD 附录 B、conventions）、`.kamal/secrets` 与 `deploy.yml`
