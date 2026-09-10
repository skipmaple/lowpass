# P0 抓取与阅读 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 lowpass 在本地跑起来：每天 06:00 自动把 Hacker News、GitHub Trending、Hackaday 装订成一期不可变的日刊，每天 09:00 检查阮一峰周刊与通用 RSS 周刊源并装订成周刊，读者能在日刊页、周刊页与两份归档里读到；P0 不含登录、搜索、后台与推荐理由。

**Architecture:** Rails 8.1 单体，vanilla Rails（STYLE.md）：适配器在模型层输出统一的条目契约，期生成器只装订条目；Solid Queue 跑抓取任务与每分钟一次的调度 tick；Inertia + React + TypeScript 渲染四个阅读页面；PostgreSQL 单库，主键是 UUIDv7 的 25 字符 base36 字符串。

**Tech Stack:** Ruby 3.4.8、Rails 8.1（`rails new` 自带 Solid Queue / Cache / Cable、Kamal、Thruster、bin/ci）、PostgreSQL 16（开发用 Docker 容器）、inertia_rails + vite_rails + React 19 + TypeScript + Tailwind v4 + shadcn/ui、Minitest + fixtures + WebMock、rubocop-rails-omakase、brakeman、bundler-audit、mise 管 Ruby 与 Node、surfguard 做出站 SSRF 检查、rss 与 nokogiri 做解析。

**Spec:** `docs/superpowers/specs/2026-09-08-mvp-prd.md`（v0.3.6，P0 范围见 10.1 与 10.2）；决议 `docs/adr/0001-mvp-tech-stack.md`（T1 到 T12）；默认值 `AGENTS.md`；风格 `STYLE.md`；界面令牌 `.claude/skills/lowpass-design-taste/reference/lowpass-tokens.md`。

## Global Constraints

- 期发布后不可变（R-1.4）；修订只由"某期某源"重抓整栏替换并写 `revised_at`（R-1.5）。
- 周期键：日刊 `YYYY-MM-DD`，周刊 `YYYY-Www`（ISO 8601，周一起）；计算与展示用 `Asia/Shanghai`，存储 UTC（3.2）。
- 调度：每分钟一次 tick 读数据库里的生成时间；日刊默认 `06:00`，周刊检查默认 `09:00`；错过的调度补跑并标记 `generated_late`（R-1.1、R-1.7、ADR T2）。
- 抓取：单源单次超时 60 秒；每次调度最多 3 次尝试，间隔 30 秒、120 秒；期级总超时 20 分钟；429 / 403 按失败处理不追加重试；User-Agent 含产品名与站点地址（R-1.2、7.6）。
- 发布条件：至少一个源成功则 `published`，全部失败则 `empty`（R-1.3）；每源默认取前 10 条（D15）。
- 条目契约（7.2）：title ≤ 300、url ≤ 2048 且仅 http(s)、url_hash 为归一化地址的 SHA-256、summary ≤ 500、section ≤ 100、author ≤ 100；唯一键 `(source_id, issue_id, url_hash)`。
- 地址归一化（7.4）与摘要清洗（7.5）按 PRD 原文实现。
- 阮一峰解析（R-2.3）：一级标题取期号与主题；二级标题为板块；条目少于 5 条降级为整期一条并告警（P0 只记录，告警渠道在 P2）。
- 主键：所有表 UUIDv7 base36 25 字符字符串列，不用 PostgreSQL 的 uuid 类型（ADR T9）；fixture 的 id 比运行时记录老。
- 列长度显式写 `limit` 并加 CHECK 约束；唯一性放数据库（AGENTS.md）。
- 测试不碰网络：WebMock 全局禁用外连，源站样本放 `test/fixtures/files/`。
- 中文一律霞鹜文楷，拉丁内容 Newsreader，数字 Maple Mono，Bodoni 只在报头；颜色只用六个令牌；无圆角、无阴影、无卡片底色。
- 提交信息末尾加 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`；本机 git 用 `git --no-pager`，提交加 `-c commit.gpgsign=false`。

---

## 文件结构

| 路径 | 职责 |
|---|---|
| `lib/lowpass/uuid.rb` | UUIDv7 生成与 base36 编解码 |
| `app/models/application_record.rb` | 主键默认值 |
| `app/models/period_key.rb` | 日刊与周刊周期键的唯一计算处 |
| `app/models/url_normalizer.rb`、`app/models/summary_cleaner.rb` | 7.4 与 7.5 |
| `app/models/source.rb`、`app/models/source/*.rb` | 信息源、适配器解析、健康度 |
| `app/models/adapters/{entry,http,base,hacker_news,github_trending,rss,ruanyf_weekly}.rb` | 条目契约、出站 HTTP、四个适配器 |
| `app/models/issue.rb`、`app/models/issue/{daily,weekly,finalization}.rb` | 期、生成、装订、发布 |
| `app/models/item.rb` | 条目 |
| `app/models/fetch_run.rb` | 抓取记录与清理 |
| `app/models/setting.rb` | 生成时间等键值设置 |
| `app/jobs/{fetch_source_job,scheduler_tick_job,weekly_check_job}.rb` | 浅 job，逻辑在模型 |
| `config/recurring.yml` | 每分钟 tick、每日清理 |
| `app/controllers/{daily_issues,weekly_issues}_controller.rb` | Inertia 页面 |
| `app/frontend/pages/{Daily,Weekly}/*.tsx`、`app/frontend/components/*.tsx`、`app/frontend/entrypoints/*.css` | 页面、报头页脚、令牌与字体 |
| `test/models/*_test.rb`、`test/jobs/*_test.rb`、`test/controllers/*_test.rb`、`test/fixtures/*.yml`、`test/fixtures/files/**` | 测试与样本 |
| `bin/setup`、`bin/dev`、`bin/ci`、`config/ci.rb`、`.mise.toml`、`.githooks/pre-commit`、`script/capture_samples` | 开发环境与门禁 |

---

### Task 1: 仓库骨架与工具链

**Files:**
- Create: `.mise.toml`、`.ruby-version`、`Gemfile`（`rails new` 生成后改）、`config/database.yml`、`Procfile.dev`、`bin/setup`、`bin/dev`、`.githooks/pre-commit`、`.rubocop.yml`、`docs/development.md`
- Modify: `.gitignore`

**Interfaces:**
- Produces: 可运行的空 Rails 应用；`bin/setup` 幂等；`bin/rails test` 通过（0 个测试）；`bin/ci` 可跑。

- [ ] **Step 1: 钉工具版本**

`.mise.toml`：

```toml
[tools]
ruby = "3.4.8"
node = "24"
```

运行：`mise install` 并确认 `ruby -v` 输出 3.4.8。

- [ ] **Step 2: 生成应用**

在仓库根目录（已有 docs/ 与 AGENTS.md）执行：

```bash
gem install rails -v "~> 8.1"
rails new . --name=lowpass --database=postgresql --skip-hotwire --skip-jbuilder --skip-javascript --skip-docker --force
```

`--force` 只覆盖 Rails 自己的文件；确认 `git --no-pager status` 里 docs/、AGENTS.md、STYLE.md、.claude/ 未被改动。`--skip-docker` 是因为 Dockerfile 在 P3 按 fizzy 的样子手写。

- [ ] **Step 3: Gemfile 补齐**

```ruby
# Gemfile 追加
gem "inertia_rails", "~> 3.6"
gem "vite_rails", "~> 3.0"
gem "rss"                     # Ruby 3.4 起是 bundled gem，必须显式声明
gem "nokogiri"
gem "surfguard", github: "basecamp/surfguard"
gem "mission_control-jobs"

group :development, :test do
  gem "bundler-audit", require: false
  gem "webmock"
  gem "mocha"
end
```

运行 `bundle install`。

- [ ] **Step 4: 数据库配置指向 Docker 里的 PostgreSQL**

`config/database.yml`：

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  host: <%= ENV.fetch("PGHOST", "127.0.0.1") %>
  port: <%= ENV.fetch("PGPORT", "5432") %>
  username: <%= ENV.fetch("PGUSER", "postgres") %>
  password: <%= ENV.fetch("PGPASSWORD", "postgres") %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>

development:
  <<: *default
  database: lowpass_development

test:
  <<: *default
  database: lowpass_test

production:
  primary: &primary_production
    <<: *default
    database: lowpass_production
    url: <%= ENV["DATABASE_URL"] %>
  queue:
    <<: *primary_production
    database: lowpass_production_queue
    migrations_paths: db/queue_migrate
```

- [ ] **Step 5: bin/setup 幂等**

`bin/setup`（替换生成的版本）：

```bash
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."

step() { echo "▸ $1"; shift; "$@"; echo; }

step "Installing Ruby and Node via mise" mise install --yes
eval "$(mise hook-env -s bash)"

step "Installing Git pre-commit hook" git config core.hooksPath .githooks

step "Installing RubyGems" bundle install
step "Installing npm packages" npm install

if ! nc -z 127.0.0.1 5432 2>/dev/null; then
  if docker ps -aq -f name=lowpass-postgres | grep -q .; then
    step "Starting PostgreSQL" docker start lowpass-postgres
  else
    step "Creating PostgreSQL container" docker run -d --name lowpass-postgres \
      -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16
  fi
  sleep 3
fi

if [[ "$*" == *--reset* ]]; then
  step "Resetting the database" bin/rails db:reset
else
  step "Preparing the database" bin/rails db:prepare
fi

step "Cleaning logs and tempfiles" bin/rails log:clear tmp:clear
echo "✓ Done"
```

`chmod +x bin/setup`。

- [ ] **Step 6: bin/dev 与 Procfile.dev**

`Procfile.dev`：

```
web: bin/rails server -p 3000
vite: bin/vite dev
```

`bin/dev`：

```bash
#!/usr/bin/env bash
cd "$(dirname "$0")/.."
export SOLID_QUEUE_IN_PUMA=true
command -v foreman >/dev/null || gem install foreman
exec foreman start -f Procfile.dev "$@"
```

- [ ] **Step 7: 风格与钩子**

`.rubocop.yml`：

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }
AllCops:
  Exclude:
    - "db/migrate/**/*"
    - "db/schema.rb"
    - "node_modules/**/*"
Style/NegatedIf:
  Enabled: true
Style/NegatedUnless:
  Enabled: true
```

`.githooks/pre-commit`：

```bash
#!/bin/sh
files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.rb$')
[ -z "$files" ] && exit 0
exec bin/rubocop --force-exclusion $files
```

`chmod +x .githooks/pre-commit`。

- [ ] **Step 8: 验证**

运行：`bin/setup && bin/rails test && bin/ci`
预期：setup 全绿；`0 runs, 0 assertions`；`bin/ci` 的 rubocop、brakeman、bundler-audit 步骤通过（Rails 8.1 生成的 `config/ci.rb` 已含这些步骤）。

- [ ] **Step 9: 提交**

```bash
git add -A && git -c commit.gpgsign=false commit -m "chore: Rails 8.1 骨架、mise、Docker PostgreSQL、bin/setup 与 bin/dev

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: UUIDv7 base36 主键

**Files:**
- Create: `lib/lowpass/uuid.rb`、`config/initializers/uuid.rb`、`test/lib/lowpass/uuid_test.rb`
- Modify: `app/models/application_record.rb`、`test/test_helper.rb`

**Interfaces:**
- Produces: `Lowpass::Uuid.generate -> String(25)`、`Lowpass::Uuid.hex_to_base36(hex)`、`Lowpass::Uuid.base36_to_hex(b36)`；`ApplicationRecord` 建记录时自动填 id；fixture 用 `ActiveRecord::FixtureSet.identify(label, :uuid)` 得到比运行时记录老的 id。

- [ ] **Step 1: 失败测试**

`test/lib/lowpass/uuid_test.rb`：

```ruby
require "test_helper"

class Lowpass::UuidTest < ActiveSupport::TestCase
  test "generate 返回 25 位 base36" do
    id = Lowpass::Uuid.generate
    assert_equal 25, id.length
    assert_match(/\A[0-9a-z]{25}\z/, id)
  end

  test "先生成的 id 排在后生成的前面" do
    a = Lowpass::Uuid.generate
    sleep 0.002
    b = Lowpass::Uuid.generate
    assert a < b
  end

  test "hex 与 base36 往返一致" do
    hex = "0190f3c2a1b74e1a8c3d1e2f3a4b5c6d"
    assert_equal hex, Lowpass::Uuid.base36_to_hex(Lowpass::Uuid.hex_to_base36(hex))
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

`bin/rails test test/lib/lowpass/uuid_test.rb`，预期 `NameError: uninitialized constant Lowpass::Uuid`。

- [ ] **Step 3: 实现**

`lib/lowpass/uuid.rb`：

```ruby
module Lowpass
  module Uuid
    BASE36_LENGTH = 25 # 36^25 > 2^128

    class << self
      def generate
        hex_to_base36(SecureRandom.uuid_v7.delete("-"))
      end

      def hex_to_base36(hex)
        hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
      end

      def base36_to_hex(base36)
        base36.to_s.to_i(36).to_s(16).rjust(32, "0")
      end

      # 给 fixture 用：按标签生成确定且排在过去的 UUIDv7
      def for_fixture(label)
        fixture_int = Zlib.crc32("fixtures/#{label}") % (2**30 - 1)
        time = Time.utc(2024, 1, 1) + (fixture_int / 1000.0)
        with_timestamp(time, label)
      end

      def with_timestamp(time, seed)
        ms = (time.to_f * 1000)
        ts = ms.to_i
        bytes = 6.times.map { |i| (ts >> (40 - 8 * i)) & 0xff }
        sub = ((ms - ts) * 4096).to_i & 0xfff
        bytes << (((sub >> 8) & 0x0f) | 0x70) << (sub & 0xff)
        rand_b = Digest::MD5.hexdigest(seed)[3...19].to_i(16) & ((2**62) - 1)
        bytes << (((rand_b >> 56) & 0x3f) | 0x80)
        7.times { |i| bytes << ((rand_b >> (48 - 8 * i)) & 0xff) }
        hex_to_base36(bytes.pack("C*").unpack1("H*"))
      end
    end
  end
