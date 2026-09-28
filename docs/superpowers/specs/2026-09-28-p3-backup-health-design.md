# P3 运维：数据库备份与健康检查

日期：2026-09-28 · 状态：草案（产品负责人要求「把备份与健康检查做了」，并要求开发、CI 与生产统一到 PostgreSQL 18（§9）；需要选择的地方按 §8「默认决定」定，全部可推翻）
依据：PRD `docs/superpowers/specs/2026-09-08-mvp-prd.md` F-26（数据库每日备份）、N-5（健康检查端点返回数据库、搜索、最近一期距今时长）、N-6（每日备份保留 7 天，上线前恢复演练）、5.7（备份失败 · 严重）、7.8（备份保留 7 天）、10.3 上线清单（备份、观测两行）、11 风险「单人维护，长期无人值守」；ADR T3（每日 pg_dump 推到香港区域对象存储）、T4（内存预算）
前置：P2-③ 告警（`Alerts.backup_failed!` 的调用口、按日去重）

## 1. 范围

做：
- 每日加密备份：主库 `pg_dump` → AES-256-GCM 加密 → PUT 到 S3 兼容的对象存储；`backup_runs` 记每一次；失败走 `Alerts.backup_failed!`；后台设置页「备份」一节（状态、最近一次、立即备份）；`bin/rails backup:now`；不启动应用也能解密的 `script/decrypt_backup`；恢复步骤与演练记录写进 `docs/development.md`。
- 健康检查端点 `GET /health`：数据库、搜索、调度心跳、日刊是否按时、备份是否新鲜；全部正常 200，任一失败 503；给外部拨测用。
- PostgreSQL 18：开发容器、CI 的 postgres service 与生产 accessory 统一到 18，镜像里的客户端跟着换（§9）。

不做：
- 应用里列出、下载、删除备份。恢复时用对象存储的控制台或任意 S3 客户端取文件；7 天保留交给存储桶的生命周期规则。应用的密钥因此只需要写入权限（E4）。
- 队列库的备份（可以重建，丢的只是排队中的任务）。
- 外部拨测服务本身的开通与配置（产品负责人选服务，见 `docs/development.md`「健康检查」）。
- 健康检查失败时由应用自己发告警：检查存在的意义就是不依赖应用进程，通知由外部拨测发。
- 错误上报的订阅者：skipmaple/lowpass#42 单独做了（`Lowpass::ErrorLog`），这里只把健康检查的 `health`、备份的 `backup_run` 两个上下文键加进它的白名单，值都是应用自己生成的。

## 2. 备份

### 2.1 流程

1. `Scheduler#backup_if_due`：上海时间 03:00 之后、当天还没备份过（`Setting` 的 `backed_up_on`）就 `BackupRun.create_later(trigger: "scheduled")`，然后记账；错过那一分钟当天补跑（同 `cleanup_if_due`）。只在「应该有备份」时运行（E8）。
2. `BackupRun.create_later` 建一条 `queued` 记录并入队 `BackupJob`；入队失败就删掉这条记录再抛出，下一分钟的 tick 重来。
3. `BackupJob#perform` → `run.perform_now(attempt:)`：
   - 标记 `running`；配置不全就直接失败（`未配置备份：…`）。
   - 在 `tmp/` 下的临时目录里：`Backup::Dump.write`（`pg_dump --format=custom --no-password`，跳过 `solid_cache_entries`、`solid_cable_messages` 两张表的数据；连接参数取 `ActiveRecord` 的主库配置，经环境变量传给子进程，口令不进命令行；10 分钟超时，超时先 TERM 再 KILL）。
   - `Lowpass::BackupCipher.encrypt`（§2.3）。
   - `Backup::Storage.put(对象名, 文件)`（§2.4）。对象名是 `<库名>-<UTC 时间戳>.dump.enc`，如 `lowpass_production-20260928T190000Z.dump.enc`。
   - 成功：`succeeded`，记大小、对象名、耗时。失败：`failed`，记错误摘要（首行，200 字）并抛出。临时目录无论成败都删掉。
