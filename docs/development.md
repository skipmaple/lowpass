# 开发环境

## 前置要求

- [mise](https://mise.jdx.dev/)：钉住 Ruby 与 Node 版本，见 `.mise.toml`。
- Docker：本地 PostgreSQL 18 以容器运行，见下文；不需要本机装 PostgreSQL 或 `psql`。
- Google Chrome：系统测试（`bin/rails test:system`，`bin/ci` 的一步）用无头 Chrome 跑真浏览器。
  chromedriver 不用手装，selenium-webdriver 自己下（Selenium Manager）。

## 首次搭建

```
bin/setup
```

幂等，可重复执行。做了什么：

1. `mise install --yes` 装好 `.mise.toml` 钉住的 Ruby 与 Node。
2. 把 Git 的 `core.hooksPath` 指到 `.githooks`（见下文「提交前检查」）。
3. `bundle install`、`npm install`。
4. 若本机 5432 端口没有服务在监听，启动（不存在则新建）名为 `lowpass-postgres` 的
   `postgres:18` 容器（与 CI 的 postgres service、生产 accessory 同一个大版本），用户名与密码均为
   `postgres`，只发布到 `127.0.0.1:5432`（默认口令不该跟着局域网走），然后轮询容器里的
   `pg_isready`，最多等 30 秒。已有的 `lowpass-postgres` 若是用别的镜像建的（以前是 `postgres:16`），
   照样启动，但会提醒一句，换法见下文「数据库」。加 `--skip-server` 参数就整段跳过（`config/ci.rb`
   的 Setup 步骤与 CI 里的 postgres service 自己管数据库）。
5. `bin/rails db:prepare`（加 `--reset` 参数则改为 `bin/rails db:reset`）。
6. 清理 `log/`、`tmp/`。

## 日常开发

```
bin/dev
```

用 [Foreman](https://github.com/ddollar/foreman) 按 `Procfile.dev` 同时起三个进程：Rails server
（3000 端口，`http://localhost:3000`）、Vite dev server，以及 `bin/jobs`（Solid Queue worker，带
`config/recurring.yml` 里每分钟一次的 `SchedulerTickJob`）。日刊到点生成、错过补跑、超时收尾、
每天检查一次周刊都靠这个 tick（`Scheduler#tick` 先写心跳，即 `Setting` 的 `ticked_at`，健康检查靠它；再依次跑
`generate_daily_if_due`、`finalize_stale_issues`、`check_weekly_if_due`、`check_reasons_if_due`、`cleanup_if_due`
与 `backup_if_due`，开发机上一个 `BACKUP_*` 都没配时最后这步什么都不做，见「备份」），本地想看效果就得让 jobs 进程
跑着，`log/development.log` 里每分钟一条。日刊生成、周刊检查的时间点读 `Setting`（键
`daily_time`、`weekly_time`），不是写死在代码里。

## 队列面板

```
http://localhost:3000/admin/jobs
```

`mission_control-jobs` 三个环境都挂在 `/admin/jobs`（`config/routes.rb`），只给 admin：认证由 `Admin::BaseController`
做（登录墙 + 白名单角色，`config/application.rb` 的 `base_controller_class`），引擎自带的 HTTP Basic Auth 关掉了，
仓库里没有凭证。本地要看它，先用开发登录、邮箱填在 `ADMIN_EMAILS` 里的那个（见下文「登录」）。

## 登录

全站要登录才能读（PRD D1）。development 的登录页多一个「开发登录」表单（OmniAuth 的 `developer` 策略，
只在 development 挂载）：填显示名与邮箱就进来，不需要任何 OAuth 应用。管理员由白名单推导（R-5.5）：

```
# .env（仓库已忽略 /.env*；bin/dev 用的 Foreman 会自动读它）
ADMIN_EMAILS=you@example.com
```

填在白名单里的邮箱登录后，报头头像菜单多一项「管理」。换一个邮箱登录就是普通成员，方便看两种视图。

想在本地走真实的 Google / GitHub 登录，在两家各建一个 OAuth 应用：Google Cloud Console 的「OAuth 客户端 ID」
（Web 应用，已授权的重定向 URI 填 `http://localhost:3000/auth/google_oauth2/callback`，同意屏幕范围 `openid email profile`）；
GitHub Settings → Developer settings → OAuth Apps（Authorization callback URL 填 `http://localhost:3000/auth/github/callback`，
登录时申请 `user:email`）。把凭证放进 `.env`：

```
GOOGLE_CLIENT_ID=…
GOOGLE_CLIENT_SECRET=…
GITHUB_CLIENT_ID=…
GITHUB_CLIENT_SECRET=…
```

哪家的两个变量都配了，登录页就多出那家的按钮（`config/initializers/omniauth.rb`）。会话 30 天滑动、最长 90 天，
存在 `sessions` 表，cookie 里只有签名过的 token；登出即删。登录回调按 IP 每分钟 10 次（`lib/middleware/auth/callback_rate_limit.rb`）。

设置页最后一行是注销（PRD R-5.11、D33）：确认框里确认后 `DELETE /user`，删掉用户、登录身份与全部会话（别的设备随之退出），
审计记录留着、操作者置空，回到登录页；用同一方式再登录是一个新用户。本地试的话用开发登录随便建一个账号再注销。

测试不连 provider：`OmniAuth.config.test_mode`，`test/test_helpers/authentication_test_helpers.rb` 的 `sign_in_as` 按 fixture 里的
身份伪造一次登录；系统测试用 `sign_in_with_browser`，真的在浏览器里点登录按钮。

## 管理后台

```
http://localhost:3000/admin
```

白名单邮箱登录后，报头头像菜单的「管理」进 `/admin/sources`。四个分页：信息源（新建 / 编辑 / 启停 / 测试抓取 / 抓取记录）、
期（某期某源重抓、补生成缺期、立即生成今日日刊）、用户（只读）、设置（日刊生成时间、周刊检查时间；白名单只读；告警渠道；
备份状态与「立即备份」；兴趣画像与推荐理由）。
写操作都记进 `audit_logs`（谁、何时、对什么、改了什么），保留 90 天，没有界面，要看用 `bin/rails console`：
`AuditLog.order(created_at: :desc).limit(20)`。

测试抓取是 `POST /admin/test_fetches` 的 JSON 端点，请求内同步等最多 30 秒；本机代理是 fake-IP 模式时会得到
「地址解析不到公网 IP。」（见「抓不到内容？」）。手动重抓走 `FetchSourceJob`（`trigger: "manual"`），本地要让
`bin/dev` 的 jobs 进程跑着，期页与记录页每 5 秒刷新一次直到任务结束。补生成过去的日子只对支持回填的源产出内容：
Hacker News 经 Algolia（`hn.algolia.com`），RSS 看 feed 里还有没有那一天的条目，GitHub Trending 标「该来源无法回填」。

## 告警

设计见 `docs/superpowers/specs/2026-09-14-p2-alerts-design.md`。渠道只从环境读（`config/initializers/alerts.rb` 启动时检查一次并把问题写进日志），配一个或两个：

| 变量 | 说明 |
|---|---|
| `BASE_URL` | 站点地址，告警里的后台链接与抓取的 User-Agent 都用它（默认 `http://localhost:3000`；production 必填，缺了链接会指向 localhost） |
| `ALERT_EMAIL_TO` | 收件地址，逗号分隔；与 `SMTP_ADDRESS` 一起配了邮件渠道才算开 |
| `ALERT_EMAIL_FROM` | 发件地址，默认 `lowpass@<BASE_URL 的主机名>` |
| `SMTP_ADDRESS` `SMTP_PORT` `SMTP_USERNAME` `SMTP_PASSWORD` `SMTP_DOMAIN` `SMTP_AUTHENTICATION` `SMTP_STARTTLS` | SMTP；`SMTP_PORT` 留空按 587，`SMTP_DOMAIN` 默认取 `BASE_URL` 的主机名，认证默认 plain（没配用户名就不认证），STARTTLS 默认开。每个变量留空都等于没配（Kamal 对没配的变量注入空串） |
| `ALERT_WEBHOOK_URL` | https 的 JSON 接收端：Slack incoming webhook、飞书 / 企业微信 / 钉钉的自定义机器人都行 |
| `ALERT_WEBHOOK_FORMAT` | 报文形状：`generic`（默认，Slack 兼容）· `feishu` · `wecom` · `dingtalk` |

本地看效果：development 的邮件不真发，`bin/rails console` 里看 `ActionMailer::Base.deliveries`；webhook 可以指到自己的 https 接收端。
验证 AC-7.1：配好变量，`bin/dev` 起着（jobs 进程在跑），到 `/admin/settings` 点「发送测试告警」，1 分钟内应收到「[lowpass] 提示 · 测试告警」。
事件记在 `alert_events`（`AlertEvent.order(created_at: :desc).limit(20)`），同源同日同类只发一条，恢复后发一条「已恢复」；
事件保留 90 天，由每天 04:00 的清理一并删。
投递失败最多重试 3 次，耗尽写日志并留在 `delivery_error`。触发点：源抓取终态失败、解析退化（丢弃过半、阮一峰降级）、空刊、
日刊晚于生成时间 30 分钟以上才补跑、搜索连续 3 次不可用、每日备份失败（见「备份」）、推荐理由在发布 30 分钟后仍有缺失。
这些告警都从应用进程里发出：进程本身停了就一条也发不出来，那种情况靠「健康检查」接的外部拨测。

## 推荐理由

设计见 `docs/superpowers/specs/2026-09-14-p2-reasons-design.md`。接入层只认 OpenAI 兼容的 chat completions：在 `/admin/settings`「推荐理由」一节填接口地址（如 `https://api.openai.com/v1`、`https://api.deepseek.com/v1`，本地 Ollama 是 `http://localhost:11434/v1`）、模型名、每百万 token 的输入 / 输出单价与月费用上限（0 = 不限）；密钥只从环境读：

```
MODEL_API_KEY=…
```

三样齐了才生成：日刊发布后入队 `GenerateReasonsJob`，一期顺序做，单条 20 秒超时、重试 2 次，缺领域名判失败；跨天重复的条目沿用前一期理由。
Hacker News 与 Hackaday（RSS 日刊源）的标题、GitHub Trending 的仓库简介在同一次调用里顺带拿回中文译文（PRD D25，`items.title_zh` / `items.summary_zh`），读者页排在各自原文下方；不多一次调用，译文不合规只当没有，不影响理由。D25 上线前已经发布的期没有译文：到后台期页对那一期点「重生成理由」就连同译文一起补上（整期覆盖，理由也会重写，一期约 30 次调用）。
后台期页每期显示「已生成 / 缺 N 条」并可「重生成理由」（整期覆盖）；读者页不提供重生成入口，避免误触产生模型费用。受保护的单条重生成后端接口仍保留给管理流程。
账本在 `model_calls`（`ModelCall.order(created_at: :desc).limit(20)`），保留 90 天；月费用到上限就停止生成并告警一次。
发布 30 分钟后仍缺理由会告警（③ 的「推荐理由缺失」）。初始兴趣画像由 `bin/rails db:seed` 建，后台可增删改。
**已经存在的数据库要手动跑一次 `bin/rails db:seed`**：`bin/setup` 与 Kamal 的 `db:prepare` 只在新建数据库时播种，
老库里的 `interest_areas` 是空的。画像里没有启用的领域就不生成（不调模型、不记费用），
后台期页那一格与两个「重生成」都会写「兴趣画像为空」。

## 备份

设计见 `docs/superpowers/specs/2026-09-28-p3-backup-health-design.md`。每天 03:00（上海）tick 入队一次 `BackupJob`，
当天错过就补跑：主库 `pg_dump --format=custom`（`solid_cache_entries`、`solid_cable_messages` 只留表结构），AES-256-GCM
加密，再以 S3 兼容协议（SigV4 PutObject）上传。队列库不备份，恢复后由入口的 `db:prepare` 重建。每一次备份记在 `backup_runs`，
保留 30 天。上传遇到 5xx 或网络错误时重试 2 次（间隔 2 分钟、10 分钟）；其余错误和重试耗尽都发一条「备份失败」（严重，一天一条）。
`/admin/settings` 的「备份」一节显示存储地址、密钥指纹、最近一次与最近成功，也可以「立即备份」。

配置只从环境读，五项都齐才算配好：

| 变量 | 说明 |
|---|---|
| `BACKUP_BUCKET_URL` | 对象的上一级地址，可带前缀。虚拟主机式如 `https://lowpass-backup.oss-cn-hongkong.aliyuncs.com/daily`，路径式如 `https://<account>.r2.cloudflarestorage.com/lowpass-backup/daily`。只接受 https；`localhost` / `127.0.0.1` 的 http 也行（本机演练用） |
| `BACKUP_REGION` | 签名用的区域：R2 填 `auto`，AWS 填桶所在区域，阿里云 OSS 按其 S3 兼容文档填（形如 `oss-cn-hongkong`） |
| `BACKUP_ACCESS_KEY_ID` / `BACKUP_SECRET_ACCESS_KEY` | 只给这个桶（或前缀）`PutObject` 权限的密钥：应用只写不读不删。R2 没有只写的一档，见下文 |
| `BACKUP_ENCRYPTION_KEY` | `openssl rand -hex 32` 生成的 64 位十六进制。除了服务器环境，还要在密码管理器里另存一份：丢了它，备份就解不开 |

production 下没配（或配不全）就是 N-6 不达标：每天 03:00 照样记一次失败并告警，启动日志里也会写一句。开发机上一个 `BACKUP_*`
都不配就不备份。

存储端要做的三件事：桶保持私有；加一条生命周期规则「前缀下的对象 7 天后删除」（PRD 7.8 的保留期就在这里，应用不删文件）；
建一把只有 `PutObject` 权限的密钥。对象名是 `<库名>-<UTC 时间戳>.dump.enc`，在控制台里按名字排就是按时间排。

Cloudflare R2 的令牌没有只写这一档，最小是「Object Read & Write」并限定到这个桶，读、写、列、删都能做。只写要防的是服务器被攻破后
历史备份跟着被删，R2 上改用桶锁来防：桶的 Settings →「Bucket lock rules」加一条，前缀与生命周期规则相同（如 `daily/`），保留 7 天。
期限内的对象谁都删不掉、改不了；锁优先于生命周期规则，满 7 天照常删；令牌只能动对象，改不了桶的规则。保留期别选 Indefinite，
那样生命周期规则就永远删不掉了。令牌建成 Account API token，不随个人账号失效。

换加密密钥：换上新密钥之后的备份用新密钥，旧密钥至少再留 7 天，等旧备份过期。设置页与解密报错里显示的指纹，就是用来对上用的是哪一把。

手动备份（数据库升级等高风险操作之前）：`bundle exec kamal app exec --reuse "bin/rails backup:now"`，或者后台「立即备份」。

本机试上传，可以用 rclone 起一个会校验签名的 S3 服务端：

```
rclone serve s3 --auth-key drillkey,drillsecret --addr 127.0.0.1:9000 /tmp/s3root   # 先建好 /tmp/s3root/lowpass-backup
BACKUP_BUCKET_URL=http://127.0.0.1:9000/lowpass-backup/daily BACKUP_REGION=us-east-1 \
BACKUP_ACCESS_KEY_ID=drillkey BACKUP_SECRET_ACCESS_KEY=drillsecret BACKUP_ENCRYPTION_KEY=$(openssl rand -hex 32) \
  bin/rails backup:now
```

### 恢复

1. 从存储的控制台（或任意 S3 客户端）下载要恢复的那个对象。
2. 解密：`BACKUP_ENCRYPTION_KEY=… ruby script/decrypt_backup lowpass_production-20260928T190000Z.dump.enc lowpass.dump`。
   脚本只用 Ruby 标准库，不启动应用、不连数据库，任何一台装了 Ruby 的机器都行。认证标签校验不过（文件损坏、被改、密钥不对）就不留输出。
3. 恢复到一个新库，核对主要表的行数：

   ```
   createdb lowpass_restore
   pg_restore --no-owner --no-privileges --exit-on-error -d lowpass_restore lowpass.dump
   psql -d lowpass_restore -c "select (select count(*) from issues) issues, (select count(*) from items) items, (select count(*) from sources) sources, (select count(*) from users) users"
   ```

4. 生产的库整个没了（新服务器、数据卷丢了）：先只起数据库，恢复完再起应用。应用先起来的话，入口的 `db:prepare` 会建一个空库，调度紧接着往里写新的一期：

   ```
   bundle exec kamal server bootstrap      # 新服务器才需要：装 Docker
   bundle exec kamal accessory boot db
   # 等 initdb 跑完再导，否则会连不上，或者导到一半被停掉（见「升级数据库大版本」第 4 步）
   ssh root@$DEPLOY_HOST 'for i in $(seq 120); do docker logs lowpass-db 2>&1 | grep -qE "init process complete|Skipping initialization" && docker exec lowpass-db pg_isready -q -U lowpass -d lowpass_production && { echo ready; exit 0; }; sleep 1; done; docker logs --tail 20 lowpass-db; exit 1'
   ssh root@$DEPLOY_HOST 'mkdir -p /root/lowpass-backups'
   scp lowpass.dump root@$DEPLOY_HOST:/root/lowpass-backups/
   ssh root@$DEPLOY_HOST 'docker exec -i lowpass-db pg_restore -U lowpass -d lowpass_production --no-owner --exit-on-error < /root/lowpass-backups/lowpass.dump'
   bundle exec kamal setup                 # 已在跑的 accessory 它会跳过；入口的 db:prepare 重建空的队列库
   ```

   库还在但数据坏了：`bundle exec kamal app stop`，在 accessory 里 `dropdb` / `createdb lowpass_production` 之后照上面恢复，再 `bundle exec kamal app start`。
   恢复完打开 `/health`，再到后台看一眼期与源。

### 演练记录（N-6）

- 2026-09-28，本机（PostgreSQL 18.6，rclone 1.75.1 的 `serve s3`，会校验 SigV4）：开发库灌入样本数据（4 个源、3 期、88 条）后
  `bin/rails backup:now` 上传 84.1 KB；换一把错的 secret 再传，存储端回 403 `SignatureDoesNotMatch`，说明签名确实被校验过。
  取回对象，用 `ruby --disable-gems script/decrypt_backup` 解密，`pg_restore --no-owner --no-privileges --exit-on-error` 恢复到新库，
  各表行数一致，`pg_trgm` 在；应用连上恢复出来的库，搜索正常返回。
- 2026-09-28，生产（Cloudflare R2；同一天线上从 PostgreSQL 17 升到 18）：后台「立即备份」三次都成功，15:18 与 15:28 在 17 上
  （各 246 KB），15:46 在 18 上。从 R2 取回当天的备份，在本机用密码管理器里另存的那份密钥解密，恢复到 PostgreSQL 18 的新库：
  issues 16、items 467、sources 4、users 1，与线上一致。

## 健康检查

`GET /health` 给外部拨测（PRD N-5，设计 §3）：不用登录，只返回状态、不含内容；全部正常时 200，任一项失败时 503。
按 IP 每分钟 30 次，计数放在进程内存里。`/up` 不变，仍只回答「应用起来没有」，给 kamal-proxy 切流量用。

| 检查 | 失败条件 |
|---|---|
| `database` | `SELECT 1` 出错 |
| `search` | 固定探测查询 1 秒内没跑完或出错（不计入「搜索不可用」告警的连续失败计数） |
| `scheduler` | tick 心跳（`Setting` 的 `ticked_at`）超过 5 分钟没更新。返回里另附 Solid Queue 的进程心跳：tick 停了而进程心跳还在，是 tick 本身出错；两个都停，是 Solid Queue 停了 |
| `daily_issue` | 过了生成时间 30 分钟，当日期还不存在（此前只要求昨日期存在）。返回里附最近一期的发布时间与距今分钟数 |
| `backup` | 需要备份时（production，或者配了 `BACKUP_*`），最近一次成功超过 50 小时；一次都没成功过则从第一条记录算起。一条记录都没有时不判 |

```
curl -s https://lowpass.tech/health
{"status":"ok","checked_at":"2026-09-28T10:00:00+08:00","checks":{"database":"ok","search":"ok","scheduler":"ok","daily_issue":"ok","backup":"ok"},"search":{"latency_ms":12},"scheduler":{"ticked_at":"…","queue_heartbeat_at":"…"},"daily_issue":{"latest":"2026-09-28","expected":"2026-09-28","published_at":"2026-09-28T06:12:04+08:00","age_minutes":227},"backup":{"last_succeeded_at":"2026-09-28T03:00:21+08:00"}}
```

外部拨测：在 UptimeRobot、Better Stack 这类服务上建一个 HTTP(S) 监控，地址填 `https://lowpass.tech/health`，间隔 1 到 5 分钟，非 200 就通知。
它的通知走拨测服务自己的渠道，和应用的告警互相独立，这正是它的用处：应用进程或 Solid Queue 停了的时候，应用自己一条告警也发不出来。

## 开发数据

```
mise exec -- ruby script/seed_sample_issue            # 昨天那一期日刊
mise exec -- ruby script/seed_sample_issue 2026-09-08 # 指定周期键
mise exec -- ruby script/seed_sample_weekly           # 阮一峰第 411 期那一周的周刊
```

`seed_sample_issue` 把 `test/fixtures/files/` 里那批源站样本（HN topstories 与条目、GitHub Trending 的 daily.html、
Hackaday 的 feed）当成三个日刊源的响应，用正式的抓取 → 装订 → 定稿路径写出一期结构真实的日刊，
不连网络。想在浏览器里看日刊页时用它，比等 `bin/dev` 的调度器到点快。只在 development 下能跑；
重复执行会先删掉同一周期键的旧期，可以反复跑。样本抓下来那天早就过了 RSS 源的 24 小时窗口，
脚本只在内存里把 `window_hours` 放宽，不改库里的源配置。

`seed_sample_weekly` 同理，把 `test/fixtures/files/ruanyf/` 里的仓库 README 与第 411 期原文当成阮一峰周刊的响应，
走 `Issue.check_weekly_sources!` 装订出一期真实的周刊（9 个板块、33 条），用来看周刊页与周刊归档。
期落在原文发布日所在的 ISO 周（R-2.2）。重复执行会先删掉上次装订的那一期（整期只有第 411 期的条目），可以反复跑。

源列表来自 `bin/rails db:seed`（`bin/setup` 已经跑过）；对应的源没有启用时脚本会直接退出并提示。

## 手动生成一期

不想等调度器到点，直接在 Rails console 或 `bin/rails runner` 里调用正式代码路径——会真的按源配置出网抓取，
不是样本数据；离线看效果用上面的 `seed_sample_issue` / `seed_sample_weekly`。

```
# 跑一次完整的调度 tick，和 SchedulerTickJob 每分钟做的事一样
mise exec -- bin/rails runner 'Scheduler.tick'

# 只生成今天的日刊，不等 Setting 里的 daily_time
mise exec -- bin/rails runner 'Issue.generate_daily!(PeriodKey.today, trigger: "manual")'

# 检查一遍所有启用的周刊源；阮一峰按期号认新内容，其余按本周的 ISO 周键
mise exec -- bin/rails runner 'Issue.check_weekly_sources!'

# 某一期某个源重抓：整栏替换，成功且期不在生成中则记 revised_at 并按需补发布（R-1.5）
mise exec -- bin/rails runner '
  issue = Issue.daily.find_by!(period_key: "2026-09-10")
  source = Source.find_by!(adapter: "hacker_news")
  Issue.regenerate_source!(issue, source)
'
```

## 抓样本

```
mise exec -- ruby script/capture_samples hn
mise exec -- ruby script/capture_samples github
mise exec -- ruby script/capture_samples hackaday
mise exec -- ruby script/capture_samples ruanyf 400 420   # FROM TO：阮一峰的期号区间
```

写到 `test/fixtures/files/` 下对应目录，供适配器测试与 `seed_sample_issue` / `seed_sample_weekly` 使用。
这是唯一允许联网的开发脚本；测试本身、`seed_sample_*` 都不连网络。

## 数据库

连接参数从环境变量读取，见 `config/database.yml`：`PGHOST`、`PGPORT`、`PGUSER`、`PGPASSWORD`，
默认值都指向 `bin/setup` 起的 `lowpass-postgres` 容器。开发与生产都是两个库：业务库（`lowpass_development`）
和给 Solid Queue 的 `queue` 库（`lowpass_development_queue`，表结构在 `db/queue_schema.rb`，
见各自环境文件里的 `config.solid_queue.connects_to`），`bin/rails db:prepare` 会一并建好；测试环境只有一个库。
Solid Cache 与 Solid Cable 的表与业务表同库。

开发容器、CI 的 postgres service（`.github/workflows/ci.yml`）与生产 accessory（`config/deploy.yml`）都是 PostgreSQL 18，
三处一起升级；生产的做法见「部署」的「升级数据库大版本」。

手动操作容器：

```
docker start lowpass-postgres   # 启动
docker stop lowpass-postgres    # 停止
docker rm lowpass-postgres      # 删除，数据一并丢失
```

以前建的 `lowpass-postgres` 是 `postgres:16`，`bin/setup` 会提醒。换成 18：开发库的数据用不着的话，直接删容器重来，再按「开发数据」
灌样本；想留着就先导出、建好新容器再导回：

```
docker exec lowpass-postgres pg_dump -U postgres -Fc lowpass_development > tmp/lowpass_development.dump   # 想留数据才需要
docker rm -f lowpass-postgres
bin/setup                                                                                                  # 建 postgres:18 的新容器并 db:prepare
docker exec -i lowpass-postgres pg_restore -U postgres -d lowpass_development --clean --if-exists --no-owner < tmp/lowpass_development.dump
```

## 搜索

PostgreSQL 内建（ADR T7、设计文档 `docs/superpowers/specs/2026-09-11-p1-search-design.md`）：`pg_trgm` 由迁移启用
（开发容器与生产 accessory 都是超级用户连接，`db:prepare` 就够）。索引表 `search_records` 由 `Item` 的
`Searchable` 回调与装订（`Issue::Sections`）维护，不需要手动刷新；第一次跑完这批迁移、或怀疑索引不对时重建：

```
bin/rails search:rebuild
```

第一次把这批迁移部署到线上之后，在服务器上也跑一次（`kamal app exec --reuse "bin/rails search:rebuild"`）；之后索引由回调与装订自己维护，改了索引副本的规则（比如 `Search::Record::SCRIPT_GAP`）再重建一次。

验收：把 50 条真实查询一行一条写进文件，跑

```
mise exec -- ruby script/search_eval queries.txt
```

打印每条的结果数与耗时、p50 / p95 与有结果率（目标 ≥ 85%，p95 < 500 ms）。调参的位置都在
`app/models/search/runner.rb`：四列权重 `WEIGHTS`、拼写容错阈值 `similarity_threshold`（5 到 8 字符 0.55、
9 字符起 0.45）与索引粗筛的下限 `SIMILARITY_FLOOR`；拆词规则在 `app/models/search/query.rb`。搜索日志
（`search_logs`，30 天）与结果点击（`search_clicks`，90 天）由每天 04:00 的清理一并删。

## 测试与 CI

```
bin/rails test          # 快速循环，不连网络
npm test                # 前端单元测试（Vitest，jsdom），npm run test:watch 是监视模式
bin/rails test:system   # 无头 Chrome 里读一期日刊、搜一条并回到所在期、走一遍登录与登出、收藏一条再取消与恢复
                         # （test/system/reading_test.rb、searching_test.rb、signing_in_test.rb、favoriting_test.rb）
bin/ci                  # 合并门禁，见 config/ci.rb
```

前端单元测试在 `test/frontend/`（跟 Ruby 的 `test/` 同级，不放进 `app/frontend`）：`lib/` 是排字与
时间那几个纯函数，`components/`、`pages/` 用 Testing Library 在 jsdom 里渲染真组件，断言的是读者
看得到的东西（文本、`role`、`href`、行内样式里的字体令牌），不存快照。配置在 `vitest.config.mts`，
跟 `vite.config.mts` 分开——那边的 vite-plugin-ruby、Inertia、Tailwind 三个插件是为 Rails 里的构建
产物准备的，jsdom 下一个都用不上。`test/frontend/setup.ts` 把 `@inertiajs/react` 整个换成
`test/frontend/support/inertia.tsx` 里的替身（`Link` 就是 `<a href>`，`usePage` 读一份可写的 props），
因为真的 Inertia 要先有 `createInertiaApp` 挂出来的应用实例才有 page 上下文。props 的样例工厂在
`test/frontend/support/props.ts`，字段跟 `Issue::Presenting` 给出的那套对齐。类型检查覆盖测试文件：
`npm run check` 第三条就是 `tsc -p tsconfig.test.json`。

一个只在 jsdom 里出现的坑：`Mixed`（以及搜索页的 `HitText`）把一段文字拆成多个相邻 `<span>`，`getByRole` 算
可访问名时每个 `<span>` 先 trim、行内兄弟之间不加分隔，落在边界上的空格就没了——`getByRole('link', { name: '近 7 天' })`
找不到，报错列出的 Name 是「近7天」，比可见文本少一个空格。真浏览器与 `textContent` / `toHaveTextContent` 都不受
影响；`name` 换成容忍空格的正则（`/^近\s*7\s*天$/`）即可，不要改 `Mixed` / `HitText` / `splitRuns`。
机制写在 `app/frontend/lib/typeset.tsx` 顶上。

`bin/ci` 依次跑：Setup（`bin/setup --skip-server`）、Style: Ruby（`bin/rubocop`）、Frontend: typecheck
（`npm run check`）、Frontend: unit tests（`npm test`）、Frontend: audit（`npm audit --audit-level=high`）、
Frontend: build（`npm run build`）、Frontend: first screen budget（`script/first_screen_size`：读上一步的构建产物，
日刊页首屏的 JS、CSS 与界面字体合计超过 300 KB 就失败，PRD N-1；GitHub Actions 的 `test` job 在 Build frontend 之后跑同一步）、Security: Gem audit（`bin/bundler-audit`）、
Security: Brakeman code analysis、Security: Secrets
（`gitleaks detect --source . --no-banner --redact`，规则继承自 gitleaks 内置集，豁免的误报与理由见
仓库根目录的 `.gitleaks.toml`）、Frontend: build for tests（`env RAILS_ENV=test bin/vite build --mode
test`）、Tests: Rails（`bin/rails test`）、Tests: System（`bin/rails test:system`，要本机有 Chrome）、
Tests: Seeds（`RAILS_ENV=test bin/rails db:seed:replant`，验的是 `db/seeds.rb` 预置的 4 个源在
任何环境都建得出来）。
「Frontend: build for tests」先出一份 test 模式的 Vite 构建产物，避开下一步并行测试 worker 抢着触发
`autoBuild`（`config/vite.json` 里 test 环境开着）的竞态——不这么做偶尔会在并行跑测试时炸出 `Vite
test manifest missing entrypoints/application.css`；`autoBuild` 本身留着，单独跑 `bin/rails test` 不受
影响，但这个结论的前提是 `public/vite-test` 下已经有一份构建产物。刚 clone 的仓库第一次跑、`public/
vite-test` 还是空的时候，直接并行 `bin/rails test` 同样可能撞上这个竞态；`bin/setup` 之后先完整跑一次
`bin/ci`（或单独跑一次 `env RAILS_ENV=test bin/vite build --mode test`）能避开。这一步必须显式带
`RAILS_ENV=test`：vite_rails 的 CLI 会先把 Rails 应用整个启动起来才处理 `--mode`，没有 `RAILS_ENV` 时
`Rails.env` 默认是 development，产物会悄悄写进 `public/vite-dev` 而不是 `public/vite-test`，起不到防
竞态的作用。

`bin/rails test` 超过 50 个测试后会按 CPU 核数 fork 出并行 worker，封顶 8 个（核数很高的机器上开满会把
PostgreSQL 连接池压出间歇性失败）。`config/database.yml` 里的 `gssencmode: disable` 是为了绕开 macOS 上
预编译 pg gem 在 fork 后段错误的问题（表现为 worker 全部崩溃、命令挂起），别删；想单进程跑就
`PARALLEL_WORKERS=1 bin/rails test`（这个环境变量优先于核数上限生效）。

## 抓不到内容？

某些网络环境的 DNS 对不存在或任意的域名也返回一个能连上的地址（代理开着 fake-IP 模式，常见网段
`198.18.0.0/15`）。出站请求先经 `surfguard` 把域名解析成公网 IP 才会真的去连
（`Adapters::Http#resolve_public_ip`），fake-IP 网段不是公网地址，会被过滤掉，解析结果变成空，
抓取以 `Adapters::Http::Unresolvable` 收场——`FetchRun` 记一条 `failed`，不阻塞发布，只是那一栏空着
（AC-1.2）。把代理切到 real-IP 模式，或者不出网，用上面的 `seed_sample_issue` / `seed_sample_weekly`
看离线数据。

## 提交前检查

`bin/setup` 把 `core.hooksPath` 设为 `.githooks`；`.githooks/pre-commit` 对本次提交改动的 `.rb`
文件跑 `bin/rubocop --force-exclusion`，未改动 Ruby 文件时直接放行。

## 部署

底座（ADR T4、T5）：阿里云轻量（香港，x86_64；地址不进仓库，本机放在 deploy.env 的 `DEPLOY_HOST`，`config/deploy.yml` 经 ERB 读它）跑 `web` 单容器（Solid Queue 作 Puma 插件）加 PostgreSQL 18 accessory；
镜像在 Docker Hub `skipmaple/lowpass`；kamal-proxy 做 Let's Encrypt，域名 `lowpass.tech`。同一台机器上还有另一个 Kamal 应用与 lowpass
共用 kamal-proxy，按域名分流；它的库占着宿主机的 `127.0.0.1:5432`，所以 lowpass 的库不发布端口，应用走 docker 网络里的 `lowpass-db`。
配置在 `config/deploy.yml`，变量名在 `.kamal/secrets`，值只从跑 kamal 的那个 shell 读。本机手动部署时镜像在服务器上构建（`builder.remote`），不用模拟 x86；
CI 在 runner 上构建，见下面「CI 自动部署」。

### 首次部署

1. Docker Hub：Account settings → Personal access tokens，建一个 Read & Write 的令牌，作 `KAMAL_REGISTRY_PASSWORD`。
2. 数据库口令：`openssl rand -hex 24`，作 `POSTGRES_PASSWORD`（应用侧的 `PGPASSWORD` 取同一个值，`.kamal/secrets` 已写好）。
3. 变量放进仓库外的一个文件（例如 `~/.config/lowpass/deploy.env`），跑 kamal 前 `set -a; source ~/.config/lowpass/deploy.env; set +a`：
   `DEPLOY_HOST`（服务器 IP，`config/deploy.yml` 经 ERB 读它）、`KAMAL_REGISTRY_PASSWORD`、`POSTGRES_PASSWORD`、`BASE_URL=https://lowpass.tech`、`GOOGLE_CLIENT_ID/SECRET`、`GITHUB_CLIENT_ID/SECRET`、
   `ADMIN_EMAILS`，以及「告警」「推荐理由」「备份」三节列的变量；没用到的留空（备份在 production 下是必需的，没配会每天告警）。
4. Cloudflare：SSL/TLS 加密模式设「完全」；首次签证书前关掉「始终使用 HTTPS」，签完再开。橙云代理开着也行，
   Let's Encrypt 的 HTTP-01 校验会经 Cloudflare 转到源站的 80。
5. `bundle exec kamal setup`：服务器已有 Docker 与 kamal-proxy，这一步实际做的是起 accessory、在服务器上构建镜像并推到 Docker Hub、
   起 web 容器（入口先 `db:prepare` 建主库与队列库）、向 kamal-proxy 注册 `lowpass.tech` 并签证书。
6. 播种与索引：

   ```
   bundle exec kamal app exec --reuse "bin/rails db:seed"
   bundle exec kamal app exec --reuse "bin/rails search:rebuild"
   ```

7. 验证：登录页有两家按钮；白名单邮箱登录后报头有「管理」；设置页「发送测试告警」一分钟内收到；「立即备份」之后对象出现在桶里；
   填好模型配置后期页「重生成理由」；`curl https://lowpass.tech/health` 是 200。
8. 在外部拨测服务上监控 `https://lowpass.tech/health`（见「健康检查」）。

### 日常

- 发布：`bundle exec kamal deploy`（构建、推送、零停机切换）；回滚 `bundle exec kamal rollback <版本>`，版本是 git sha，`kamal app containers` 能看。
- 日志 `bundle exec kamal app logs -f`；控制台 `bundle exec kamal console`；数据库 `bundle exec kamal dbc`；代理 `bundle exec kamal proxy details`。
- 服务器上的落点：数据 `/root/lowpass-db/postgresql`（18；升级之前的 17 在 `/root/lowpass-db/data`，升级后留作回滚，确认无误再删），Kamal 记录 `/root/.kamal/apps/lowpass`。证书由 kamal-proxy 自动续。
- 备份：每天 03:00 自动加密上传到对象存储，状态看设置页「备份」一节，恢复步骤见「备份」。马上要一份：后台「立即备份」或
  `bundle exec kamal app exec --reuse "bin/rails backup:now"`。
- 服务器上的 accessory 永远别用 `kamal accessory remove`：它连数据目录一起删。换镜像、换挂载用 `kamal accessory reboot db`（只重建容器，宿主机目录不动）。

### 升级数据库大版本（17 → 18）

`config/deploy.yml` 的 accessory 已经是 `postgres:18`，但 `kamal deploy`（包括 CI 自动部署）不重启 accessory：升大版本要照下面的步骤
手动做一次。应用镜像里的客户端已是 18，对 17 的服务端照样能导出（备份不受影响）。停机几分钟，
避开 03:00 备份、06:00 到 06:20 的日刊生成与 09:00 的周刊检查。数据目录不跨大版本复用：18 用新目录，17 的旧目录原样留着回滚用。
2026-09-15（16 → 17）与 2026-09-28（17 → 18）用的都是这一套「导出 → 新目录重建 → 导回」。

18 起官方镜像换了数据布局：`PGDATA` 是 `/var/lib/postgresql/18/docker`，卷挂整个 `/var/lib/postgresql`
（`config/deploy.yml` 里是 `postgresql:/var/lib/postgresql`，宿主机上是 `/root/lowpass-db/postgresql`）。
以后再升大版本，新旧目录可以并排放在同一个挂载里。

在本机跑，checkout 已是合并后的 main，`set -a; source ~/.config/lowpass/deploy.env; set +a`：

```
# 0. 先要一份备份（配好了备份的话）
bundle exec kamal app exec --reuse "bin/rails backup:now"

# 1. 停应用，停机从这里开始，之后不会再有写入
bundle exec kamal app stop

# 2. 在 17 里导出主库，文件留在服务器上；队列库不用导，应用起来时 db:prepare 会重建
ssh root@$DEPLOY_HOST 'mkdir -p /root/lowpass-backups && docker exec lowpass-db pg_dump -U lowpass -Fc lowpass_production > /root/lowpass-backups/pg17-lowpass_production.dump && ls -lh /root/lowpass-backups'

# 3. 记下行数，恢复后对照
ssh root@$DEPLOY_HOST "docker exec lowpass-db psql -U lowpass lowpass_production -Atc \"select 'issues', count(*) from issues union all select 'items', count(*) from items union all select 'sources', count(*) from sources union all select 'users', count(*) from users\""

# 4. 换成 18：删掉旧容器、按新配置起一个，新目录里 initdb，并按 POSTGRES_DB 建好空的 lowpass_production；
#    /root/lowpass-db/data（17）原样不动
bundle exec kamal accessory reboot db
#    reboot 一返回容器就在跑，但头几秒是 initdb 和建库用的临时实例（只听 unix socket，pg_isready 这时也说就绪）：
#    这时导入会连不上、找不到库，或者导到一半被停掉。等日志里出现 init process complete 再连；打出 ready 再往下，
#    两分钟还不行就打出最后 20 行日志
ssh root@$DEPLOY_HOST 'for i in $(seq 120); do docker logs lowpass-db 2>&1 | grep -qE "init process complete|Skipping initialization" && docker exec lowpass-db pg_isready -q -U lowpass -d lowpass_production && { echo ready; exit 0; }; sleep 1; done; docker logs --tail 20 lowpass-db; exit 1'

# 5. 导回 18
ssh root@$DEPLOY_HOST 'docker exec -i lowpass-db pg_restore -U lowpass -d lowpass_production --no-owner --exit-on-error < /root/lowpass-backups/pg17-lowpass_production.dump'

# 6. 行数对照第 3 步，版本应是 18
ssh root@$DEPLOY_HOST "docker exec lowpass-db psql -U lowpass lowpass_production -Atc 'select version()'"

# 7. 起应用：入口的 db:prepare 在 18 上重建空的队列库；看日志、打开 /health
bundle exec kamal app start
bundle exec kamal app logs --lines 100
curl -s https://lowpass.tech/health
```

回滚（第 7 步之前发现问题）：把 `config/deploy.yml` 的 accessory 改回 `postgres:17` 与 `data:/var/lib/postgresql/data`，
`bundle exec kamal accessory reboot db`（17 起在原来的目录上），再 `bundle exec kamal app start`。第 7 步之后才回滚的话，
这期间写进 18 的内容会丢，先在 18 里 `pg_dump` 一份再退。确认一周无误，再删 `/root/lowpass-db/data` 与导出文件。

### CI 自动部署

`.github/workflows/deploy.yml`：main 上名为 CI 的工作流跑完且成功后自动 `kamal deploy`，部署的是那次 CI 测过的 sha；
Actions 页面的「Run workflow」可以手动重发。job 绑定 GitHub Environment「production」，密钥都在这个 Environment 的 secrets 里，
名字与 `.kamal/secrets` 一致，外加四项：`DEPLOY_HOST`、`DEPLOY_KNOWN_HOSTS`（见下）、`RAILS_MASTER_KEY`（job 把它写成 `config/master.key`）与 `SSH_PRIVATE_KEY`
（专用 deploy key，公钥在服务器 root 的 `authorized_keys`，注释 `lowpass-ci-deploy`）。
镜像在 runner 上构建（`deploy.yml` 看 `KAMAL_BUILD_LOCAL` 这个变量），层缓存在 GitHub Actions cache，服务器只拉镜像。
服务器地址与 host key 都不进仓库：Environment 里另有 `DEPLOY_HOST`（IP）与 `DEPLOY_KNOWN_HOSTS`（本机 `ssh-keyscan -t ed25519 $DEPLOY_HOST` 输出的那一行），服务器重装或换 key 时更新它们。

- 填或改 secrets（值不进仓库，本机的 env 文件整份导入；备份的五个 `BACKUP_*` 也在这份文件里）：
  `gh secret set -f ~/.config/lowpass/deploy.env --env production`（GitHub 拒绝以 `GITHUB_` 开头的 secret 名，
  所以 `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` 两项要另外以 `OAUTH_GITHUB_CLIENT_ID` / `OAUTH_GITHUB_CLIENT_SECRET` 的名字设，工作流里再映射回原名）；
  `gh secret set RAILS_MASTER_KEY --env production < config/master.key`；
  `gh secret set SSH_PRIVATE_KEY --env production < ~/.config/lowpass/deploy_key`。
- 换 deploy key：本机 `ssh-keygen -t ed25519 -C lowpass-ci-deploy -f ~/.config/lowpass/deploy_key`，
  公钥追加到服务器 `/root/.ssh/authorized_keys` 并删掉旧的那行，再 `gh secret set SSH_PRIVATE_KEY`。
- 要「部署前本人批准」：仓库 Settings → Environments → production 勾 Required reviewers，工作流不用改。
- 与本机手动 `kamal deploy` 互不冲突：Kamal 的锁保证同一时间只有一次部署；CI 里排队的部署不取消。