end
```

`config/initializers/uuid.rb`：

```ruby
require "lowpass/uuid"
```

`app/models/application_record.rb`：

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_create { self.id ||= Lowpass::Uuid.generate }
end
```

`test/test_helper.rb` 追加（在 `require "rails/test_help"` 之后）：

```ruby
require "webmock/minitest"
require "mocha/minitest"
WebMock.disable_net_connect!(allow_localhost: true)

module FixtureUuids
  extend ActiveSupport::Concern
  class_methods do
    def identify(label, column_type = :integer)
      return super unless column_type.in?([ :uuid, :string ])
      Lowpass::Uuid.for_fixture(label)
    end
  end
end
ActiveSupport.on_load(:active_record_fixture_set) { prepend FixtureUuids }

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  fixtures :all
  include ActiveJob::TestHelper
end
```

- [ ] **Step 4: 跑测试确认通过**

`bin/rails test test/lib/lowpass/uuid_test.rb`，预期 3 runs, 0 failures。

- [ ] **Step 5: 提交**

```bash
git add lib/lowpass/uuid.rb config/initializers/uuid.rb app/models/application_record.rb test/test_helper.rb test/lib && git -c commit.gpgsign=false commit -m "feat: UUIDv7 base36 主键与 fixture id 生成

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: 周期键

**Files:**
- Create: `app/models/period_key.rb`、`test/models/period_key_test.rb`

**Interfaces:**
- Produces: `PeriodKey.daily(time) -> "YYYY-MM-DD"`、`PeriodKey.weekly(time) -> "YYYY-Www"`、`PeriodKey.today`、`PeriodKey.this_week`、`PeriodKey.date_of(daily_key) -> Date`、`PeriodKey.week_range(weekly_key) -> Range<Date>`。全站唯一的周期键计算处。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class PeriodKeyTest < ActiveSupport::TestCase
  test "日刊按上海时区的自然日" do
    assert_equal "2026-09-08", PeriodKey.daily(Time.utc(2026, 9, 8, 15, 59))   # 上海 23:59
    assert_equal "2026-09-09", PeriodKey.daily(Time.utc(2026, 9, 8, 16, 0))    # 上海 00:00
  end

  test "服务器时区不是上海也不影响" do
    Time.use_zone("America/New_York") do
      assert_equal "2026-09-09", PeriodKey.daily(Time.utc(2026, 9, 8, 16, 0))
    end
  end

  test "周刊按 ISO 周，周一起" do
    assert_equal "2026-W36", PeriodKey.weekly(Time.utc(2026, 8, 30, 20, 0))   # 上海 8月31日 周一 04:00
    assert_equal "2026-W35", PeriodKey.weekly(Time.utc(2026, 8, 30, 15, 0))   # 上海 8月30日 周日 23:00
  end

  test "周范围与日期反解" do
    assert_equal Date.new(2026, 8, 31)..Date.new(2026, 9, 6), PeriodKey.week_range("2026-W36")
    assert_equal Date.new(2026, 9, 8), PeriodKey.date_of("2026-09-08")
  end
end
```

- [ ] **Step 2: 跑测试确认失败**（`NameError`）

- [ ] **Step 3: 实现**

```ruby
class PeriodKey
  ZONE = "Asia/Shanghai"
  DAILY = /\A\d{4}-\d{2}-\d{2}\z/
  WEEKLY = /\A\d{4}-W\d{2}\z/

  class << self
    def daily(time = Time.current)
      local(time).strftime("%Y-%m-%d")
    end

    def weekly(time = Time.current)
      local(time).strftime("%G-W%V")
    end

    def today = daily
    def this_week = weekly

    def date_of(daily_key)
      raise ArgumentError, daily_key unless daily_key.match?(DAILY)
      Date.iso8601(daily_key)
    end

    def week_range(weekly_key)
      raise ArgumentError, weekly_key unless weekly_key.match?(WEEKLY)
      year, week = weekly_key.split("-W").map(&:to_i)
      monday = Date.commercial(year, week, 1)
      monday..(monday + 6)
    end

    private
      def local(time)
        time.in_time_zone(ZONE)
      end
  end
end
```

- [ ] **Step 4: 跑测试确认通过**，然后提交：

