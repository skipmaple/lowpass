# 开发环境

## 前置要求

- [mise](https://mise.jdx.dev/)：钉住 Ruby 与 Node 版本，见 `.mise.toml`。
- Docker：本地 PostgreSQL 以容器运行，见下文；不需要本机装 PostgreSQL 或 `psql`。
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
   `postgres:16` 容器，用户名与密码均为 `postgres`，只发布到 `127.0.0.1:5432`（默认口令不该
   跟着局域网走），然后轮询容器里的 `pg_isready`，最多等 30 秒。加 `--skip-server` 参数就整段
   跳过（`config/ci.rb` 的 Setup 步骤与 CI 里的 postgres service 自己管数据库）。
5. `bin/rails db:prepare`（加 `--reset` 参数则改为 `bin/rails db:reset`）。
6. 清理 `log/`、`tmp/`。

## 日常开发

```
bin/dev
```

用 [Foreman](https://github.com/ddollar/foreman) 按 `Procfile.dev` 同时起三个进程：Rails server
（3000 端口，`http://localhost:3000`）、Vite dev server，以及 `bin/jobs`（Solid Queue worker，带
`config/recurring.yml` 里每分钟一次的 `SchedulerTickJob`）。日刊到点生成、错过补跑、超时收尾、
每天检查一次周刊都靠这个 tick（`Scheduler#tick` 依次跑 `generate_daily_if_due`、
`finalize_stale_issues`、`check_weekly_if_due`、`cleanup_if_due`），本地想看效果就得让 jobs 进程
跑着，`log/development.log` 里每分钟一条。日刊生成、周刊检查的时间点读 `Setting`（键
`daily_time`、`weekly_time`），不是写死在代码里。

## 队列面板

```
http://localhost:3000/jobs
```

`mission_control-jobs` 只在开发环境挂载（见 `config/routes.rb`），能看到 Solid Queue 的队列、
待执行与失败的任务。这个 gem 默认打开 HTTP Basic Auth 且要求配置凭证，没配就直接拒绝访问；
P0 不往仓库里提交凭证，所以在 `config/environments/development.rb` 里把
`config.mission_control.jobs.http_basic_auth_enabled` 关掉了，只在开发环境生效。生产环境挂载
`/admin/jobs` 与管理员认证是 P2（见 `AGENTS.md`）。

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

手动操作容器：

```
docker start lowpass-postgres   # 启动
docker stop lowpass-postgres    # 停止
docker rm lowpass-postgres      # 删除，数据一并丢失
```

## 测试与 CI

```
bin/rails test          # 快速循环，不连网络
bin/rails test:system   # 无头 Chrome 里读一期日刊（test/system/reading_test.rb）
bin/ci                  # 合并门禁，见 config/ci.rb
```

`bin/ci` 依次跑：Setup（`bin/setup --skip-server`）、Style: Ruby（`bin/rubocop`）、Frontend: typecheck
（`npm run check`）、Frontend: audit（`npm audit --audit-level=high`）、Frontend: build（`npm run build`）、
Security: Gem audit（`bin/bundler-audit`）、Security: Brakeman code analysis、Security: Secrets
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