4. 失败分类（E7）：上传遇到 5xx、网络错误、超时算暂时性（`Backup::Transient`），job 重试 2 次，间隔 2 分钟、10 分钟，等待期间记录回到 `queued`；其余都是终态（`Backup::Error`）：`pg_dump` 失败或超时、上传 4xx（包括 403 与 429，按仓库不变量不追加请求）、配置缺失。终态或重试耗尽时调 `Alerts.backup_failed!(摘要)`（严重，全局按日去重；B8 没有「已恢复」），再抛出，让队列面板看得见。
5. 同时只允许一份备份在跑（`limits_concurrency`，键 `backup`）。

### 2.2 `backup_runs`

| 列 | 类型 | 说明 |
|---|---|---|
| id | string(25) | UUIDv7 base36 |
| trigger | string(10) | CHECK：`scheduled` `manual` |
| status | string(10) | CHECK：`queued` `running` `succeeded` `failed` |
| attempts | integer 默认 0 | 已经跑过几次（含重试） |
| started_at / finished_at | datetime null | 最近一次尝试的开始、结束 |
| duration_ms | integer null | 成功那次的耗时 |
| size_bytes | bigint null | 加密后的文件大小 |
| object_key | string(255) null | 存储里的对象名 |
| error_summary | string(200) null | 最近一次失败的原因 |
| created_at / updated_at | datetime | |

索引 `created_at`（清理与「最近一次」）。保留 30 天，`BackupRun.cleanup` 挂进 `Scheduler#cleanup_if_due`。`queued` / `running` 超过 30 分钟没有动静算「未完成」：不再挡「立即备份」，页面上也照实写（进程在备份途中被杀、job 丢了，都会留下这样的记录）。

### 2.3 加密格式（`lib/lowpass/backup_cipher.rb`）

AES-256-GCM，按 1 MB 分块流式加解密。文件依次是：`LPBK`（4 字节）、版本 `1`（1 字节）、密钥指纹（密钥 SHA-256 的前 8 字节）、IV（12 字节）、密文、认证标签（16 字节）；前三项作为附加认证数据。解密先比对指纹，对不上就直接说「备份是用指纹 xxxx 的密钥加密的」；标签校验不过（文件被截断、被改）就报错，并删掉写了一半的输出。这个文件只依赖 Ruby 标准库：`script/decrypt_backup` 直接 `require_relative` 它，恢复时不需要启动应用、不需要连数据库。

密钥 `BACKUP_ENCRYPTION_KEY` 是 64 位十六进制（`openssl rand -hex 32`）。它丢了，备份就解不开，所以除了服务器环境，还要在密码管理器里另存一份。

### 2.4 存储（`Backup::Storage`）

- 协议：S3 兼容的 `PutObject`，AWS Signature V4（`aws-sigv4` gem，它只是签名库，不是 SDK）。阿里云 OSS、Cloudflare R2、AWS S3、Backblaze B2、MinIO 都认。
- 地址：`BACKUP_BUCKET_URL` 是对象的上一级，可以带前缀路径。虚拟主机式写 `https://<桶>.<endpoint>/<前缀>`，路径式写 `https://<endpoint>/<桶>/<前缀>`。对象地址就是它后面接 `/<对象名>`，所以两种写法不用再加一个开关。只接受 https；`localhost` / `127.0.0.1` 的 http 也行（本机演练用，同模型端点的规则）。
- 请求：`Content-MD5` 与 `x-amz-content-sha256` 都按文件实际内容算，由存储端校验上传的完整性；请求体从文件流式读取；连接 10 秒、写 300 秒、读 60 秒超时；`max_retries = 0`（Net::HTTP 默认会对 PUT 自动重试一次）；不跟重定向。
- 地址由运维在环境里配，是可信输入，不经 surfguard，与告警 webhook、模型端点同一类（AGENTS.md 的明示例外）。
- 应用只需要这个桶（或前缀）的 `PutObject` 权限。

### 2.5 配置（只从环境读，`Backup::Config`）

| 变量 | 说明 |
|---|---|
| `BACKUP_BUCKET_URL` | 见 §2.4 |
| `BACKUP_REGION` | 签名用的区域：R2 填 `auto`，AWS 填桶所在区域；阿里云 OSS 按其 S3 兼容文档填（形如 `oss-cn-hongkong`） |
| `BACKUP_ACCESS_KEY_ID` / `BACKUP_SECRET_ACCESS_KEY` | 只有写入权限的密钥 |
| `BACKUP_ENCRYPTION_KEY` | 见 §2.3 |