```bash
git add app/models/period_key.rb test/models/period_key_test.rb && git -c commit.gpgsign=false commit -m "feat: 周期键，上海时区与 ISO 周

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: 数据模型与预置源

**Files:**
- Create: `db/migrate/*_create_sources.rb`、`*_create_issues.rb`、`*_create_items.rb`、`*_create_fetch_runs.rb`、`*_create_settings.rb`、`app/models/{source,issue,item,fetch_run,setting}.rb`、`test/fixtures/{sources,issues,items,fetch_runs,settings}.yml`、`test/models/{source,issue,item}_test.rb`、`db/seeds.rb`

**Interfaces:**
- Produces: 五个模型与约束；`Source.enabled.daily`、`Source.weekly` 作用域；`Issue.daily.find_by(period_key:)`；`Setting.get("daily_time") -> "06:00"`；`bin/rails db:seed` 写入四个预置源。

- [ ] **Step 1: 失败测试**

`test/models/item_test.rb`：

```ruby
require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "同源同期同地址唯一" do
    existing = items(:hn_one)
    dup = existing.dup
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "标题超过 300 字符被数据库拒绝" do
    item = items(:hn_one)
    assert_raises(ActiveRecord::StatementInvalid) do
      item.update_column(:title, "x" * 301)
    end
  end

  test "url 必须是 http 或 https" do
    item = items(:hn_one)
    item.url = "ftp://example.com/a"
    assert_not item.valid?
  end
end
```

`test/models/issue_test.rb`：

```ruby
require "test_helper"

class IssueTest < ActiveSupport::TestCase
  test "同刊物同周期键只有一期" do
    dup = Issue.new(kind: "daily", period_key: issues(:daily_0908).period_key, state: "generating")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "缺期是推导出来的" do
    assert_nil Issue.daily.find_by(period_key: "2026-09-03")
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 迁移**

`bin/rails generate migration CreateSources` 等五个，内容：

```ruby
class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources, id: { type: :string, limit: 25 } do |t|
      t.string :name, limit: 100, null: false
      t.string :adapter, limit: 40, null: false      # hacker_news / github_trending / rss / ruanyf_weekly
      t.string :publication, limit: 10, null: false  # daily / weekly
      t.jsonb :config, null: false, default: {}
      t.integer :sort_order, null: false, default: 100
      t.boolean :enabled, null: false, default: true
      t.timestamps
      t.index :name, unique: true
      t.check_constraint "publication IN ('daily', 'weekly')", name: "sources_publication"
    end
  end
end

class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues, id: { type: :string, limit: 25 } do |t|
      t.string :kind, limit: 10, null: false          # daily / weekly
      t.string :period_key, limit: 10, null: false
      t.string :state, limit: 12, null: false, default: "generating"  # generating / published / empty
      t.datetime :published_at
      t.datetime :revised_at
      t.datetime :generation_started_at, null: false
      t.boolean :generated_late, null: false, default: false
      t.timestamps
      t.index [ :kind, :period_key ], unique: true
      t.check_constraint "state IN ('generating', 'published', 'empty')", name: "issues_state"
    end
  end
end

class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items, id: { type: :string, limit: 25 } do |t|
      t.string :source_id, limit: 25, null: false
      t.string :issue_id, limit: 25, null: false
      t.string :title, limit: 300, null: false
      t.string :url, limit: 2048, null: false
      t.string :url_hash, limit: 64, null: false
      t.string :summary, limit: 500
      t.string :section, limit: 100
      t.string :author, limit: 100
      t.datetime :published_at
      t.integer :rank
      t.jsonb :meta, null: false, default: {}
      t.datetime :fetched_at, null: false
      t.boolean :hidden, null: false, default: false
      t.string :reason, limit: 120
      t.string :interest_tag, limit: 20
      t.datetime :reason_generated_at
      t.timestamps
      t.index [ :source_id, :issue_id, :url_hash ], unique: true
      t.index [ :issue_id, :source_id, :rank ]
      t.foreign_key :sources
      t.foreign_key :issues
      t.check_constraint "length(title) <= 300", name: "items_title_len"
      t.check_constraint "length(url) <= 2048", name: "items_url_len"
      t.check_constraint "length(summary) <= 500", name: "items_summary_len"
    end
  end
end

class CreateFetchRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :fetch_runs, id: { type: :string, limit: 25 } do |t|
      t.string :source_id, limit: 25, null: false
      t.string :issue_id, limit: 25
      t.string :trigger, limit: 10, null: false       # scheduled / manual / test
      t.integer :attempt, null: false, default: 1
      t.string :status, limit: 10, null: false        # queued / running / succeeded / failed / timed_out
      t.datetime :started_at
      t.integer :duration_ms
      t.integer :item_count
      t.integer :dropped_count
      t.string :error_summary, limit: 200
      t.timestamps
      t.index [ :source_id, :created_at ]
      t.foreign_key :sources
      t.foreign_key :issues
    end
  end
end

class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings, id: { type: :string, limit: 25 } do |t|
      t.string :key, limit: 50, null: false
      t.string :value, limit: 255, null: false
      t.timestamps
      t.index :key, unique: true
    end
  end
end
```

- [ ] **Step 4: 模型**

```ruby
# app/models/source.rb
class Source < ApplicationRecord
  ADAPTERS = %w[ hacker_news github_trending rss ruanyf_weekly ].freeze

  has_many :items, dependent: :restrict_with_exception
  has_many :fetch_runs, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 100 }
  validates :adapter, inclusion: { in: ADAPTERS }
  validates :publication, inclusion: { in: %w[ daily weekly ] }

  scope :enabled, -> { where(enabled: true) }
  scope :daily,   -> { where(publication: "daily") }
  scope :weekly,  -> { where(publication: "weekly") }
  scope :ordered, -> { order(:sort_order, :name) }

  def adapter_class
    "Adapters::#{adapter.camelize}".constantize
  end
end

# app/models/issue.rb
class Issue < ApplicationRecord
  has_many :items, dependent: :delete_all
  has_many :fetch_runs, dependent: :nullify

  validates :kind, inclusion: { in: %w[ daily weekly ] }
  validates :period_key, presence: true
  validates :state, inclusion: { in: %w[ generating published empty ] }

  scope :daily,  -> { where(kind: "daily") }
  scope :weekly, -> { where(kind: "weekly") }
  scope :chronologically, -> { order(:period_key) }

  def published? = state == "published"
  def empty?     = state == "empty"
  def generating? = state == "generating"
end

# app/models/item.rb
class Item < ApplicationRecord
  belongs_to :source
  belongs_to :issue

  validates :title, presence: true, length: { maximum: 300 }
  validates :url, presence: true, length: { maximum: 2048 }, format: { with: %r{\Ahttps?://}i }
  validates :url_hash, presence: true, length: { is: 64 }
  validates :summary, length: { maximum: 500 }, allow_nil: true

  scope :visible, -> { where(hidden: false) }
  scope :ranked,  -> { order(:rank, :created_at) }
end

# app/models/fetch_run.rb
class FetchRun < ApplicationRecord
  belongs_to :source
  belongs_to :issue, optional: true

  RETENTION = 30.days

  validates :trigger, inclusion: { in: %w[ scheduled manual test ] }
  validates :status, inclusion: { in: %w[ queued running succeeded failed timed_out ] }

  scope :ordered, -> { order(created_at: :desc) }
  scope :stale,   -> { where(created_at: ...RETENTION.ago) }

  def self.cleanup(batch_size: 500)
    loop { break if stale.limit(batch_size).delete_all.zero? }
  end
end

# app/models/setting.rb
class Setting < ApplicationRecord
  DEFAULTS = { "daily_time" => "06:00", "weekly_time" => "09:00" }.freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key)
    find_by(key: key)&.value || DEFAULTS.fetch(key)
  end

  def self.set(key, value)
    find_or_initialize_by(key: key).update!(value: value)
  end
end
```

- [ ] **Step 5: fixtures 与 seeds**

`test/fixtures/sources.yml`：

```yaml
hn:
  id: <%= ActiveRecord::FixtureSet.identify(:hn, :uuid) %>
  name: Hacker News
  adapter: hacker_news
  publication: daily
  config: { "list": "top", "count": 10, "min_score": 0 }
  sort_order: 1
github:
  id: <%= ActiveRecord::FixtureSet.identify(:github, :uuid) %>
  name: GitHub Trending
  adapter: github_trending
  publication: daily
  config: { "languages": [], "count": 10 }
  sort_order: 2
hackaday:
  id: <%= ActiveRecord::FixtureSet.identify(:hackaday, :uuid) %>
  name: Hackaday
  adapter: rss
  publication: daily
  config: { "feed_url": "https://hackaday.com/feed/", "count": 10, "window_hours": 24 }
  sort_order: 3
ruanyf:
  id: <%= ActiveRecord::FixtureSet.identify(:ruanyf, :uuid) %>
  name: 阮一峰科技爱好者周刊
  adapter: ruanyf_weekly
  publication: weekly
  config: { "min_items": 5 }
  sort_order: 1
```

`test/fixtures/issues.yml`：

```yaml
daily_0908:
  id: <%= ActiveRecord::FixtureSet.identify(:daily_0908, :uuid) %>
  kind: daily
  period_key: "2026-09-08"
  state: published
  published_at: <%= Time.utc(2026, 9, 7, 22, 12).to_fs(:db) %>
  generation_started_at: <%= Time.utc(2026, 9, 7, 22, 0).to_fs(:db) %>
weekly_w36:
  id: <%= ActiveRecord::FixtureSet.identify(:weekly_w36, :uuid) %>
  kind: weekly
  period_key: "2026-W36"
  state: published
  published_at: <%= Time.utc(2026, 9, 4, 1, 3).to_fs(:db) %>
  generation_started_at: <%= Time.utc(2026, 9, 4, 1, 0).to_fs(:db) %>
```

`test/fixtures/items.yml`：

```yaml
hn_one:
  id: <%= ActiveRecord::FixtureSet.identify(:hn_one, :uuid) %>
  source: hn
  issue: daily_0908
  title: "Show HN: A terminal log viewer written in Rust"
  url: "https://example.com/termlog"
  url_hash: <%= Digest::SHA256.hexdigest("https://example.com/termlog") %>
  rank: 1
  meta: { "score": 312, "comments": 145 }
  fetched_at: <%= Time.utc(2026, 9, 7, 22, 12).to_fs(:db) %>
```

`test/fixtures/settings.yml`、`test/fixtures/fetch_runs.yml` 各放一条。`db/seeds.rb`：

```ruby
return unless Rails.env.development?

[
  { name: "Hacker News", adapter: "hacker_news", publication: "daily", sort_order: 1, config: { list: "top", count: 10, min_score: 0 } },
  { name: "GitHub Trending", adapter: "github_trending", publication: "daily", sort_order: 2, config: { languages: [], count: 10 } },
  { name: "Hackaday", adapter: "rss", publication: "daily", sort_order: 3, config: { feed_url: "https://hackaday.com/feed/", count: 10, window_hours: 24 } },
  { name: "阮一峰科技爱好者周刊", adapter: "ruanyf_weekly", publication: "weekly", sort_order: 1, config: { min_items: 5 } }
].each { |attrs| Source.find_or_create_by!(name: attrs[:name]) { |s| s.assign_attributes(attrs) } }
```

- [ ] **Step 6: 迁移并跑测试**

`bin/rails db:migrate && bin/rails test`，预期全部通过（含 Task 2、3）。检查 `db/schema.rb` 里 id 是 `limit: 25` 的 string。

- [ ] **Step 7: 提交**

```bash
git add db app/models test/fixtures test/models && git -c commit.gpgsign=false commit -m "feat: 源、期、条目、抓取记录、设置的模型与约束，预置四个源

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: 地址归一化与摘要清洗

**Files:**
- Create: `app/models/url_normalizer.rb`、`app/models/summary_cleaner.rb`、`test/models/url_normalizer_test.rb`、`test/models/summary_cleaner_test.rb`

**Interfaces:**
- Produces: `UrlNormalizer.normalize(url) -> String`、`UrlNormalizer.hash(url) -> 64 hex`；`SummaryCleaner.clean(text) -> String(≤500)`、`SummaryCleaner.preview(text) -> String(≤200)`。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class UrlNormalizerTest < ActiveSupport::TestCase
  test "小写协议与主机、去默认端口、去 fragment、去跟踪参数、参数排序、去尾斜杠" do
    url = "HTTP://Example.COM:80/a/b/?utm_source=x&b=2&a=1#top"
    assert_equal "https://example.com/a/b?a=1&b=2", UrlNormalizer.normalize(url)
  end

  test "根路径保留斜杠，http 与 https 同哈希" do
    assert_equal "https://example.com/", UrlNormalizer.normalize("http://example.com/")
    assert_equal UrlNormalizer.hash("http://example.com/x"), UrlNormalizer.hash("https://example.com/x")
  end
end

class SummaryCleanerTest < ActiveSupport::TestCase
  test "去标签、解实体、合并空白、截断" do
    assert_equal "Hello & world", SummaryCleaner.clean("<p>Hello &amp;\n\n  <b>world</b></p>")
    long = SummaryCleaner.clean("字" * 600)
    assert_equal 500, long.length
    assert long.end_with?("…")
  end

  test "去 Markdown 标记" do
    assert_equal "标题 链接 加粗", SummaryCleaner.clean("## 标题 [链接](https://x.y) **加粗**")
  end

  test "列表预览 200 字" do
    assert_equal 200, SummaryCleaner.preview("字" * 300).length
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

```ruby
# app/models/url_normalizer.rb
require "digest"

class UrlNormalizer
  TRACKING = /\A(utm_|ref\z|source\z|spm\z|fbclid\z|gclid\z)/i

  class << self
    def normalize(url)
      uri = URI.parse(url.strip)
      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase
      uri.port = nil if uri.port == uri.default_port
      uri.fragment = nil
      uri.query = sorted_query(uri.query)
      uri.path = uri.path.chomp("/") if uri.path.length > 1
      uri.path = "/" if uri.path.empty?
      uri.to_s
    end

    def hash(url)
      canonical = normalize(url).sub(/\Ahttp:/, "https:")
      Digest::SHA256.hexdigest(canonical)
    end

    private
      def sorted_query(query)
        return nil if query.blank?
        pairs = URI.decode_www_form(query).reject { |k, _| k.match?(TRACKING) }.sort_by(&:first)
        pairs.empty? ? nil : URI.encode_www_form(pairs)
      end
  end
end

# app/models/summary_cleaner.rb
class SummaryCleaner
  STORE_LIMIT = 500
  PREVIEW_LIMIT = 200

  class << self
    def clean(text)
      return nil if text.nil?
      s = strip_markdown(strip_html(text))
      s = CGI.unescapeHTML(s).gsub(/[[:space:]]+/, " ").strip
      truncate(s, STORE_LIMIT)
    end

    def preview(text)
      truncate(clean(text).to_s, PREVIEW_LIMIT)
    end

    private
      def strip_html(text)
        Nokogiri::HTML.fragment(text).text
      end

      def strip_markdown(text)
        text.gsub(/!\[[^\]]*\]\([^)]*\)/, "")            # 图片
            .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')          # 链接保留文字
            .gsub(/^\s{0,3}#{1,6}\s+/, "")                # 标题
            .gsub(/(\*\*|__|\*|_|`)/, "")                 # 强调与代码
            .gsub(/^\s*[-*+]\s+/, "")                     # 列表符
    end

      def truncate(s, limit)
        s.length > limit ? s[0, limit - 1] + "…" : s
      end
  end
end
```

- [ ] **Step 4: 跑测试确认通过**，提交：

```bash
git add app/models/url_normalizer.rb app/models/summary_cleaner.rb test/models && git -c commit.gpgsign=false commit -m "feat: 地址归一化与摘要清洗

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: 出站 HTTP 客户端

**Files:**
- Create: `app/models/adapters/http.rb`、`test/models/adapters/http_test.rb`

**Interfaces:**
- Produces: `Adapters::Http.get(url, timeout: 60, max_bytes: 2.megabytes) -> Adapters::Http::Response(status, body, content_type)`；错误类 `Adapters::Http::Error`、`Adapters::Http::Blocked`（429/403）、`Adapters::Http::TooLarge`、`Adapters::Http::Unresolvable`（SSRF 拦截）。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class Adapters::HttpTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "93.184.216.34" ]) }

  test "带 User-Agent 取回正文" do
    stub_request(:get, "https://example.com/feed").with(headers: { "User-Agent" => /lowpass/ }).to_return(body: "<rss/>", status: 200)
    response = Adapters::Http.get("https://example.com/feed")
    assert_equal 200, response.status
    assert_equal "<rss/>", response.body
  end

  test "429 与 403 直接失败不重试" do
    stub_request(:get, "https://example.com/x").to_return(status: 429)
    assert_raises(Adapters::Http::Blocked) { Adapters::Http.get("https://example.com/x") }
    assert_requested :get, "https://example.com/x", times: 1
  end

  test "超过大小上限失败" do
    stub_request(:get, "https://example.com/big").to_return(body: "x" * 1000)
    assert_raises(Adapters::Http::TooLarge) { Adapters::Http.get("https://example.com/big", max_bytes: 100) }
  end

  test "解析不到公网地址时拒绝连接" do
    Surfguard.unstub(:resolve_public_ips)
    Surfguard.stubs(:resolve_public_ips).raises(Surfguard::Unresolvable)
    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http.get("http://10.0.0.1/feed") }
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

```ruby
require "net/http"

module Adapters
  class Http
    Error = Class.new(StandardError)
    Blocked = Class.new(Error)
    TooLarge = Class.new(Error)
    Unresolvable = Class.new(Error)
    Response = Struct.new(:status, :body, :content_type)

    USER_AGENT = "lowpass/0.1 (+#{ENV.fetch('BASE_URL', 'https://lowpass.example')})"
    MAX_REDIRECTS = 3

    def self.get(url, timeout: 60, max_bytes: 2.megabytes)
      new(timeout: timeout, max_bytes: max_bytes).get(url)
    end

    def initialize(timeout:, max_bytes:)
      @timeout = timeout
      @max_bytes = max_bytes
    end

    def get(url, redirects = 0)
      uri = URI.parse(url)
      raise Error, "unsupported scheme" unless uri.is_a?(URI::HTTP)
      ip = resolve_public_ip(uri.host)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = @timeout
      http.ipaddr = ip

      http.start do |conn|
        request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "*/*")
        conn.request(request) do |res|
          return follow(res, redirects) if res.is_a?(Net::HTTPRedirection)
          raise Blocked, "#{res.code} for #{uri}" if res.code.in?(%w[ 403 429 ])
          raise Error, "#{res.code} for #{uri}" unless res.is_a?(Net::HTTPSuccess)
          body = read_capped(res)
          return Response.new(res.code.to_i, body, res["Content-Type"])
        end
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError, Errno::ECONNREFUSED => e
      raise Error, e.message
    end

    private
      def resolve_public_ip(host)
        Surfguard.resolve_public_ips(host).first or raise Unresolvable, host
      rescue Surfguard::Unresolvable
        raise Unresolvable, host
      end

      def follow(res, redirects)
        raise Error, "too many redirects" if redirects >= MAX_REDIRECTS
        get(URI.join(res.uri, res["Location"]).to_s, redirects + 1)
      end

      def read_capped(res)
        buffer = +""
        res.read_body do |chunk|
          buffer << chunk
          raise TooLarge, buffer.bytesize if buffer.bytesize > @max_bytes
        end
        buffer.force_encoding(Encoding::UTF_8)
      end
  end
end
```

- [ ] **Step 4: 跑测试确认通过**，提交：

```bash
git add app/models/adapters/http.rb test/models/adapters && git -c commit.gpgsign=false commit -m "feat: 出站 HTTP 客户端：超时、大小上限、429/403、surfguard

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: 条目契约与适配器基类

**Files:**
- Create: `app/models/adapters/entry.rb`、`app/models/adapters/base.rb`、`test/models/adapters/entry_test.rb`

**Interfaces:**
- Produces: `Adapters::Entry.new(title:, url:, summary: nil, section: nil, author: nil, published_at: nil, rank: nil, meta: {})`，`#valid?`、`#to_item_attributes(source:, issue:)`；`Adapters::Base.new(source).fetch(period_key: nil) -> Array<Entry>`（子类实现 `entries`），`Adapters::Base#test_fetch -> Array<Entry>`（前 5 条，30 秒超时）。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class Adapters::EntryTest < ActiveSupport::TestCase
  test "缺标题或缺链接无效" do
    assert_not Adapters::Entry.new(title: "", url: "https://a.b").valid?
    assert_not Adapters::Entry.new(title: "t", url: nil).valid?
    assert Adapters::Entry.new(title: "t", url: "https://a.b").valid?
  end

  test "转成条目属性时清洗摘要并算哈希" do
    entry = Adapters::Entry.new(title: " 标题 ", url: "https://A.b/x/", summary: "<b>hi</b>")
    attrs = entry.to_item_attributes(source: sources(:hn), issue: issues(:daily_0908))
    assert_equal "标题", attrs[:title]
    assert_equal "hi", attrs[:summary]
    assert_equal UrlNormalizer.hash("https://A.b/x/"), attrs[:url_hash]
    assert_equal sources(:hn).id, attrs[:source_id]
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

```ruby
# app/models/adapters/entry.rb
module Adapters
  Entry = Struct.new(:title, :url, :summary, :section, :author, :published_at, :rank, :meta, keyword_init: true) do
    def valid?
      title.to_s.strip.present? && url.to_s.match?(%r{\Ahttps?://}i)
    end

    def to_item_attributes(source:, issue:)
      {
        source_id: source.id,
        issue_id: issue.id,
        title: title.to_s.strip[0, 300],
        url: url.to_s.strip[0, 2048],
        url_hash: UrlNormalizer.hash(url),
        summary: SummaryCleaner.clean(summary),
        section: section&.strip&.slice(0, 100),
        author: author&.strip&.slice(0, 100),
        published_at: published_at,
        rank: rank,
        meta: meta || {},
        fetched_at: Time.current
      }
    end
  end
end

# app/models/adapters/base.rb
module Adapters
  class Base
    FETCH_TIMEOUT = 60
    TEST_TIMEOUT = 30

    attr_reader :source

    def initialize(source)
      @source = source
    end

    def fetch(period_key: nil)
      Timeout.timeout(FETCH_TIMEOUT) { entries(period_key: period_key) }
    end

    def test_fetch
      Timeout.timeout(TEST_TIMEOUT) { entries(period_key: nil).first(5) }
    end

    private
      # 子类实现，返回 Array<Entry>
      def entries(period_key:)
        raise NotImplementedError
      end

      def config
        source.config.with_indifferent_access
      end

      def http(url, **options)
        Http.get(url, **options)
      end
  end
end
```

