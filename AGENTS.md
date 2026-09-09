# Lowpass

个人技术刊物站：每天 06:00（Asia/Shanghai）把 Hacker News、GitHub Trending、Hackaday 装订成一期不可变的日刊，
每周收进阮一峰周刊；信息源可配置，历史可搜索，Google / GitHub 登录，单租户。

本文件是带理由的默认值，不是法律：与眼前代码冲突时走更好的路并指出冲突；涉及数据丢失、安全、CI 门禁的不变量必须摆到台面上，不能悄悄绕过。提交前先攻击自己的 diff。

## 先读什么

- 需求：`docs/superpowers/specs/2026-09-08-mvp-prd.md`，F / R / AC / D / N 编号是唯一依据。
- 选型与决议：`docs/adr/0001-mvp-tech-stack.md`（Rails 8 + Inertia / React / TypeScript / shadcn，PostgreSQL，Solid Queue / Cache / Cable，Kamal；T1 到 T12）。
- 代码风格：`STYLE.md`，改代码或评审前先读。界面：`.claude/skills/lowpass-design-taste/`。
- 每条约定的出处与取舍：`docs/engineering-conventions.md`。

## 不变量

- 期发布后不可变。例外只有两个：管理员按「某期某源」重抓整栏替换并记 `revised_at`；推荐理由可在发布后补写。
- 周期键只在一处计算；展示按 Asia/Shanghai，存储 UTC；跨日与非上海时区有测试。
- 调度是每分钟一次的 tick，读数据库里的生成时间；不是静态 cron；错过要补跑。
- 某个源失败只告警，不阻塞发布。推荐理由异步生成，只有日刊条目有，周刊没有。
- 适配器只产出 PRD 7.2 契约的条目，期生成器不认识具体的源。
- `/admin` 只给由白名单邮箱推导出的 admin，其他人 403。单租户，没有 Account。

## 约定

- 主键：UUIDv7 编成 25 字符 base36 字符串列，不用 PostgreSQL 的 uuid 类型。fixture 的 id 比运行时记录都老，别用插入顺序去修正排序。
- 搜索：PostgreSQL 内建。`Searchable` concern 用 `after_*_commit` 维护独立的 `Search::Record` 表，不为搜索改条目表。
- 出站 HTTP：超时、有限重试、标明 lowpass 的 User-Agent、响应体上限；429 / 403 不追加重试；feed 地址先经 `surfguard` 解析成公网 IP 再连。
- 后台任务：Solid Queue，浅 job 调富模型（`_later` 入队、`_now` 同步）；周期任务写在 `config/recurring.yml`；job 幂等，某期某源同时只允许一个重抓。
- 认证：OAuth。`Session` 记录 + 签名 cookie；`Current` 承载 session、user 与请求属性；`rate_limit` 保护登录回调与搜索；`next` 只接受站内相对路径。
- 前端：控制器是 CRUD 资源，每个动作渲染一个 Inertia 页面；props 必须有类型；首屏资源不超过 300 KB；颜色、字体、字号只从设计 skill 的令牌取。
- 数据库：只支持 PostgreSQL。`string` / `text` 列写明 `limit`（值来自 PRD 7.2）并加 CHECK 约束；唯一性放数据库。
- 测试：Minitest + fixtures；不碰网络，源站样本放 `test/fixtures/files/`；`bin/rails test` 快速循环，`bin/ci` 是合并门禁（rubocop、brakeman、bundler-audit、gitleaks、测试、系统测试）。
- 环境与部署：mise 钉工具版本；`bin/setup` 幂等；`bin/dev` 起 rails + vite；密钥只从环境读。`main` 分支用 Kamal 部署 `web` 与 `job` 两个角色加 PostgreSQL accessory；新增常驻进程先改 ADR 里的内存预算；队列面板 `mission_control-jobs` 挂在 `/admin/jobs`。

## 不要做

不引入多租户、SaaS 双 Gemfile、SQLite / MySQL 双适配器、外部搜索引擎、图片处理、Web Push、通行密钥、邮箱验证码登录、prek。