空串等于没配（Kamal 对没值的变量注入空串）。五项齐全且合法才算已配置。配了一部分、或者值不合法，启动时写一条警告，页面列出问题，当天的备份记失败并告警。

### 2.6 后台「备份」一节（`/admin/settings#backup`）

- 键值行：存储（主机与路径，不含密钥）、加密密钥（指纹：密钥 SHA-256 的前 8 字节，16 位十六进制，与文件头、解密报错里的是同一串；或「未配置」）、最近一次（时间 · 结果 · 大小 · 用时，或失败原因）、最近成功（时间；最近一次就是成功的那次时不重复画）。
- 「立即备份」按钮：`POST /admin/backup`；未配置、或者已有备份在进行时按钮禁用，服务端也照样拒绝；限流每用户每分钟 5 次；成功入队记审计 `backup.create`。
- 有 `queued` / `running` 的记录时，每 5 秒部分刷新这一节（`usePolling`）。
- 说明句：「每天 03:00 自动备份；保留天数由存储桶的生命周期规则决定。」配置问题逐条列出。
- 「部署配置帮助」补上 `BACKUP_*` 五个变量与健康检查地址。

## 3. 健康检查 `GET /health`

- 控制器继承 `ActionController::Base`，与 Rails 自带的 `/up` 同款：不走登录墙、Inertia、浏览器版本检查。只返回状态，不返回任何内容，所以 D1（登录后可读）不受影响。`/up` 不动，仍给 kamal-proxy。
- 限流：按 IP 每分钟 30 次，计数放进程内的内存存储。放 Solid Cache 的话，数据库挂了限流会先 500，拨测就拿不到那份 JSON。
- 检查项（E12）：

| 检查 | 通过条件 | 附带信息 |
|---|---|---|
| `database` | `SELECT 1` | |
| `search` | 固定探测查询（`lowpass 日刊`，覆盖 trigram 与中文子串两条路径）在 1 秒内跑完；不计入 B5 的搜索连续失败计数 | `latency_ms` |
| `scheduler` | tick 心跳（每次 tick 先写 `Setting` 的 `ticked_at`）不超过 5 分钟 | `ticked_at`，Solid Queue 进程心跳 `queue_heartbeat_at`（只做诊断：tick 停了而进程心跳还在，说明 tick 本身出错；两者都停，说明 Solid Queue 停了） |
| `daily_issue` | 生成时间过后 30 分钟起，当日期必须存在；此前只要求昨日期存在 | `latest`、`expected`、最近一期发布时间与距今分钟数（N-5） |
| `backup` | 「应该有备份」时（E8）：有过任何备份记录，就要求最近一次成功不超过 50 小时，一次都没成功过则从第一条记录起算。一条记录都没有不判（刚部署、还没到 03:00） | `last_succeeded_at` |

- 返回：`{ status: "ok" | "fail", checked_at, checks: { database: "ok", … }, scheduler: {…}, daily_issue: {…}, search: {…}, backup: {…} }`。不应检查的项写 `skipped`。任一 `fail` 就返回 503。不写异常信息（里面可能有内部主机名），异常只 `Rails.error.report`。

## 4. 现有代码的改动点

- `Scheduler#tick`：第一步写心跳，最后一步 `backup_if_due`；`cleanup_if_due` 加 `BackupRun.cleanup`。`Setting::DEFAULTS` 加 `backed_up_on`、`ticked_at`。
- `Search::Runner.probe`：跑固定查询，不经 `Alerts.search_status`。
- `Admin::SettingsController#show` 加 `backup: Backup::Status.props`。
- `Dockerfile`：运行时从 PostgreSQL 官方 APT 源（PGDG）装 `postgresql-client-18`。bookworm 自带的是 15，而数据库是 18（§9），`pg_dump` 遇到比自己新的服务端会拒绝导出。源的签名密钥用 Debian 的 `postgresql-common` 包里带的那一份（`apt.postgresql.org.sh -y` 写源并 `apt-get update`），构建时不另外下载密钥；核对过这份密钥能验过当前 `bookworm-pgdg` 仓库的签名。
- `config/deploy.yml`、`.kamal/secrets`、`.github/workflows/deploy.yml` 加五个 `BACKUP_*`，全部走 secret。
- `config/initializers/backup.rb`：启动时把配置问题写进日志（test 不写）。