- [ ] **Step 4: 跑测试确认通过**，提交：

```bash
git add app/models/adapters test/models/adapters && git -c commit.gpgsign=false commit -m "feat: 条目契约与适配器基类

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Hacker News 适配器

**Files:**
- Create: `app/models/adapters/hacker_news.rb`、`test/models/adapters/hacker_news_test.rb`、`test/fixtures/files/hacker_news/topstories.json`、`test/fixtures/files/hacker_news/item_*.json`、`script/capture_samples`

**Interfaces:**
- Consumes: `Adapters::Base`、`Adapters::Http`
- Produces: `Adapters::HackerNews#fetch` 返回前 N 条 story（排除 job），无外链的指向讨论页（D8），meta 含 `score`、`comments`、`comments_url`。

- [ ] **Step 1: 样本抓取脚本**

`script/capture_samples`（需要网络，只在开发机跑一次，样本随代码提交）：

```ruby
#!/usr/bin/env ruby
require "net/http"
require "json"
require "fileutils"

ROOT = File.expand_path("../test/fixtures/files", __dir__)
def save(path, body) = (FileUtils.mkdir_p(File.dirname(f = File.join(ROOT, path))); File.write(f, body); puts f)
def get(url) = Net::HTTP.get(URI(url))

case ARGV[0]
when "hn"
  ids = JSON.parse(get("https://hacker-news.firebaseio.com/v0/topstories.json")).first(15)
  save("hacker_news/topstories.json", JSON.pretty_generate(ids))
  ids.each { |id| save("hacker_news/item_#{id}.json", get("https://hacker-news.firebaseio.com/v0/item/#{id}.json")) }
when "github"
  save("github_trending/daily.html", get("https://github.com/trending?since=daily"))
when "hackaday"
  save("rss/hackaday.xml", get("https://hackaday.com/feed/"))
when "ruanyf"
  from, to = ARGV[1].to_i, ARGV[2].to_i
  (from..to).each { |n| save("ruanyf/issue-#{n}.md", get("https://raw.githubusercontent.com/ruanyf/weekly/master/docs/issue-#{n}.md")) }
  save("ruanyf/README.md", get("https://raw.githubusercontent.com/ruanyf/weekly/master/README.md"))
else
  abort "usage: script/capture_samples hn|github|hackaday|ruanyf [from to]"
end
```

`chmod +x script/capture_samples && script/capture_samples hn`。样本里若含 job 条目正好可以测过滤；没有的话手工把其中一份 item 的 `"type"` 改成 `"job"` 并在文件名加 `_job` 说明。

- [ ] **Step 2: 失败测试**

```ruby
require "test_helper"

class Adapters::HackerNewsTest < ActiveSupport::TestCase
  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    ids = JSON.parse(file_fixture("hacker_news/topstories.json").read)
    stub_request(:get, "https://hacker-news.firebaseio.com/v0/topstories.json").to_return(body: ids.to_json)
    ids.each do |id|
      stub_request(:get, "https://hacker-news.firebaseio.com/v0/item/#{id}.json").to_return(body: file_fixture("hacker_news/item_#{id}.json").read)
    end
  end

  test "取前 10 条 story，跳过 job，带分数与评论" do
    entries = Adapters::HackerNews.new(sources(:hn)).fetch
    assert_equal 10, entries.size
    assert entries.all?(&:valid?)
    assert_equal (1..10).to_a, entries.map(&:rank)
    first = entries.first
    assert_kind_of Integer, first.meta[:score]
    assert_match %r{news\.ycombinator\.com/item\?id=}, first.meta[:comments_url]
  end

  test "无外链的帖子指向讨论页" do
    entries = Adapters::HackerNews.new(sources(:hn)).fetch
    ask = entries.find { |e| e.title.start_with?("Ask HN") }
    skip "样本里没有 Ask HN" unless ask
    assert_match %r{news\.ycombinator\.com/item\?id=}, ask.url
  end
end
```

- [ ] **Step 3: 跑测试确认失败**

- [ ] **Step 4: 实现**

```ruby
module Adapters
  class HackerNews < Base
    API = "https://hacker-news.firebaseio.com/v0"

    private
      def entries(period_key:)
        count = config.fetch(:count, 10).to_i
        min_score = config.fetch(:min_score, 0).to_i
        ids = JSON.parse(http("#{API}/#{config.fetch(:list, 'top')}stories.json").body)
        picked = []
        ids.each do |id|
          break if picked.size >= count
          story = JSON.parse(http("#{API}/item/#{id}.json").body)
          next unless story["type"] == "story" && story["score"].to_i >= min_score && !story["dead"] && !story["deleted"]
          picked << build(story, picked.size + 1)
        end
        picked
      end

      def build(story, rank)
        discussion = "https://news.ycombinator.com/item?id=#{story['id']}"
        Entry.new(
          title: story["title"],
          url: story["url"].presence || discussion,
          author: story["by"],
          published_at: Time.at(story["time"].to_i).utc,
          rank: rank,
          meta: { score: story["score"].to_i, comments: story["descendants"].to_i, comments_url: discussion }
        )
      end
  end
end
```

- [ ] **Step 5: 跑测试确认通过**，提交：

```bash
git add app/models/adapters/hacker_news.rb test/models/adapters/hacker_news_test.rb test/fixtures/files/hacker_news script/capture_samples && git -c commit.gpgsign=false commit -m "feat: Hacker News 适配器与样本

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: GitHub Trending 适配器

**Files:**
- Create: `app/models/adapters/github_trending.rb`、`test/models/adapters/github_trending_test.rb`、`test/fixtures/files/github_trending/daily.html`

**Interfaces:**
- Produces: 前 N 个仓库：title 为 `owner/repo`，url 仓库页，summary 描述（空则 nil），meta 含 `language`、`stars`、`stars_today`；语言列表非空时按语言路径各取 5（D13）。

- [ ] **Step 1: 样本**：`script/capture_samples github`。

- [ ] **Step 2: 失败测试**

```ruby
require "test_helper"

class Adapters::GithubTrendingTest < ActiveSupport::TestCase
  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "https://github.com/trending?since=daily").to_return(body: file_fixture("github_trending/daily.html").read)
  end

  test "解析综合榜前 10" do
    entries = Adapters::GithubTrending.new(sources(:github)).fetch
    assert_equal 10, entries.size
    first = entries.first
    assert_match %r{\A[\w.-]+/[\w.-]+\z}, first.title
    assert_match %r{\Ahttps://github\.com/}, first.url
    assert_kind_of Integer, first.meta[:stars]
    assert_kind_of Integer, first.meta[:stars_today]
  end

  test "页面结构变了要报解析失败而不是静默 0 条" do
    stub_request(:get, "https://github.com/trending?since=daily").to_return(body: "<html><body>nothing</body></html>")
    assert_raises(Adapters::GithubTrending::ParseError) { Adapters::GithubTrending.new(sources(:github)).fetch }
  end
end
```

- [ ] **Step 3: 跑测试确认失败**

- [ ] **Step 4: 实现**

```ruby
module Adapters
  class GithubTrending < Base
    ParseError = Class.new(StandardError)

    private
      def entries(period_key:)
        languages = Array(config[:languages]).reject(&:blank?)
        if languages.empty?
          parse(fetch_page(nil)).first(config.fetch(:count, 10).to_i)
        else
          per = config.fetch(:count, 5).to_i
          languages.flat_map { |lang| parse(fetch_page(lang), language: lang).first(per) }.each_with_index.map { |e, i| e.rank = i + 1; e }
        end
      end

      def fetch_page(language)
        path = language ? "/trending/#{URI.encode_www_form_component(language)}" : "/trending"
        http("https://github.com#{path}?since=daily").body
      end

      def parse(html, language: nil)
        doc = Nokogiri::HTML(html)
        rows = doc.css("article.Box-row")
        raise ParseError, "no trending rows" if rows.empty?
        rows.each_with_index.map do |row, i|
          repo = row.at_css("h2 a")["href"].to_s.delete_prefix("/")
          Entry.new(
            title: repo,
            url: "https://github.com/#{repo}",
            summary: row.at_css("p")&.text,
            rank: i + 1,
            meta: {
              language: language || row.at_css("[itemprop='programmingLanguage']")&.text&.strip,
              stars: number(row.at_css("a[href$='/stargazers']")&.text),
              stars_today: number(row.css("span").map(&:text).find { |t| t.include?("stars today") })
            }
          )
        end
      end

      def number(text)
        text.to_s.delete(",").scan(/\d+/).first.to_i
      end
  end
end
```

- [ ] **Step 5: 跑测试确认通过**，提交：

```bash
git add app/models/adapters/github_trending.rb test/models/adapters/github_trending_test.rb test/fixtures/files/github_trending && git -c commit.gpgsign=false commit -m "feat: GitHub Trending 适配器与样本

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: RSS/Atom 适配器（Hackaday）

**Files:**
- Create: `app/models/adapters/rss.rb`、`test/models/adapters/rss_test.rb`、`test/fixtures/files/rss/hackaday.xml`、`test/fixtures/files/rss/atom_sample.xml`

**Interfaces:**
- Produces: 日刊用法：时间窗口内（默认 24 小时）最新 N 条，按发布时间倒序；周刊用法（F-08）：`fetch(period_key: "2026-W36")` 返回该 ISO 周内的条目。字段：title、url、summary（summary / description / content 首个非空）、author、published_at（published 或 updated；缺失则用抓取时间并在 meta 标 `time_from_fetch: true`）、meta.image_url。

- [ ] **Step 1: 样本**：`script/capture_samples hackaday`；另手写一份最小 Atom 文件 `atom_sample.xml`（两条 entry，一条无发布时间）。

- [ ] **Step 2: 失败测试**

```ruby
require "test_helper"

class Adapters::RssTest < ActiveSupport::TestCase
  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "https://hackaday.com/feed/").to_return(body: file_fixture("rss/hackaday.xml").read)
    stub_request(:get, "https://example.com/atom").to_return(body: file_fixture("rss/atom_sample.xml").read)
  end

  test "RSS 2.0：时间窗口内最新 10 条，倒序" do
    newest = RSS::Parser.parse(file_fixture("rss/hackaday.xml").read, false).items.map(&:pubDate).max
    travel_to newest + 1.hour do
      entries = Adapters::Rss.new(sources(:hackaday)).fetch
      assert entries.size <= 10
      assert entries.all?(&:valid?)
      assert_equal entries.map(&:published_at), entries.map(&:published_at).sort.reverse
      assert entries.all? { |e| e.published_at >= 24.hours.ago }
    end
  end

  test "Atom：缺发布时间用抓取时间并标记" do
    source = Source.new(name: "x", adapter: "rss", publication: "daily", config: { feed_url: "https://example.com/atom", count: 10, window_hours: 24 * 365 * 10 })
    entries = Adapters::Rss.new(source).fetch
    assert_equal 2, entries.size
    assert entries.any? { |e| e.meta[:time_from_fetch] }
  end

  test "周刊用法按 ISO 周过滤" do
    source = Source.new(name: "w", adapter: "rss", publication: "weekly", config: { feed_url: "https://example.com/atom", count: 50 })
    entries = Adapters::Rss.new(source).fetch(period_key: "2026-W36")
    assert entries.all? { |e| PeriodKey.weekly(e.published_at) == "2026-W36" }
  end
end
```

- [ ] **Step 3: 跑测试确认失败**

- [ ] **Step 4: 实现**

```ruby
require "rss"

module Adapters
  class Rss < Base
    private
      def entries(period_key:)
        feed = ::RSS::Parser.parse(http(config.fetch(:feed_url)).body, false)
        raise Http::Error, "not a feed" if feed.nil?
        fetched_at = Time.current
        all = feed_items(feed).map { |it| normalize(it, fetched_at) }.select(&:valid?)
        window = if period_key
          range = PeriodKey.week_range(period_key)
          all.select { |e| range.cover?(e.published_at.in_time_zone(PeriodKey::ZONE).to_date) }
        else
          all.select { |e| e.published_at >= config.fetch(:window_hours, 24).to_i.hours.ago }
        end
        window.sort_by(&:published_at).reverse.first(config.fetch(:count, 10).to_i).each_with_index.map { |e, i| e.rank = i + 1; e }
      end

      def feed_items(feed)
        feed.respond_to?(:items) ? feed.items : feed.entries
      end

      def normalize(item, fetched_at)
        atom = item.respond_to?(:updated)
        published = atom ? (item.published&.content || item.updated&.content) : (item.pubDate || item.dc_date)
        Entry.new(
          title: atom ? item.title&.content : item.title,
          url: atom ? item.link&.href : item.link,
          summary: atom ? (item.summary&.content || item.content&.content) : (item.description.presence || item.content_encoded),
          author: atom ? item.author&.name&.content : (item.dc_creator || item.author),
          published_at: published&.to_time&.utc || fetched_at,
          meta: { image_url: first_image(item), time_from_fetch: published.nil? }.compact
        )
      end

      def first_image(item)
        html = item.respond_to?(:content_encoded) ? item.content_encoded.to_s : item.try(:content)&.content.to_s
        Nokogiri::HTML.fragment(html).at_css("img")&.[]("src")
      end
  end
end
```

- [ ] **Step 5: 跑测试确认通过**，提交：

```bash
git add app/models/adapters/rss.rb test/models/adapters/rss_test.rb test/fixtures/files/rss && git -c commit.gpgsign=false commit -m "feat: RSS/Atom 适配器，日刊窗口与周刊 ISO 周两种用法

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: 阮一峰周刊适配器

**Files:**
- Create: `app/models/adapters/ruanyf_weekly.rb`、`app/models/adapters/ruanyf_weekly/markdown.rb`、`test/models/adapters/ruanyf_weekly_test.rb`、`test/fixtures/files/ruanyf/issue-{N}.md`（近 20 期）、`test/fixtures/files/ruanyf/README.md`

**Interfaces:**
- Produces: `Adapters::RuanyfWeekly#latest_issue_number -> Integer`（读仓库 README 的期列表）、`#fetch(period_key: nil)` 返回最新一期的条目（section 为板块名，meta 含 `issue_no`、`issue_title`、`anchor`）、`#fetch_issue(n)`；`Adapters::RuanyfWeekly::Markdown.parse(text) -> { issue_no:, title:, published_on:, sections: [{ name:, items: [...] }] }`；条目少于 5 抛 `Degraded`（带原文链接）。

- [ ] **Step 1: 样本**：`script/capture_samples ruanyf 347 366`（最近 20 期）。

- [ ] **Step 2: 失败测试**

```ruby
require "test_helper"

class Adapters::RuanyfWeeklyTest < ActiveSupport::TestCase
  RAW = "https://raw.githubusercontent.com/ruanyf/weekly/master"

  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "#{RAW}/README.md").to_return(body: file_fixture("ruanyf/README.md").read)
    Dir[file_fixture_path.join("ruanyf/issue-*.md")].each do |path|
      n = path[/issue-(\d+)/, 1]
      stub_request(:get, "#{RAW}/docs/issue-#{n}.md").to_return(body: File.read(path))
    end
  end

  test "近 20 期样本都能拆出板块与至少 5 条" do
    Dir[file_fixture_path.join("ruanyf/issue-*.md")].each do |path|
      parsed = Adapters::RuanyfWeekly::Markdown.parse(File.read(path))
      assert parsed[:issue_no] > 0, path
      assert parsed[:sections].map { |s| s[:name] }.include?("科技动态"), path
      items = parsed[:sections].flat_map { |s| s[:items] }
      assert items.size >= 5, "#{path}: #{items.size}"
      assert items.all? { |i| i[:title].present? && i[:url].present? }, path
    end
  end

  test "最新期号来自 README" do
    n = Adapters::RuanyfWeekly.new(sources(:ruanyf)).latest_issue_number
    assert_equal Dir[file_fixture_path.join("ruanyf/issue-*.md")].map { |p| p[/issue-(\d+)/, 1].to_i }.max, n
  end

  test "fetch 返回最新期的条目，带板块与期号" do
    entries = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch
    assert entries.size >= 5
    assert entries.all? { |e| e.section.present? && e.meta[:issue_no].is_a?(Integer) }
  end

  test "条目少于 5 条降级" do
    stub_request(:get, "#{RAW}/docs/issue-999.md").to_return(body: "# 科技爱好者周刊（第 999 期）：坏了\n\n## 科技动态\n\n1、只有一条 [x](https://a.b)\n")
    assert_raises(Adapters::RuanyfWeekly::Degraded) { Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(999) }
  end
end
```

- [ ] **Step 3: 跑测试确认失败**

- [ ] **Step 4: 实现**

```ruby
# app/models/adapters/ruanyf_weekly/markdown.rb
module Adapters
  class RuanyfWeekly < Base
    module Markdown
      TITLE = /\A#\s*科技爱好者周刊（第\s*(\d+)\s*期）[：:]\s*(.+?)\s*\z/
      SECTION = /\A##\s+(.+?)\s*\z/
      ITEM_START = /\A(?:\d+[、.]\s*|[-*]\s+)/
      LINK = %r{\[([^\]]*)\]\((https?://[^)\s]+)\)}
      BOLD = /\*\*([^*]+)\*\*/

      module_function

      def parse(text)
        issue_no = nil; title = nil; published_on = nil
        sections = []
        current = nil
        block = []

        flush = lambda do
          if current && block.any?
            current[:items] << build_item(block, current[:name])
          end
          block = []
        end

        text.each_line do |raw|
          line = raw.chomp
          if (m = line.match(TITLE)) && issue_no.nil?
            issue_no, title = m[1].to_i, m[2]
          elsif (m = line.match(SECTION))
            flush.call
            current = { name: m[1], items: [] }
            sections << current
          elsif current && line.match?(ITEM_START)
            flush.call
            block << line.sub(ITEM_START, "")
          elsif current && block.any?
            line.strip.empty? ? (flush.call if block.size > 0 && looks_complete?(block)) : block << line
          elsif published_on.nil? && (m = line.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/))
            published_on = Date.new(m[1].to_i, m[2].to_i, m[3].to_i)
          end
        end
        flush.call
        { issue_no: issue_no, title: title, published_on: published_on, sections: sections.reject { |s| s[:items].empty? } }
      end

      def build_item(block, section)
        body = block.join("\n")
        link = body.match(LINK)
        bold = body.match(BOLD)
        {
          title: (bold && bold[1]) || (link && link[1].presence) || block.first.gsub(/[*_`#]/, "").strip,
          url: link && link[2],
          summary: body,
          section: section
        }
      end

      def looks_complete?(block)
        block.last.to_s.strip.end_with?("。", ".", "）", ")")
      end
    end
  end
