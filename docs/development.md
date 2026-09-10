# 开发环境

## 前置要求

- [mise](https://mise.jdx.dev/)：钉住 Ruby 与 Node 版本，见 `.mise.toml`。
- Docker：本地 PostgreSQL 以容器运行，见下文；不需要本机装 PostgreSQL 或 `psql`。

## 首次搭建

```
bin/setup
```

幂等，可重复执行。做了什么：

1. `mise install --yes` 装好 `.mise.toml` 钉住的 Ruby 与 Node。
2. 把 Git 的 `core.hooksPath` 指到 `.githooks`（见下文「提交前检查」）。
3. `bundle install`、`npm install`。
4. 若本机 5432 端口没有服务在监听，启动（不存在则新建）名为 `lowpass-postgres` 的
   `postgres:16` 容器，用户名与密码均为 `postgres`，映射到 `127.0.0.1:5432`。
5. `bin/rails db:prepare`（加 `--reset` 参数则改为 `bin/rails db:reset`）。
6. 清理 `log/`、`tmp/`。

## 日常开发

```
bin/dev
```

用 [Foreman](https://github.com/ddollar/foreman) 按 `Procfile.dev` 同时起三个进程：Rails server（3000 端口）、
Vite dev server，以及 `bin/jobs`（Solid Queue worker，带 `config/recurring.yml` 里每分钟一次的 `SchedulerTickJob`）。
日刊到点生成、错过补跑、超时收尾都靠这个 tick，本地想看效果就得让 jobs 进程跑着，`log/development.log` 里每分钟一条。

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
bin/rails test   # 快速循环，不连网络
bin/ci           # 合并门禁，见 config/ci.rb：setup、rubocop、bundler-audit、brakeman、测试、seeds 回放
```

`bin/rails test` 超过 50 个测试后会按 CPU 核数 fork 出并行 worker。`config/database.yml` 里的 `gssencmode: disable`
是为了绕开 macOS 上预编译 pg gem 在 fork 后段错误的问题（表现为 worker 全部崩溃、命令挂起），别删；
想单进程跑就 `PARALLEL_WORKERS=1 bin/rails test`。

## 提交前检查

`bin/setup` 把 `core.hooksPath` 设为 `.githooks`；`.githooks/pre-commit` 对本次提交改动的 `.rb`
文件跑 `bin/rubocop --force-exclusion`，未改动 Ruby 文件时直接放行。