## 5. 测试

- 加密：往返（跨块、空文件）、密钥不对报指纹、密文被改或被截断报错且不留半截文件、魔数与版本不对报错。
- 配置：空串等于没配、五项缺一、地址非 https、本机 http、密钥格式；页面属性里不出现任何密钥。
- 存储（WebMock）：签名头的形状（`AWS4-HMAC-SHA256 Credential=<id>/<日期>/<区域>/s3/aws4_request`）、`x-amz-content-sha256` 与 `Content-MD5` 等于文件实际摘要、请求体就是文件、虚拟主机式与路径式地址、403 / 429 终态并带 S3 错误码、5xx 与超时是暂时性。签名本身是否被真实存储端接受，由 §6 的演练验证（rclone 的 S3 服务端会校验 SigV4）。
- `pg_dump` 执行：用一个假的 `pg_dump` 脚本代替真命令，覆盖成功（经环境变量拿到连接参数）、失败带 stderr 首行、超时被杀、命令不存在。
- `BackupRun`：成功与失败记账、未配置直接失败、对象名、清理、「未完成」判定、`create_later` 入队失败时删记录。
- `BackupJob`：暂时性错误重试并回到 `queued`，耗尽后告警；终态错误立即告警；成功不告警。
- `Scheduler`：心跳；`backup_if_due` 到点一天一次、错过补跑、不需要备份时什么都不做；清理。
- `Health`：每一项的通过与失败、边界（生成时间 + 30 分钟、5 分钟、50 小时）、首次部署不误报。
- 控制器：`/health` 不登录可访问、200 / 503 与 JSON 形状、限流；`POST /admin/backup` 的四种结果、成员 403、限流；设置页带 `backup`。
- 前端（Vitest）：「备份」一节的几种状态、按钮禁用、POST 路径。
- 全部不碰网络、不跑真的 `pg_dump`：CI 的 runner 与 postgres service 版本对不上，真命令会失败。

## 6. 恢复与演练

步骤写进 `docs/development.md`「备份」：从存储取回对象 → `script/decrypt_backup` 解密（校验标签）→ `pg_restore --no-owner --no-privileges` 恢复到一个新库 → 核对主要表的行数 →（真恢复时）先只起数据库、恢复、再起应用。

本期在本机做过一次端到端演练（2026-09-28，PostgreSQL 18.6）：开发库灌入样本数据（4 个源、3 期、88 条），经 `rclone serve s3` 上传了 84.1 KB。这个服务端真的校验 SigV4：换一把错的 secret 再传，得到 403 `SignatureDoesNotMatch`。取回之后用 `ruby --disable-gems script/decrypt_backup` 解密，`pg_restore --exit-on-error` 恢复到新库，各表行数一致，`pg_trgm` 在；应用连上恢复出来的库，搜索正常返回。生产环境的首次演练要等存储与密钥配好，由产品负责人照步骤做一次并记录（上线清单 N-6）。

## 7. 文案（进 PRD 附录 B，v0.3.17）

| 位置 | 文案 |
|---|---|
| 备份状态 | 存储 · 加密密钥 · 最近一次 · 最近成功 · 未配置 · 配置不完整：{问题} · 还没有备份 · {时间} · 成功 · {大小} · 用时 {n} 秒 · {时间} · 失败：{原因} · 进行中 · 排队 · 未完成 · 指纹 {指纹} · 每天 03:00 自动备份；保留天数由存储桶的生命周期规则决定。 |
| 立即备份 | 立即备份 · 备份中… · 已开始备份 · 备份未配置 · 已有备份在进行 · 备份没能入队 · 操作过于频繁，请稍后再试。 · 备份未能开始，请重试 · 未配置备份存储，无法立即备份。 |
| 备份失败摘要 | 未配置备份：{问题} · pg_dump 失败：{原因} · pg_dump 超时（10 分钟） · 上传失败（{状态码}）：{错误码} · 上传没有完成：{原因} |

## 8. 默认决定（代理定，可推翻）