end

# app/models/adapters/ruanyf_weekly.rb
module Adapters
  class RuanyfWeekly < Base
    RAW = "https://raw.githubusercontent.com/ruanyf/weekly/master"
    Degraded = Class.new(StandardError) { attr_accessor :issue_no, :issue_title, :url }

    def latest_issue_number
      http("#{RAW}/README.md").body.scan(%r{docs/issue-(\d+)\.md}).flatten.map(&:to_i).max or raise Http::Error, "no issues in README"
    end

    def fetch_issue(n)
      parsed = Markdown.parse(http("#{RAW}/docs/issue-#{n}.md").body)
      original = "https://github.com/ruanyf/weekly/blob/master/docs/issue-#{n}.md"
      items = parsed[:sections].flat_map { |s| s[:items] }
      if items.size < config.fetch(:min_items, 5).to_i
        raise Degraded.new("issue #{n} parsed #{items.size} items").tap { |e| e.issue_no = n; e.issue_title = parsed[:title]; e.url = original }
      end
      items.each_with_index.map do |it, i|
        Entry.new(
          title: it[:title], url: it[:url] || "#{original}##{anchor(it[:section])}", summary: it[:summary], section: it[:section],
          published_at: parsed[:published_on]&.in_time_zone(PeriodKey::ZONE)&.beginning_of_day&.utc, rank: i + 1,
          meta: { issue_no: n, issue_title: parsed[:title], anchor: anchor(it[:section]) }
        )
      end
    end

    private
      def entries(period_key:)
        fetch_issue(latest_issue_number)
      end

      def anchor(section)
        section.to_s.downcase.gsub(/\s+/, "-")
      end
  end
end
```

- [ ] **Step 5: 跑测试确认通过**。样本里若有某期结构特殊（如合刊）导致失败，修解析器而不是改样本；实在是原文异常，在测试里用 `skip` 记下期号与原因。

- [ ] **Step 6: 提交**

```bash
git add app/models/adapters/ruanyf_weekly.rb app/models/adapters/ruanyf_weekly test/models/adapters/ruanyf_weekly_test.rb test/fixtures/files/ruanyf && git -c commit.gpgsign=false commit -m "feat: 阮一峰周刊适配器，近 20 期样本回归

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: 抓取任务与抓取记录

**Files:**
- Create: `app/models/source/fetching.rb`、`app/jobs/fetch_source_job.rb`、`test/models/source/fetching_test.rb`、`test/jobs/fetch_source_job_test.rb`
- Modify: `app/models/source.rb`（include Fetching）

**Interfaces:**
- Consumes: 适配器、`FetchRun`、`Issue`
- Produces: `Source#fetch_later(issue, trigger: "scheduled")`、`Source#fetch_now(issue, trigger:, attempt:) -> FetchRun`（写记录、把条目整栏写入期：先删该源该期旧条目再插入，同一事务）；`FetchSourceJob` 3 次尝试，间隔 30 / 120 秒；`Source#health -> "ok" | "recent_failure" | "consecutive_failures" | "disabled"`。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class Source::FetchingTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ]) }

  test "成功时写入条目、记录成功、整栏替换旧条目" do
    issue = issues(:daily_0908)
    entries = [ Adapters::Entry.new(title: "A", url: "https://a.b/1", rank: 1), Adapters::Entry.new(title: "B", url: "https://a.b/2", rank: 2) ]
    Adapters::HackerNews.any_instance.stubs(:fetch).returns(entries)

    run = sources(:hn).fetch_now(issue, trigger: "manual")

    assert_equal "succeeded", run.status
    assert_equal 2, run.item_count
    assert_equal %w[ A B ], issue.items.where(source: sources(:hn)).ranked.pluck(:title)
  end

  test "缺链接的条目被丢弃并计数" do
    entries = [ Adapters::Entry.new(title: "A", url: nil), Adapters::Entry.new(title: "B", url: "https://a.b/2") ]
    Adapters::HackerNews.any_instance.stubs(:fetch).returns(entries)
    run = sources(:hn).fetch_now(issues(:daily_0908), trigger: "manual")
    assert_equal 1, run.item_count
    assert_equal 1, run.dropped_count
  end

  test "失败时记录失败与错误摘要" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "boom")
    run = sources(:hn).fetch_now(issues(:daily_0908), trigger: "scheduled")
    assert_equal "failed", run.status
    assert_equal "boom", run.error_summary
  end

  test "健康度由最近记录推导" do
    source = sources(:hn)
    3.times { source.fetch_runs.create!(trigger: "scheduled", status: "failed", attempt: 1) }
    assert_equal "consecutive_failures", source.health
    source.fetch_runs.create!(trigger: "scheduled", status: "succeeded", attempt: 1)
    assert_equal "ok", source.health
  end
end

class FetchSourceJobTest < ActiveJob::TestCase
  test "失败后重试，最多 3 次" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Error, "down")
    assert_enqueued_with(job: FetchSourceJob) do
      FetchSourceJob.perform_now(sources(:hn), issues(:daily_0908), "scheduled")
    end
    assert_equal 1, FetchRun.where(source: sources(:hn), attempt: 1).count
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

```ruby
# app/models/source/fetching.rb
module Source::Fetching
  extend ActiveSupport::Concern

  def fetch_later(issue, trigger: "scheduled")
    FetchSourceJob.perform_later(self, issue, trigger)
  end

  def fetch_now(issue, trigger:, attempt: 1)
    run = fetch_runs.create!(issue: issue, trigger: trigger, attempt: attempt, status: "running", started_at: Time.current)
    entries = adapter_class.new(self).fetch(period_key: issue&.period_key)
    kept, dropped = entries.partition(&:valid?)
    replace_items(issue, kept) if issue
    run.update!(status: "succeeded", item_count: kept.size, dropped_count: dropped.size, duration_ms: elapsed(run))
    run
  rescue Timeout::Error => e
    run.update!(status: "timed_out", error_summary: e.message.to_s.lines.first.to_s.strip[0, 200], duration_ms: elapsed(run))
    raise
  rescue StandardError => e
    run.update!(status: "failed", error_summary: e.message.to_s.lines.first.to_s.strip[0, 200], duration_ms: elapsed(run))
    raise
  end

  def health
    return "disabled" unless enabled?
    recent = fetch_runs.where(trigger: %w[ scheduled manual ]).ordered.limit(3).pluck(:status)
    return "ok" if recent.empty? || recent.first == "succeeded"
    failures = recent.take_while { |s| s != "succeeded" }.size
    failures >= 3 ? "consecutive_failures" : "recent_failure"
  end

  private
    def replace_items(issue, entries)
      transaction do
        issue.items.where(source: self).delete_all
        rows = entries.map { |e| e.to_item_attributes(source: self, issue: issue) }
        rows.uniq! { |r| r[:url_hash] }   # 同源重复地址保留首次出现
        Item.insert_all!(rows.map { |r| r.merge(id: Lowpass::Uuid.generate, created_at: Time.current, updated_at: Time.current) }) if rows.any?
      end
    end

    def elapsed(run)
      ((Time.current - run.started_at) * 1000).to_i
    end
end

# app/models/source.rb 顶部加 include Source::Fetching

# app/jobs/fetch_source_job.rb
class FetchSourceJob < ApplicationJob
  queue_as :default
  WAITS = [ 30.seconds, 120.seconds ].freeze

  retry_on Adapters::Http::Error, Timeout::Error, wait: ->(executions) { WAITS[executions - 1] || WAITS.last }, attempts: 3
  discard_on Adapters::Http::Blocked   # 429 / 403 不追加请求
  discard_on Adapters::Http::Unresolvable

  def perform(source, issue, trigger)
    source.fetch_now(issue, trigger: trigger, attempt: executions)
  end
end
```

- [ ] **Step 4: 跑测试确认通过**，提交：

```bash
git add app/models/source.rb app/models/source app/jobs/fetch_source_job.rb test/models/source test/jobs && git -c commit.gpgsign=false commit -m "feat: 抓取任务、整栏替换、抓取记录与健康度

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: 日刊生成与发布

**Files:**
- Create: `app/models/issue/daily.rb`、`app/models/issue/finalization.rb`、`test/models/issue/daily_test.rb`
- Modify: `app/models/issue.rb`（include）

**Interfaces:**
- Produces: `Issue.generate_daily!(period_key, late: false) -> Issue`（建期、并行入队所有启用日刊源）；`Issue#finalize_if_done!`（全部源有终态记录则发布或空刊）；`Issue#finalize!(reason:)`（期级超时强制结束）；`Issue#source_state(source) -> "ok" | "failed" | "empty" | "pending"`；`Issue.regenerate_source!(issue, source)`（R-1.5 重抓成功则替换并写 revised_at）。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class Issue::DailyTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ]) }

  def stub_all(entries_by_adapter)
    entries_by_adapter.each { |klass, entries| klass.any_instance.stubs(:fetch).returns(entries) }
  end

  test "AC-1.1 三源成功则发布" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ],
             Adapters::GithubTrending => [ Adapters::Entry.new(title: "g/g", url: "https://g/1") ],
             Adapters::Rss => [ Adapters::Entry.new(title: "r", url: "https://r/1") ])
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.published?
    assert_equal 3, issue.items.count
  end

  test "AC-1.2 一源失败其余照常发布" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ],
             Adapters::Rss => [ Adapters::Entry.new(title: "r", url: "https://r/1") ])
    Adapters::GithubTrending.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.published?
    assert_equal "failed", issue.source_state(sources(:github))
    assert_equal "ok", issue.source_state(sources(:hn))
  end

  test "AC-1.4 全部失败则空刊" do
    Adapters::HackerNews.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    Adapters::GithubTrending.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    Adapters::Rss.any_instance.stubs(:fetch).raises(Adapters::Http::Blocked, "403")
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.empty?
  end

  test "源成功但 0 条视为成功，状态是无新内容" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ], Adapters::GithubTrending => [], Adapters::Rss => [])
    issue = Issue.generate_daily!("2026-09-10")
    perform_enqueued_jobs
    assert issue.reload.published?
    assert_equal "empty", issue.source_state(sources(:github))
  end

  test "期级超时按已完成结果发布" do
    stub_all(Adapters::HackerNews => [ Adapters::Entry.new(title: "h", url: "https://h/1") ])
    issue = Issue.generate_daily!("2026-09-10")
    sources(:hn).fetch_now(issue, trigger: "scheduled")
    travel 21.minutes
    issue.finalize!(reason: "timeout")
    assert issue.reload.published?
    assert_equal "failed", issue.source_state(sources(:github))
  end

  test "重抓成功整栏替换并写修订时间" do
    issue = issues(:daily_0908)
    Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "新", url: "https://h/new") ])
    Issue.regenerate_source!(issue, sources(:hn))
    assert_equal [ "新" ], issue.items.where(source: sources(:hn)).pluck(:title)
    assert issue.reload.revised_at.present?
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

```ruby
# app/models/issue/daily.rb
module Issue::Daily
  extend ActiveSupport::Concern
  ISSUE_TIMEOUT = 20.minutes

  class_methods do
    def generate_daily!(period_key, late: false, trigger: "scheduled")
      issue = daily.create!(period_key: period_key, state: "generating", generation_started_at: Time.current, generated_late: late)
      Source.enabled.daily.find_each { |source| source.fetch_later(issue, trigger: trigger) }
      issue
    end

    def regenerate_source!(issue, source)
      run = source.fetch_now(issue, trigger: "manual")
      issue.update!(revised_at: Time.current, state: "published", published_at: issue.published_at || Time.current) if run.status == "succeeded"
      run
    end
  end

  def daily_sources
    Source.enabled.daily.ordered
  end

  def source_state(source)
    last = fetch_runs.where(source: source).ordered.first
    return "pending" if last.nil? || last.status.in?(%w[ queued running ])
    return "failed" unless last.status == "succeeded"
    last.item_count.to_i.zero? ? "empty" : "ok"
  end

  def timed_out?
    generating? && generation_started_at < ISSUE_TIMEOUT.ago
  end
end

# app/models/issue/finalization.rb
module Issue::Finalization
  extend ActiveSupport::Concern

  def finalize_if_done!
    return unless generating?
    finalize!(reason: "complete") if daily_sources.all? { |s| source_state(s) != "pending" }
  end

  def finalize!(reason:)
    return unless generating?
    succeeded = daily_sources.any? { |s| source_state(s).in?(%w[ ok empty ]) }
    update!(state: succeeded ? "published" : "empty", published_at: Time.current)
  end
end
```

`app/models/issue.rb` 里 `include Issue::Daily, Issue::Finalization`。`Source::Fetching#fetch_now` 末尾（成功与失败路径都要）加一行 `issue&.finalize_if_done!`——放在 `ensure` 里，但只在没有后续重试时才算终态：把 `finalize_if_done!` 改成只看"最近一条记录是终态且 attempt == 3 或 succeeded"：

```ruby
# Issue::Daily#source_state 里的 pending 判断改为：
def source_state(source)
  last = fetch_runs.where(source: source).ordered.first
  return "pending" if last.nil? || last.status.in?(%w[ queued running ])
  return "pending" if last.status != "succeeded" && last.attempt < FetchSourceJob::MAX_ATTEMPTS && !timed_out?
  return "failed" unless last.status == "succeeded"
  last.item_count.to_i.zero? ? "empty" : "ok"
end
```

并在 `FetchSourceJob` 里加 `MAX_ATTEMPTS = 3`，`perform` 末尾 `ensure issue&.finalize_if_done!`。

- [ ] **Step 4: 跑测试确认通过**，提交：

```bash
git add app/models/issue.rb app/models/issue app/models/source app/jobs test/models/issue && git -c commit.gpgsign=false commit -m "feat: 日刊生成、发布条件、期级超时与整栏重抓

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 14: 每分钟调度 tick 与补跑

**Files:**
- Create: `app/models/scheduler.rb`、`app/jobs/scheduler_tick_job.rb`、`config/recurring.yml`、`test/models/scheduler_test.rb`

**Interfaces:**
- Produces: `Scheduler.tick(now: Time.current)`：到达或错过当日日刊时间且当日无期 → `Issue.generate_daily!(today, late: 迟于设定 1 分钟以上)`；生成中且超过 20 分钟的期 → `finalize!(reason: "timeout")`；到达周刊检查时间且今天未检查 → `WeeklyCheckJob.perform_later`（Task 15）；每日 04:00 后 `FetchRun.cleanup`。`config/recurring.yml` 每分钟跑 `SchedulerTickJob`。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class SchedulerTest < ActiveSupport::TestCase
  setup { Issue.stubs(:generate_daily!).returns(Issue.new) }

  def sh(str) = Time.find_zone("Asia/Shanghai").parse(str)

  test "AC-1.1 到点生成当日期" do
    Issue.expects(:generate_daily!).with("2026-09-10", late: false).once
    Scheduler.tick(now: sh("2026-09-10 06:00:30"))
  end

  test "未到点不生成" do
    Issue.expects(:generate_daily!).never
    Scheduler.tick(now: sh("2026-09-10 05:59:00"))
  end

  test "AC-1.7 错过调度后补跑并标记延迟" do
    Issue.expects(:generate_daily!).with("2026-09-10", late: true).once
    Scheduler.tick(now: sh("2026-09-10 07:05:00"))
  end

  test "当日已有期就不再生成" do
    Issue.unstub(:generate_daily!)
    Issue.daily.create!(period_key: "2026-09-08", state: "published", generation_started_at: Time.current)
    assert_no_difference("Issue.count") { Scheduler.tick(now: sh("2026-09-08 07:00:00")) }
  end

  test "生成中超过 20 分钟的期被收尾" do
    Issue.unstub(:generate_daily!)
    issue = Issue.daily.create!(period_key: "2026-09-10", state: "generating", generation_started_at: sh("2026-09-10 06:00:00"))
    Scheduler.tick(now: sh("2026-09-10 06:21:00"))
    assert_not issue.reload.generating?
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

```ruby
# app/models/scheduler.rb
class Scheduler
  LATE_AFTER = 1.minute

  def self.tick(now: Time.current)
    new(now).tick
  end

  def initialize(now)
    @now = now.in_time_zone(PeriodKey::ZONE)
  end

  def tick
    generate_daily_if_due
    finalize_stale_issues
    check_weekly_if_due
    cleanup_if_due
  end

  private
    def generate_daily_if_due
      due_at = today_at(Setting.get("daily_time"))
      return if @now < due_at
      key = PeriodKey.daily(@now)
      return if Issue.daily.exists?(period_key: key)
      Issue.generate_daily!(key, late: @now - due_at > LATE_AFTER)
    end

    def finalize_stale_issues
      Issue.daily.where(state: "generating").where(generation_started_at: ...Issue::Daily::ISSUE_TIMEOUT.ago).find_each { |i| i.finalize!(reason: "timeout") }
    end

    def check_weekly_if_due
      due_at = today_at(Setting.get("weekly_time"))
      return if @now < due_at || Setting.get("weekly_checked_on") == PeriodKey.daily(@now)
      Setting.set("weekly_checked_on", PeriodKey.daily(@now))
      WeeklyCheckJob.perform_later
    end

    def cleanup_if_due
      return unless @now.hour == 4 && @now.min == 2
      FetchRun.cleanup
    end

    def today_at(hhmm)
      h, m = hhmm.split(":").map(&:to_i)
      @now.change(hour: h, min: m, sec: 0)
    end
end

# app/jobs/scheduler_tick_job.rb
class SchedulerTickJob < ApplicationJob
  queue_as :default
  def perform = Scheduler.tick
end
```

`Setting::DEFAULTS` 加 `"weekly_checked_on" => ""`。`config/recurring.yml`：

```yaml
production: &production
  scheduler_tick:
    class: SchedulerTickJob
    schedule: every minute
development: *production
```

Task 15 之前先建一个空的 `WeeklyCheckJob`（`def perform; end`）让测试能过。

- [ ] **Step 4: 跑测试确认通过**；本地起 `bin/dev`，观察 `log/development.log` 里每分钟出现一次 `SchedulerTickJob`。提交：

```bash
git add app/models/scheduler.rb app/models/setting.rb app/jobs config/recurring.yml test/models/scheduler_test.rb && git -c commit.gpgsign=false commit -m "feat: 每分钟调度 tick，到点生成、错过补跑、超时收尾

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 15: 周刊检查与装订

**Files:**
- Create: `app/models/issue/weekly.rb`、`app/jobs/weekly_check_job.rb`、`test/models/issue/weekly_test.rb`
- Modify: `app/models/issue.rb`、`app/models/source/fetching.rb`

**Interfaces:**
- Produces: `Issue.check_weekly_sources!`：对每个启用周刊源，阮一峰取最新期号，若该期号还没入库则按发布日所在 ISO 周找或建周刊期并整节写入（降级时写一条整期条目并在 meta 标 `degraded: true`）；RSS 周刊源按本周 `period_key` 抓取写入本周期；周刊期至少一源有内容才存在（R-2.7）；`Issue#weekly_sections -> [{ source:, issue_no:, issue_title:, degraded:, sections: [[name, items]] }]`。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class Issue::WeeklyTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ]) }

  def entries(n, section: "科技动态", published: Time.utc(2026, 9, 4))
    (1..n).map { |i| Adapters::Entry.new(title: "t#{i}", url: "https://x/#{i}", section: section, published_at: published, rank: i, meta: { issue_no: 367, issue_title: "主题" }) }
  end

  test "AC-2.1 新期归入发布日所在 ISO 周" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).with(367).returns(entries(6, published: Time.utc(2026, 9, 11)))
    Issue.check_weekly_sources!
    issue = Issue.weekly.find_by!(period_key: "2026-W37")
    assert_equal 6, issue.items.count
    assert issue.published?
  end

  test "AC-2.2 少于 5 条降级为整期一条" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    err = Adapters::RuanyfWeekly::Degraded.new("x").tap { |e| e.issue_no = 367; e.issue_title = "坏了"; e.url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-367.md" }
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).raises(err)
    Issue.check_weekly_sources!
    item = Issue.weekly.order(:period_key).last.items.sole
    assert item.meta["degraded"]
    assert_equal err.url, item.url
  end

  test "AC-2.6 上周五的期本周一才检测到，仍归上周" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).returns(entries(6, published: Time.utc(2026, 9, 4)))
    travel_to Time.utc(2026, 9, 7, 1, 0) { Issue.check_weekly_sources! }
    assert Issue.weekly.exists?(period_key: "2026-W36")
    assert_not Issue.weekly.exists?(period_key: "2026-W37")
  end

  test "已入库的期号不重复写" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).never
    issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })
    Issue.check_weekly_sources!
  end

  test "AC-2.4 所有源无内容则不生成期" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
    issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })
    assert_no_difference("Issue.weekly.count") { Issue.check_weekly_sources! }
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