| 编号 | 决定 | 理由 |
|---|---|---|
| E1 | 备份跑在应用进程里（tick 入队 job），不另起备份容器 | 不新增常驻进程，ADR T4 的内存预算不变；失败能直接走告警门面，后台能直接读到记录 |
| E2 | 存储用 S3 兼容协议加 SigV4，不绑厂商 | T3 写的是「香港区域对象存储」，没定厂商；OSS、R2、S3 都认这一套 |
| E3 | 应用侧加密（AES-256-GCM），不只依赖存储端加密 | 备份里有用户邮箱；桶的密钥泄露或桶被误设为公开时，文件仍然读不了 |
| E4 | 应用只写不读、不删；保留期交给生命周期规则 | 最小权限：应用被攻破也拿不到历史备份、删不掉它们；保留规则在存储端一处配置 |
| E5 | 03:00（上海）一天一次，按天记账、当天补跑 | 在 04:00 清理与 06:00 日刊之前；与现有两项每日任务同一套写法 |
| E6 | 只备主库，跳过缓存与 Cable 两张表的数据 | 队列库可以重建；缓存与 Cable 消息恢复后没有意义 |
| E7 | 上传的 5xx 与网络错误重试 2 次（2 分钟、10 分钟），其余立即算失败 | 暂时性故障值得再试；403 / 429 不追加请求（仓库不变量）；pg_dump 失败重试也不会变 |
| E8 | production 下「应该有备份」：没配或配不全，当天记一次失败并告警；其他环境一个 `BACKUP_*` 都没配就跳过 | 没配就是 N-6 不达标，不能静默；开发机上不该每天报错 |
| E9 | 记录保留 30 天 | 与抓取记录同档 |
| E10 | 后台可「立即备份」 | 配好之后马上能验证，不用等到 03:00；做高风险操作（例如数据库升大版本）之前也用得上 |
| E11 | 健康检查放在独立的 `/health`，`/up` 不动 | `/up` 是 kamal-proxy 切流量用的，只该回答「应用起来没有」；把日刊迟到也算进去，会导致部署失败 |
| E12 | 阈值：tick 5 分钟、日刊为生成时间后 30 分钟、备份 50 小时 | 5 分钟能跨过一次部署重启；30 分钟与「日刊未生成」告警（B4）一致；50 小时容得下失败一天、第二天补上 |
| E13 | 端点公开、只给状态，不要令牌 | 与 `/up` 同级，拨测服务不用配密钥；返回里没有内容，也没有异常信息 |
| E14 | 解密工具只依赖标准库 | 服务器整个没了的时候，也能在任何一台装了 Ruby 的机器上解开 |
| E15 | 生产挂新目录 `/var/lib/postgresql`，17 的旧目录留着 | 18 的官方镜像只认新布局；旧目录不动，回滚就是改回配置再 reboot |

## 9. PostgreSQL 18

产品负责人要求开发、CI 与生产统一到 18（2026-09-28）。之前三处各不相同：`bin/setup` 建的是 16，CI 的 service 跟着 `latest` 走，生产 accessory 是 17。

- 开发：`bin/setup` 建 `postgres:18` 的容器。已有容器是别的镜像时照样启动，但提醒一句，不替人删；换法写在 `docs/development.md`「数据库」。
- CI：两个 job 的 postgres service 钉 `postgres:18`，不跟着 `latest` 漂。
- 生产：`config/deploy.yml` 的 accessory 改为 `postgres:18`。18 起官方镜像的 `PGDATA` 是 `/var/lib/postgresql/18/docker`、卷挂整个 `/var/lib/postgresql`（从 Docker Hub 的镜像配置核对过），所以挂载改成 `postgresql:/var/lib/postgresql`，宿主机上是 `/root/lowpass-db/postgresql`。`kamal deploy`（包括 CI 自动部署）不重启 accessory，合并后线上仍是 17，要照 `docs/development.md`「升级数据库大版本」手动切一次：停应用、在 17 里导出主库、`kamal accessory reboot db`、导回 18、核对行数、起应用；17 的旧目录留作回滚。应用镜像里的客户端是 18，切换之前对 17 的服务端也能导出，备份不受影响。
- 本机在 18.6 上从全部迁移重建库，导出的 `db/schema.rb` 与 17 导出的逐字一致；全部测试在 18 上通过。