```ruby
# app/models/issue/weekly.rb
module Issue::Weekly
  extend ActiveSupport::Concern

  class_methods do
    def check_weekly_sources!
      Source.enabled.weekly.ordered.find_each do |source|
        case source.adapter
        when "ruanyf_weekly" then ingest_ruanyf(source)
        else ingest_rss_weekly(source)
        end
      end
    end

    def weekly_for!(period_key)
      weekly.find_or_create_by!(period_key: period_key) { |i| i.state = "generating"; i.generation_started_at = Time.current }
    end

    private
      def ingest_ruanyf(source)
        adapter = source.adapter_class.new(source)
        n = adapter.latest_issue_number
        return if Item.where(source: source).where("meta->>'issue_no' = ?", n.to_s).exists?
        run = source.fetch_runs.create!(trigger: "scheduled", attempt: 1, status: "running", started_at: Time.current)
        begin
          entries = adapter.fetch_issue(n)
          issue = weekly_for!(PeriodKey.weekly(entries.first.published_at || Time.current))
          issue.write_section!(source, entries)
          run.update!(status: "succeeded", item_count: entries.size, dropped_count: 0)
        rescue Adapters::RuanyfWeekly::Degraded => e
          issue = weekly_for!(PeriodKey.weekly(Time.current))
          issue.write_section!(source, [ Adapters::Entry.new(title: "科技爱好者周刊（第 #{e.issue_no} 期）：#{e.issue_title}", url: e.url, rank: 1, meta: { issue_no: e.issue_no, issue_title: e.issue_title, degraded: true }) ])
          run.update!(status: "succeeded", item_count: 1, dropped_count: 0, error_summary: "降级：#{e.message}"[0, 200])
        rescue StandardError => e
          run.update!(status: "failed", error_summary: e.message.to_s[0, 200])
        end
      end

      def ingest_rss_weekly(source)
        key = PeriodKey.this_week
        entries = source.adapter_class.new(source).fetch(period_key: key)
        return if entries.empty?
        weekly_for!(key).write_section!(source, entries)
      end
  end

  def write_section!(source, entries)
    transaction do
      items.where(source: source).delete_all
      rows = entries.select(&:valid?).map { |e| e.to_item_attributes(source: source, issue: self).merge(id: Lowpass::Uuid.generate, created_at: Time.current, updated_at: Time.current) }
      Item.insert_all!(rows) if rows.any?
      update!(state: "published", published_at: published_at || Time.current)
    end
  end

  def weekly_sections
    items.visible.includes(:source).group_by(&:source).map do |source, list|
      first = list.min_by(&:rank)
      { source: source, issue_no: first.meta["issue_no"], issue_title: first.meta["issue_title"], degraded: first.meta["degraded"] == true,
        sections: list.sort_by(&:rank).group_by(&:section).map { |name, its| [ name, its ] } }
    end
  end
end

# app/jobs/weekly_check_job.rb
class WeeklyCheckJob < ApplicationJob
  queue_as :default
  def perform = Issue.check_weekly_sources!
end
```

`app/models/issue.rb` 加 `include Issue::Weekly`。

- [ ] **Step 4: 跑测试确认通过**，提交：

```bash
git add app/models/issue.rb app/models/issue/weekly.rb app/jobs/weekly_check_job.rb test/models/issue/weekly_test.rb && git -c commit.gpgsign=false commit -m "feat: 周刊检查、按 ISO 周装订、降级为整期一条

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 16: Inertia + React + TypeScript 基线与设计令牌

**Files:**
- Create: `app/frontend/entrypoints/application.tsx`、`app/frontend/entrypoints/application.css`、`app/frontend/styles/tokens.css`、`app/frontend/styles/fonts.css`、`app/frontend/components/Layout.tsx`、`app/frontend/components/Masthead.tsx`、`app/frontend/components/Footer.tsx`、`app/frontend/types/lowpass.ts`、`app/frontend/fonts/MapleMonoNL-Regular.woff2`、`app/views/layouts/application.html.erb`（改）、`config/initializers/inertia_rails.rb`、`vite.config.ts`、`tsconfig.json`、`components.json`
- Modify: `Gemfile`（已有）、`package.json`

**Interfaces:**
- Produces: `bin/dev` 起来后访问 `/` 能渲染一个 Inertia 页面；`Layout` 提供报头（LOWPASS、日刊、周刊、搜索入口图标、头像位）与页脚；`tokens.css` 定义六个颜色与四个字体角色；`types/lowpass.ts` 定义 props 契约的基础类型。

- [ ] **Step 1: 安装 Inertia 与 Vite**

```bash
bin/rails generate inertia:install --framework=react --typescript --tailwind --vite --package-manager=npm --no-interactive
```

生成器的选项名以 `bin/rails generate inertia:install --help` 输出为准（不同小版本略有差异，目标是：React、TypeScript、Tailwind、Vite、npm、非交互）。生成 `app/frontend/entrypoints/inertia.ts` 等；把入口重命名为 `application.tsx` 并在 `app/views/layouts/application.html.erb` 里保留 `vite_client_tag`、`vite_typescript_tag "application"`、`vite_stylesheet_tag "application"`。确认 `bin/dev` 后 `http://localhost:3000` 出现 Inertia 示例页。

- [ ] **Step 2: shadcn 基线**

```bash
npx shadcn@latest init --defaults --base-color neutral --css app/frontend/entrypoints/application.css
npx shadcn@latest add button tabs
```

`components.json` 的 `aliases` 指向 `app/frontend/components`、`app/frontend/lib`；`tsconfig.json` 加 `"paths": { "@/*": ["./app/frontend/*"] }`；`vite.config.ts` 加同样的 alias。shadcn 组件只作为可及性与键盘行为的底座，外观全部由令牌覆盖：无圆角、无阴影。

- [ ] **Step 3: 字体与令牌**

```bash
npm install lxgw-wenkai-screen-webfont
```

从 `docs/design/fonts/` 之外的原始 Maple Mono NL 包里取 `MapleMonoNL-Regular.woff2` 放到 `app/frontend/fonts/`（设计画布用的是子集，网站用完整字重）。

`app/frontend/styles/fonts.css`：

```css
@import "lxgw-wenkai-screen-webfont/style.css";      /* 按 unicode-range 分包，只下载用到的 */
@import url("https://fonts.googleapis.com/css2?family=Bodoni+Moda:opsz,wght@6..96,900&family=Newsreader:ital,opsz,wght@0,6..72,400..600&display=swap");

@font-face {
  font-family: "Maple Mono NL";
  src: url("../fonts/MapleMonoNL-Regular.woff2") format("woff2");
  font-weight: 400;
  font-display: swap;
}
```

`app/frontend/styles/tokens.css`：

```css
:root {
  --ground: #26241F;
  --paper: #E8E3DA;
  --ink: #1D1D1B;
  --ink2: #55504B;
  --green: #96B59F;
  --rule: rgba(29, 29, 27, 0.35);
  --underline: rgba(29, 29, 27, 0.30);

  --font-brand: "Bodoni Moda", serif;
  --font-latin: "Newsreader", "LXGW WenKai Screen", serif;
  --font-cjk: "LXGW WenKai Screen", "Songti SC", serif;
  --font-data: "Maple Mono NL", ui-monospace, monospace;

  /* 字号八档 + 来源名一档 */
  --fs-12: 12px; --fs-13: 13px; --fs-15: 15px; --fs-20: 20px; --fs-22: 22px; --fs-26: 26px; --fs-32: 32px; --fs-40: 40px; --fs-56: 56px;
}

html { background: var(--ground); color-scheme: light; }
body { margin: 0; color: var(--ink); font-family: var(--font-latin); font-size: var(--fs-15); }
.paper {
  background: var(--paper) repeating-linear-gradient(0deg, rgba(29,29,27,0.03) 0 1px, transparent 1px 3px),
              repeating-linear-gradient(90deg, rgba(255,255,255,0.14) 0 1px, transparent 1px 4px);
  box-shadow: 0 30px 80px rgba(0,0,0,0.45);
}
.cjk { font-family: var(--font-cjk); }
.data { font-family: var(--font-data); font-size: var(--fs-13); color: var(--ink2); }
a { color: inherit; text-decoration: none; }
a.t { text-decoration: underline; text-decoration-color: var(--underline); text-decoration-thickness: 1px; text-underline-offset: 4px; }
a.t:hover { text-decoration-color: var(--ink); }
```

`application.css` 顶部 `@import "../styles/fonts.css"; @import "../styles/tokens.css";`，其后保留 Tailwind 的 `@import "tailwindcss";`。

- [ ] **Step 4: 报头、页脚与布局**

`app/frontend/types/lowpass.ts`：

```ts
export type SourceSummary = { id: string; name: string; adapter: "hacker_news" | "github_trending" | "rss" | "ruanyf_weekly"; state: "ok" | "empty" | "failed" | "pending" };
export type ItemMeta = { score?: number; comments?: number; comments_url?: string; language?: string; stars?: number; stars_today?: number; issue_no?: number; issue_title?: string; degraded?: boolean };
export type Item = { id: string; title: string; url: string; summary: string | null; section: string | null; author: string | null; published_at: string | null; rank: number | null; meta: ItemMeta; reason: string | null; interest_tag: string | null };
export type IssueState = "generating" | "published" | "empty";
export type DailyIssue = { period_key: string; date_label: string; weekday: string; state: IssueState; published_at: string | null; revised_at: string | null; generated_late: boolean; is_yesterday: boolean; prev_key: string | null; next_key: string | null };
export type ArchiveDay = { period_key: string; date_label: string; weekday: string; state: IssueState | "missing"; published_label: string | null; source_marks: string | null };
```

`Masthead.tsx`（80px 墨色横带，LOWPASS 用 `--font-brand` 40px 纸色，导航文楷 15，右侧搜索图标与头像位）、`Footer.tsx`（LP 邮戳、`明早 06:00 · 下一期`、最新周刊链接、前后期按钮）、`Layout.tsx`（`<div class="paper" style="width:1240px;margin:32px auto">` 包住 Masthead + children + Footer；390px 以下改 24px 边距整宽）。样式值逐项对照 `.claude/skills/lowpass-design-taste/reference/lowpass-tokens.md`。

- [ ] **Step 5: 验证**

`bin/dev`，打开 `http://localhost:3000`，`Layout` 里放一个占位页：报头黑带、纸面、页脚可见；浏览器控制台无 404（字体分包按需加载）。`npm run build` 成功。

- [ ] **Step 6: 提交**

```bash
git add -A && git -c commit.gpgsign=false commit -m "feat: Inertia + React + TypeScript 基线，设计令牌、字体、报头与页脚

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 17: 日刊页与首页

**Files:**
- Create: `app/controllers/daily_issues_controller.rb`、`app/models/issue/presenting.rb`、`app/frontend/pages/Daily/Show.tsx`、`app/frontend/components/{IssueHead,SourceTabs,ItemRow,SourceState}.tsx`、`test/controllers/daily_issues_controller_test.rb`
- Modify: `config/routes.rb`、`app/models/issue.rb`

**Interfaces:**
- Consumes: `Issue.daily`、`Issue#source_state`、`Item`
- Produces: 路由 `root "daily_issues#latest"`、`get "/daily/:period_key"`；props `{ issue: DailyIssue, sources: SourceSummary[], items_by_source: Record<string, Item[]>, active_source_id: string, missing: boolean }`；期头状态按 D20 与附录 B：已发布 hh:mm、`生成中，约 1 分钟后刷新`、`今日为空刊，管理员已收到通知`、`本期未生成`、`昨日日刊，今日将于 06:00 生成`、`延迟生成于 hh:mm`、`已于 hh:mm 修订`；来源索引条一次只显示一个来源，默认排序第一的源；条目十条一致。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class DailyIssuesControllerTest < ActionDispatch::IntegrationTest
  test "首页渲染最新一期" do
    get root_path
    assert_response :success
    assert_includes response.body, "2026-09-08"
  end

  test "按周期键打开一期" do
    get daily_issue_path("2026-09-08")
    assert_response :success
    assert_includes response.body, "Show HN: A terminal log viewer written in Rust"
  end

  test "缺期显示本期未生成而不是 404" do
    get daily_issue_path("2026-09-03")
    assert_response :success
    assert_includes response.body, "本期未生成"
  end

  test "非法周期键 404" do
    get daily_issue_path("nope")
    assert_response :not_found
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

`config/routes.rb`：

```ruby
Rails.application.routes.draw do
  root "daily_issues#latest"
  resources :daily_issues, path: "daily", only: [ :index, :show ], param: :period_key
  resources :weekly_issues, path: "weekly", only: [ :index, :show ], param: :period_key
  get "up" => "rails/health#show", as: :rails_health_check
end
```

`app/models/issue/presenting.rb`：

```ruby
module Issue::Presenting
  extend ActiveSupport::Concern
  WEEKDAYS = %w[ 星期日 星期一 星期二 星期三 星期四 星期五 星期六 ].freeze

  class_methods do
    def daily_props_for(period_key, now: Time.current)
      issue = daily.find_by(period_key: period_key)
      date = PeriodKey.date_of(period_key)
      {
        period_key: period_key,
        date_label: "#{date.month}月#{date.day}日",
        weekday: WEEKDAYS[date.wday],
        state: issue&.state,
        published_at: issue&.published_at&.in_time_zone(PeriodKey::ZONE)&.strftime("%H:%M"),
        revised_at: issue&.revised_at&.in_time_zone(PeriodKey::ZONE)&.strftime("%H:%M"),
        generated_late: issue&.generated_late || false,
        is_yesterday: period_key == PeriodKey.daily(now - 1.day) && now.in_time_zone(PeriodKey::ZONE).hour < 6 && !daily.exists?(period_key: PeriodKey.daily(now)),
        prev_key: daily.where("period_key < ?", period_key).maximum(:period_key),
        next_key: daily.where("period_key > ?", period_key).minimum(:period_key)
      }
    end
  end

  def items_by_source
    items.visible.ranked.group_by(&:source_id).transform_values { |list| list.map { |i| i.as_json(only: %i[ id title url summary section author published_at rank meta reason interest_tag ]) } }
  end
end

# app/controllers/daily_issues_controller.rb
class DailyIssuesController < ApplicationController
  def latest
    key = Issue.daily.maximum(:period_key) || PeriodKey.today
    redirect_to daily_issue_path(key)
  end

  def show
    key = params[:period_key]
    head :not_found and return unless key.match?(PeriodKey::DAILY)
    issue = Issue.daily.find_by(period_key: key)
    sources = Source.enabled.daily.ordered
    render inertia: "Daily/Show", props: {
      issue: Issue.daily_props_for(key),
      missing: issue.nil?,
      sources: sources.map { |s| { id: s.id, name: s.name, adapter: s.adapter, state: issue ? issue.source_state(s) : "pending" } },
      items_by_source: issue ? issue.items_by_source : {},
      active_source_id: params[:source].presence_in(sources.map(&:id)) || sources.first&.id
    }
  end

  def index
    # Task 18
  end
end
```

`Daily/Show.tsx`：期头（`IssueHead`：文楷 56 日期，右侧叠放 Maple 13 发布时间与文楷 20 星期，状态标签用时钟图标 + 文楷 12；右端 40px 描边按钮前一期 / 归档 / 后一期，最新期禁用后一期）；`SourceTabs`（三条并排索引条，当前项反白，来源名 Newsreader 600 32px，44px 墨线图标；失败或无新内容的源在名字下一行小字）；列表（`ItemRow`：序号 Maple 13、标题 Newsreader 20 细下划线、说明 15、元数据行只有数字与记号，HN 为 `▲ 312 · [message-square] 145 · 5h`，GitHub 为 `Zig · ★ 12.3k · +420`，前三名今日新增用绿徽章；有 `reason` 时显示绿色竖线的推荐理由与反白兴趣标签，P0 数据里为空则不渲染）；`SourceState`（失败：日出小图 + `今日抓取失败，已通知管理员` + `上次成功 …`；无新内容：`今日无新内容`）；缺期：`本期未生成`；空刊、生成中、延迟、昨日、已修订按 props 映射到期头标签与说明句。每个字符串常量来自附录 B，不新造文案。

- [ ] **Step 4: 跑测试确认通过**；`bin/dev` 打开 `/`，用 `bin/rails runner 'Issue.generate_daily!(PeriodKey.today)'` 生成一期（需要网络；或用 `bin/rails db:seed` 后手动 `Source.first.fetch_now(...)`），对照画布上的 Main 与 FrontStates 逐项核对；390px 宽度下检查手机版式（眉行、整宽标题、44px 按钮）。

- [ ] **Step 5: 提交**

```bash
git add -A && git -c commit.gpgsign=false commit -m "feat: 日刊页与首页，期头状态、来源索引条、条目列表

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 18: 日刊归档、周刊页、周刊归档

**Files:**
- Create: `app/controllers/weekly_issues_controller.rb`、`app/frontend/pages/Daily/Index.tsx`、`app/frontend/pages/Weekly/Show.tsx`、`app/frontend/pages/Weekly/Index.tsx`、`test/controllers/weekly_issues_controller_test.rb`
- Modify: `app/controllers/daily_issues_controller.rb`、`app/models/issue/presenting.rb`

**Interfaces:**
- Produces: `/daily` 按月分组（当月默认展开，每天一行：状态记号、日期、星期、发布信息、各源结果如 `HN 10 · GH 0 · HAD 失败`；缺期行也列出，标 `缺期`）；`/weekly/:period_key`（期头 `第 36 周` + `2026` + `8月31日 至 9月6日`；每源一节：反白横带（源名、`第 366 期 · 主题`、原文外链）、阮一峰按板块分节与锚点行，RSS 源按时间倒序带发布时间；降级节显示 `本期解析失败，已保留原文链接`）；`/weekly` 按年分组（每周一行：周次、日期范围、各源期号与主题、条数；没有期的周显示 `本周无内容`）。

- [ ] **Step 1: 失败测试**

```ruby
require "test_helper"

class WeeklyIssuesControllerTest < ActionDispatch::IntegrationTest
  test "周刊页按板块分节" do
    issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "慢下来的理由", url: "https://r/1", url_hash: "1" * 64, section: "本周话题", rank: 1, fetched_at: Time.current, meta: { issue_no: 366, issue_title: "慢下来的理由" })
    get weekly_issue_path("2026-W36")
    assert_response :success
    assert_includes response.body, "本周话题"
    assert_includes response.body, "第 366 期"
  end

  test "周刊归档标出无内容的周" do
    get weekly_issues_path
    assert_response :success
    assert_includes response.body, "本周无内容"
  end
end

class DailyArchiveTest < ActionDispatch::IntegrationTest
  test "日刊归档按月列出并标缺期" do
    get daily_issues_path
    assert_response :success
    assert_includes response.body, "缺期"
  end
end
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

`Issue::Presenting` 加：

```ruby
class_methods do
  def daily_archive_props(month: Date.current.in_time_zone(PeriodKey::ZONE).to_date)
    first = month.beginning_of_month
    last = [ month.end_of_month, PeriodKey.date_of(PeriodKey.today) ].min
    existing = daily.where(period_key: first.iso8601..last.iso8601).includes(:fetch_runs).index_by(&:period_key)
    days = (first..last).to_a.reverse.map do |d|
      key = d.iso8601
      issue = existing[key]
      { period_key: key, date_label: "#{d.month}月#{d.day}日", weekday: WEEKDAYS[d.wday],
        state: issue&.state || "missing",
        published_label: issue && (issue.generated_late ? "延迟生成于 #{issue.published_at&.in_time_zone(PeriodKey::ZONE)&.strftime('%H:%M')}" : "#{issue.published_at&.in_time_zone(PeriodKey::ZONE)&.strftime('%H:%M')} 发布") + (issue&.revised_at ? " · 已于 #{issue.revised_at.in_time_zone(PeriodKey::ZONE).strftime('%H:%M')} 修订" : ""),
        source_marks: issue && Source.enabled.daily.ordered.map { |s| "#{abbr(s)} #{mark(issue, s)}" }.join(" · ") }
    end
    { month_label: "#{month.year} 年 #{month.month} 月", days: days, prev_month: (first - 1).beginning_of_month.iso8601, next_month: (last + 1 > Date.current ? nil : (last + 1).iso8601) }
  end

  def weekly_archive_props(year: Date.current.year)
    keys = (1..Date.new(year, 12, 28).cweek).map { |w| format("%d-W%02d", year, w) }.select { |k| PeriodKey.week_range(k).first <= Date.current }.reverse
    existing = weekly.where(period_key: keys).includes(items: :source).index_by(&:period_key)
    { year: year, weeks: keys.map { |k| issue = existing[k]; range = PeriodKey.week_range(k)
      { period_key: k, label: "第 #{k[-2, 2].to_i} 周", range_label: "#{range.first.month}月#{range.first.day}日 至 #{range.last.month}月#{range.last.day}日",
        summary: issue ? issue.weekly_sections.map { |s| "#{s[:source].name} 第 #{s[:issue_no]} 期 · #{s[:issue_title]}" }.join(" / ") : "本周无内容",
        count: issue&.items&.count } } }
  end

  private
    def abbr(source) = { "hacker_news" => "HN", "github_trending" => "GH" }.fetch(source.adapter, source.name[0, 3].upcase)
    def mark(issue, source)
      case issue.source_state(source)
      when "ok" then issue.items.where(source: source).count.to_s
      when "empty" then "0"
      else "失败"
      end
    end
end
```

`WeeklyIssuesController#show` 用 `issue.weekly_sections` 作 props（每节含 source、issue_no、issue_title、degraded、sections: [[name, items]]，加 `week_label`、`range_label`、`year`、`prev_key`、`next_key`）；`#index` 用 `weekly_archive_props`；`DailyIssuesController#index` 用 `daily_archive_props(month:)`。三个页面照画布 SiteWeekly、SiteWeeklyStates、SiteArchiveDaily、SiteArchiveWeekly 实现，令牌同 Task 16。

- [ ] **Step 4: 跑测试确认通过**；`bin/rails runner 'Issue.check_weekly_sources!'` 抓一期真实周刊（需要网络），打开 `/weekly` 与 `/weekly/<key>` 核对板块与锚点。

- [ ] **Step 5: 提交**

```bash
git add -A && git -c commit.gpgsign=false commit -m "feat: 日刊归档、周刊页与周刊归档

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 19: P0 退出清单

**Files:**
- Create: `docs/development.md`、`test/integration/p0_exit_test.rb`
- Modify: `config/ci.rb`（加前端检查）、`README.md`

**Interfaces:**
- Produces: `bin/ci` 全绿；`docs/development.md` 写清 setup、跑测试、抓样本、手动生成一期；`README.md` 一段说明并指向 PRD 与画布。

- [ ] **Step 1: 退出清单测试**

```ruby
require "test_helper"

class P0ExitTest < ActiveSupport::TestCase
  test "四个适配器都有基于样本的测试" do
    %w[ hacker_news github_trending rss ruanyf_weekly ].each do |a|
      assert File.exist?(Rails.root.join("test/models/adapters/#{a}_test.rb")), a
    end
    assert Dir[Rails.root.join("test/fixtures/files/ruanyf/issue-*.md")].size >= 20
  end

  test "缺期、延迟、空刊三条路径都有测试" do
    src = File.read(Rails.root.join("test/models/scheduler_test.rb")) + File.read(Rails.root.join("test/models/issue/daily_test.rb"))
    assert_includes src, "late: true"
    assert_includes src, "empty?"
    assert_includes src, "finalize!"
  end
end
```

- [ ] **Step 2: `config/ci.rb` 追加**

```ruby
step "Frontend: typecheck", "npx tsc --noEmit"
step "Frontend: audit", "npm audit --audit-level=high"
step "Frontend: build", "npm run build"
```

- [ ] **Step 3: 文档**

`docs/development.md`：setup（`bin/setup`）、运行（`bin/dev`，`http://localhost:3000`）、测试（`bin/rails test`、`bin/ci`）、样本（`script/capture_samples …`）、手动生成一期（`bin/rails runner 'Scheduler.tick'` 或 `Issue.generate_daily!(PeriodKey.today, trigger: "manual")`）、周刊（`Issue.check_weekly_sources!`）、队列面板（`/jobs`，P0 只在开发环境挂载 `mission_control-jobs`）。`README.md` 三段：产品一句话、文档入口（PRD、ADR、AGENTS.md、设计画布链接）、开发入口。

- [ ] **Step 4: 跑 `bin/ci`**，全绿后提交：

```bash
git add -A && git -c commit.gpgsign=false commit -m "docs: 开发指南与 P0 退出清单；CI 加前端检查

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```

- [ ] **Step 5: 连续 5 天验收**

在开发机或内网机器上跑 `bin/dev`（或 `bin/jobs` 单独跑队列）连续 5 天，每天 06:00 后打开 `/` 核对：期已发布、三个来源可切换、归档里有当天一行。记录在 `docs/design/notes/` 之外的 `docs/superpowers/plans/2026-09-09-p0-fetch-and-read.md` 末尾"验收记录"一节，附每日的 `FetchRun` 状态。

---

## 自检

- **规格覆盖**：F-01（Task 13、14）、F-02（17）、F-03（17、18）、F-04（17）、F-06（11、15、18）、F-07（18）、F-08（10、15、18）、F-26 抓取日志 30 天（4、14）、F-27（17）；P0 退出清单四条（19）。F-09 到 F-12、F-14 到 F-21、F-25、F-28 属 P1 / P2 阶段，不在本计划。推荐理由（D16）等 T8 定后另写小计划。
- **占位扫描**：无 TBD；每个代码步骤都有完整代码；Task 16 与 17、18 的 React 组件以画布与令牌文件为像素依据，组件文件名与 props 类型已定义。
- **类型一致**：`Adapters::Entry` 字段、`Item` 列、`types/lowpass.ts` 的 `Item` 三者一致；`source_state` 的四个取值在 `SourceSummary.state` 中一致；`PeriodKey::DAILY`、`WEEKLY` 正则在控制器复用；`FetchSourceJob::MAX_ATTEMPTS` 与 `WAITS` 长度对应 3 次尝试。

---

## 验收记录

Task 19 Step 5（连续 5 天验收）尚未开始：本次提交只完成了 Step 1 到 4（退出清单测试、CI 加前端检查、
补文档、`bin/ci` 全绿并提交）。Step 5 需要在开发机或内网机器上让 `bin/dev`（或单独跑队列的
`bin/jobs`）连续挂 5 天，每天 06:00 之后按下面的清单核对一次，再把结果填回本节的表格。

每日核对清单：

1. 打开 `/`，确认当日那期日刊已存在且状态是「已发布」（`Issue#state == "published"`；重抓过、带
   `revised_at` 的也算，不算未完成）。
2. 三个来源（Hacker News、GitHub Trending、Hackaday）都能切换查看；每栏要么有条目，要么显示
   「今日无新内容」，不是空白或报错（AC-1.1、AC-1.7）。
3. 打开日刊归档，当天有一行。
4. 记录当天每个源的 `FetchRun` 状态，例如：
   `mise exec -- bin/rails runner 'FetchRun.where(created_at: Date.current.all_day).order(:created_at).each { |r| puts [r.source.name, r.trigger, r.status, r.item_count, r.error_summary].join(" · ") }'`

| 日期 | `/` 已发布 | 三源可切换 | 归档有当天行 | 各源 FetchRun 状态 | 备注 |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
