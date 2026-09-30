# P4 收藏 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 读者在日刊条目、周刊条目与搜索结果上点一下书签就把这条链接留下来，从头像菜单进收藏页能按时间倒序找回、取消与恢复；收藏只有本人可见，管理员重抓换掉条目行之后收藏仍在。

**Architecture:** 一张 `favorites` 表，按 `(user_id, url_hash)` 唯一，收藏时抄条目快照、不引用条目行；取消是真删，恢复凭 `MessageVerifier` 签的一天有效凭据把同一条原样插回去。`FavoritesController` 的 `index` 是 Inertia 页面，`create` / `destroy` 是 fetch 调的 JSON 端点，资源的键是 `url_hash`。日刊、周刊、搜索、收藏四个页面的 props 带一份 `favorites`（这一页里已收藏的 `url_hash`），前端的 `FavoritesProvider` 管乐观更新、失败回滚与提示，并用 `router.replaceProp` 把结果写回 Inertia 当前页。

**Tech Stack:** Rails 8.1、PostgreSQL、Inertia 3.7 / React 19 / TypeScript、Minitest + fixtures、Vitest + Testing Library、Capybara 系统测试。不加任何 gem 或 npm 包。

**Spec:** `docs/superpowers/specs/2026-09-30-favorites-design.md`（默认决定 K1 到 K15）；需求是 `docs/superpowers/specs/2026-09-08-mvp-prd.md` v0.4.1 的 5.10 节（R-10.1 到 R-10.13、AC-10.1 到 AC-10.14、D26 到 D32）；界面稿 `docs/design/notes/2026-09-30-favorites-mock.html`。执行时三份都要读。

**界面稿：** `docs/design/notes/2026-09-30-favorites-mock.html` 随设计文档一起给产品负责人审，审过才开工。对书签的样子或位置有改动时，先改界面稿里的 `<style id="proposed">`，再把同样的改动带进 Task 5 的 Step 5（两处逐字一致）。

**代码的来历：** 本计划里的每一段代码都在一份临时拷贝里按这个顺序实现并跑通过（Rails 757 项、前端 392 项、系统测试 21 项，rubocop 与 brakeman 无告警）。照着做应当一次通过；哪一步的实际输出与「预期」不符，先停下来查原因，不要改测试去迁就。

## Global Constraints

- 需求以 PRD 5.10 为准。界面上出现的每一句文案都逐字来自 PRD 附录 B：「收藏」「收藏：{标题}」「取消收藏：{标题}」「还没有收藏。」「阅读最新日刊」「已取消收藏」「恢复」「收藏没有保存，请重试。」「取消收藏没有保存，请重试。」「操作过于频繁，请稍后再试。」。不加别的句子，不显示收藏总数。
- 颜色、字体、字号只用 `app/frontend/styles/tokens.css` 的令牌；无圆角、无阴影、无新颜色；汉字文楷、英文内容 Newsreader、数字与记号 Maple。新增样式只有 Task 5 那一块，逐字来自界面稿的 `<style id="proposed">`。
- 主键是 25 字符的 base36 字符串（`ApplicationRecord` 自动给）；`string` 列写 `limit` 并加 CHECK 约束；唯一性放数据库；只支持 PostgreSQL。
- 迁移只用 `bin/rails db:migrate:primary`。直接 `bin/rails db:migrate` 会顺手重写 `db/queue_schema.rb`，那是无关改动，不要提交。
- 收藏只经 `Current.user.favorites` 读写；不进后台、审计日志与错误上报（R-10.8）。不加埋点（D32）。
- 代码风格照 `STYLE.md`：展开的条件分支优先于 guard 子句，控制器薄、模型厚；Ruby 过 `bin/rubocop`（rubocop-rails-omakase：数组字面量的方括号内留空格）。前端没有 lint，过 `npm run check`（`noUnusedLocals` 与 `noUnusedParameters` 开着）。
- 测试不碰网络。跑单个 Rails 测试文件用 `bin/rails test FILE`（`bin/rails test:system FILE` 会忽略文件过滤）；跑系统测试前先 `env RAILS_ENV=test bin/vite build --mode test`。
- 不要跑 `bin/dev`：它的 jobs 进程会 tick 调度器、写开发库。要在浏览器里看页面，只起 `bin/rails server`（development 下 Vite 会按需构建）。
- 首屏资源不超过 300 KB（PRD N-1）。改动前 295.14 KB，全部做完应为 297.70 KB 上下。
- 提交：`git -c commit.gpgsign=false commit`，中文主题，最后一行逐字是 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`（不要换成别的模型名）。每个任务一次提交，不推送。

---

### Task 0: 准备工作区（一次）

**Files:** 不改任何文件。

**Interfaces:**
- Produces: 能跑测试的工作区，与一组改动前的基线数字。

- [ ] **Step 1: 装依赖**

新的 worktree 里 `.mise.toml` 还没被信任，也没有 `node_modules`。

```bash
mise trust
npm ci --no-audit --no-fund
```

- [ ] **Step 2: 确认数据库连得上**

```bash
bin/rails runner 'puts ActiveRecord::Base.connection.select_value("select 1")'
```

预期：输出 `1`。报 connection refused 就先 `docker start ares-postgres` 再试。

- [ ] **Step 3: 记下基线**

```bash
env RAILS_ENV=test bin/vite build --mode test
bin/rails test
npm run check
npm test
```

预期：`bin/rails test` 是 `714 runs, … 0 failures, 0 errors`；`npm run check` 没有输出错误；`npm test` 是 `Tests  356 passed`。main 之后又合过东西的话数字会不同：以这一步实际看到的为基线，后面各任务的「改动后」相应顺延。

---

### Task 1: 两个共用方法：所在期标签与不带命中的摘要片段

收藏页的行与搜索结果行用同一句所在期标签、同一套 160 字片段规则。先把它们从搜索里抽出来。

**Files:**
- Modify: `app/models/period_key.rb`、`app/models/search/record.rb`、`app/models/search/highlighter.rb`
- Test: `test/models/period_key_test.rb`、`test/models/search/highlighter_test.rb`（已有的 `test/models/search/record_test.rb` 兜住 `where_label` 没变）

**Interfaces:**
- Produces: `PeriodKey.issue_label(kind, key, section: nil) → String`（`kind` 是 `"daily"` 或 `"weekly"`；日刊「2026年9月8日」，周刊「2026年 · 第 36 周 · 工具」，板块名为空就没有最后一段）；`Search::Highlighter.excerpt(text) → String | nil`（不超过 160 字，截断处以「…」结尾；空文本返回 `nil`）。

- [ ] **Step 1: 写失败的测试**

`test/models/period_key_test.rb`：

```diff
--- a/test/models/period_key_test.rb
+++ b/test/models/period_key_test.rb
@@ -1,6 +1,14 @@
 require "test_helper"
 
 class PeriodKeyTest < ActiveSupport::TestCase
+  # 搜索结果与收藏页共用的所在期标签：保留年份，周刊带板块名（可空）
+  test "所在期标签" do
+    assert_equal "2026年9月8日", PeriodKey.issue_label("daily", "2026-09-08")
+    assert_equal "2026年 · 第 36 周 · 工具", PeriodKey.issue_label("weekly", "2026-W36", section: "工具")
+    assert_equal "2026年 · 第 36 周", PeriodKey.issue_label("weekly", "2026-W36", section: "")
+    assert_equal "2026年 · 第 36 周", PeriodKey.issue_label("weekly", "2026-W36")
+  end
+
   test "日刊按上海时区的自然日" do
     assert_equal "2026-09-08", PeriodKey.daily(Time.utc(2026, 9, 8, 15, 59))   # 上海 23:59
     assert_equal "2026-09-09", PeriodKey.daily(Time.utc(2026, 9, 8, 16, 0))    # 上海 00:00
```

`test/models/search/highlighter_test.rb`：

```diff
--- a/test/models/search/highlighter_test.rb
+++ b/test/models/search/highlighter_test.rb
@@ -6,6 +6,18 @@
   def pairs(runs) = runs.map { |run| [ run[:text], run[:hit] ] }
   def joined(runs) = runs.map { |run| run[:text] }.join
 
+  # 收藏页的摘要片段（R-10.6）：没有查询词，同一套 160 字与不切词的规则
+  test "excerpt 是不带命中的片段：取开头，不超过 160 字，空文本没有片段" do
+    assert_nil Search::Highlighter.excerpt(nil)
+    assert_nil Search::Highlighter.excerpt("")
+    assert_equal "A fast viewer.", Search::Highlighter.excerpt("A fast viewer.")
+
+    long = Search::Highlighter.excerpt("word " * 100)
+    assert long.start_with?("word word")
+    assert long.end_with?("word…")
+    assert_operator long.length, :<=, 160
+  end
+
   test "拉丁词按词首前缀标出，不分大小写，只标前缀相同的部分" do
     assert_equal [ [ "Kuber", true ], [ "netes operator in ", false ], [ "Rust", true ] ],
                  pairs(highlighter("kuber rust").runs("Kubernetes operator in Rust"))
```

- [ ] **Step 2: 跑测试，确认失败**

```bash
bin/rails test test/models/period_key_test.rb test/models/search/highlighter_test.rb
```

预期：2 个 error，分别是 `NoMethodError: undefined method 'issue_label'` 与 `undefined method 'excerpt'`。

- [ ] **Step 3: 实现**

`app/models/period_key.rb`：

```diff
--- a/app/models/period_key.rb
+++ b/app/models/period_key.rb
@@ -35,6 +35,16 @@
     # 期头、归档与搜索结果里的中文日期短语（PRD 6.3：「9月8日」按中文处理，整体用文楷）
     def date_label(date, year: false) = "#{"#{date.year}年" if year}#{date.month}月#{date.day}日"
 
+    # 所在期的标签，搜索结果与收藏页共用：保留年份（列表会跨年），日刊「2026年9月8日」，
+    # 周刊「2026年 · 第 36 周 · 工具」，板块名可空
+    def issue_label(kind, key, section: nil)
+      if kind == "daily"
+        date_label(date_of(key), year: true)
+      else
+        [ "#{key[0, 4]}年", "第 #{week_number(key)} 周", section.presence ].compact.join(" · ")
+      end
+    end
+
     # 归档一页一年（PRD 6.2）：这一年全部的 ISO 周键。12月28日 总落在这一年的最后一个 ISO 周里，
     # 所以 2026 有 53 周而 2025 只有 52 周——2025-W53 不存在，week_range 会抛错，控制器据此 404。
     def weeks_in(year)
```

`app/models/search/record.rb`（`where_label` 改用它。日刊那一支不碰 `item`：有测试拿没有条目的日刊记录调 `where_label`）：

```diff
--- a/app/models/search/record.rb
+++ b/app/models/search/record.rb
@@ -77,13 +77,7 @@
   def daily? = publication == "daily"
 
   # 所在期的标签保留年份：结果可能跨年，日刊与周次脱离归档仍要能辨认。板块名用 items 原文。
-  def where_label
-    if daily?
-      PeriodKey.date_label(PeriodKey.date_of(period_key), year: true)
-    else
-      [ "#{period_key[0, 4]}年", "第 #{PeriodKey.week_number(period_key)} 周", item.section.presence ].compact.join(" · ")
-    end
-  end
+  def where_label = PeriodKey.issue_label(publication, period_key, section: (item.section unless daily?))
 
   def published_label = PeriodKey.date_label(published_on, year: true)
 end
```

`app/models/search/highlighter.rb`：

```diff
--- a/app/models/search/highlighter.rb
+++ b/app/models/search/highlighter.rb
@@ -9,6 +9,9 @@
   LATIN = /[\p{L}\p{N}]/
   CJK_CHAR = "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}]"
 
+  # 不带命中的片段（收藏页的摘要，R-10.6）：同一套 160 字与不切词的规则，取开头
+  def self.excerpt(text) = new([]).snippet(text)&.map { |run| run[:text] }&.join
+
   def initialize(terms)
     @patterns = terms.map { |term| pattern(term) }
   end
```

- [ ] **Step 4: 跑测试，确认通过**

```bash
bin/rails test test/models/period_key_test.rb test/models/search/highlighter_test.rb test/models/search/record_test.rb test/controllers/searches_controller_test.rb
bin/rubocop app/models/period_key.rb app/models/search/record.rb app/models/search/highlighter.rb test/models/period_key_test.rb test/models/search/highlighter_test.rb
```

预期：`0 failures, 0 errors`；rubocop `no offenses detected`。

- [ ] **Step 5: 提交**

```bash
git add app/models/period_key.rb app/models/search/record.rb app/models/search/highlighter.rb test/models/period_key_test.rb test/models/search/highlighter_test.rb
git -c commit.gpgsign=false commit -m "所在期标签与不带命中的摘要片段抽成共用方法（收藏页要用）" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: 收藏表与模型

**Files:**
- Create: `db/migrate/20260930090000_create_favorites.rb`、`app/models/favorite.rb`、`app/models/favorite/undoing.rb`
- Modify: `app/models/user.rb`、`config/initializers/filter_parameter_logging.rb`、`db/schema.rb`（迁移生成）
- Test: `test/models/favorite_test.rb`（新建）、`test/models/user_test.rb`

**Interfaces:**
- Consumes: `PeriodKey.issue_label`（Task 1）。
- Produces:
  - `Favorite.keep(user, item) → Favorite`：收藏一条条目；同一链接已收藏就返回原来那条。
  - `Favorite.restore(user, token) → Favorite | nil`：凭凭据把取消的那条原样插回（id 与 `created_at` 不变）；凭据无效、过期、不是这个人的返回 `nil`。
  - `favorite.undo_token → String`：恢复凭据，一天有效。
  - scope `Favorite.listed`（排除链接被下架的）、`Favorite.newest_first`（`created_at DESC, id DESC`）。
  - `Favorite.live_items(favorites) → Hash`，键是 `[kind, period_key, source_id, url_hash]`，值是现存的可见 `Item`；`favorite.live_key` 是同一个键。
  - `favorite.where_label → String`；`Favorite::PER_PAGE = 20`。
  - `user.favorites`（`dependent: :delete_all`）。
  - 列：`user_id`、`url_hash`、`url`、`title`、`title_zh`、`summary`、`summary_zh`、`source_id`、`publication`、`period_key`、`section`、`anchor`、`created_at`。
  - 请求参数 `undo` 在日志里被过滤成 `[FILTERED]`。

- [ ] **Step 1: 写失败的测试**

`test/models/favorite_test.rb`（新建）：

```ruby
require "test_helper"

# 收藏（PRD 5.10）：一人一链接一条，带快照；重抓换掉条目行不影响它（AC-10.3）；取消后凭凭据原样恢复（R-10.7）
class FavoriteTest < ActiveSupport::TestCase
  setup do
    @user = users(:drew)
    @item = items(:hn_one)
  end

  def weekly_item
    index_item("Zed", issue: issues(:weekly_w36), source: sources(:ruanyf), section: "工具", meta: { "issue_no" => 366, "anchor" => "工具" })
  end

  test "keep 把条目抄成快照" do
    @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器", summary: "A fast viewer.")

    favorite = Favorite.keep(@user, @item)

    assert_equal @user, favorite.user
    assert_equal @item.url_hash, favorite.url_hash
    assert_equal "https://example.com/termlog", favorite.url
    assert_equal "Show HN: A terminal log viewer written in Rust", favorite.title
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", favorite.title_zh
    assert_equal "A fast viewer.", favorite.summary
    assert_equal sources(:hn), favorite.source
    assert_equal "daily", favorite.publication
    assert_equal "2026-09-08", favorite.period_key
    assert_nil favorite.anchor
    assert_equal "2026年9月8日", favorite.where_label
  end

  test "周刊条目的快照带板块名与板块锚点" do
    favorite = Favorite.keep(@user, weekly_item)

    assert_equal "weekly", favorite.publication
    assert_equal "2026-W36", favorite.period_key
    assert_equal "工具", favorite.section
    assert_equal "issue-366-工具", favorite.anchor
    assert_equal "2026年 · 第 36 周 · 工具", favorite.where_label
  end

  # R-10.2 收藏的是链接：同一链接再收藏（同一条，或它在另一期再出现）返回原来那条
  test "同一链接只有一条，所在期是第一次收藏的那一期" do
    first = Favorite.keep(@user, @item)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", generation_started_at: Time.current, published_at: Time.current)
    again = later.items.create!(source: sources(:hn), title: "Same link again", url: @item.url, url_hash: @item.url_hash, fetched_at: Time.current, rank: 1)

    assert_equal first, Favorite.keep(@user, @item)
    assert_equal first, Favorite.keep(@user, again)
    assert_equal 1, @user.favorites.count
    assert_equal "2026-09-08", first.reload.period_key
  end

  test "每人一份" do
    Favorite.keep(@user, @item)
    Favorite.keep(users(:guest), @item)

    assert_equal 1, @user.favorites.count
    assert_equal 1, users(:guest).favorites.count
  end

  # AC-10.3 管理员重抓把这一栏的条目行整个换掉，新内容不再含这条链接
  test "重抓换掉条目行，收藏还在" do
    favorite = Favorite.keep(@user, @item)

    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Another", url: "https://h.example/other", rank: 1) ])

    assert_not Item.exists?(@item.id)
    assert_equal "Show HN: A terminal log viewer written in Rust", favorite.reload.title
    assert_equal [ favorite ], @user.favorites.listed.to_a
    assert_empty Favorite.live_items([ favorite ])
  end

  # 重抓后这条链接还在榜上：条目 id 换了，仍然按（刊物、周期键、来源、链接）对得上
  test "live_items 对上重抓之后的新条目行" do
    favorite = Favorite.keep(@user, @item)

    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Show HN: renamed", url: @item.url, rank: 1) ])

    live = Favorite.live_items([ favorite ])[favorite.live_key]
    assert_not_equal @item.id, live.id
    assert_equal "Show HN: renamed", live.title
  end

  # R-10.9、AC-10.13
  test "listed 不含链接被下架的收藏，恢复上架后回来" do
    favorite = Favorite.keep(@user, @item)

    @item.update!(hidden: true)
    assert_empty @user.favorites.listed
    assert_equal 1, @user.favorites.count

    @item.update!(hidden: false)
    assert_equal [ favorite ], @user.favorites.listed.to_a
  end

  test "newest_first 按收藏时间倒序" do
    older = travel_to(2.days.ago) { Favorite.keep(@user, @item) }
    newer = Favorite.keep(@user, weekly_item)

    assert_equal [ newer, older ], @user.favorites.newest_first.to_a
  end

  # R-10.7 取消是真删；凭凭据把同一条原样插回去，id 与收藏时间不变
  test "取消后凭凭据原样恢复" do
    favorite = travel_to(3.days.ago) { Favorite.keep(@user, @item) }
    token = favorite.undo_token
    favorite.destroy!

    restored = Favorite.restore(@user, token)

    assert_equal favorite.id, restored.id
    assert_equal favorite.created_at, restored.created_at
    assert_equal favorite.attributes, restored.reload.attributes
  end

  test "条目已经被重抓换掉也能恢复" do
    favorite = Favorite.keep(@user, @item)
    token = favorite.undo_token
    favorite.destroy!
    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Another", url: "https://h.example/other", rank: 1) ])

    assert_equal favorite.id, Favorite.restore(@user, token).id
  end

  test "别人的、改过的、过期的凭据都恢复不了" do
    favorite = Favorite.keep(@user, @item)
    token = favorite.undo_token
    favorite.destroy!

    assert_nil Favorite.restore(users(:guest), token)
    assert_nil Favorite.restore(@user, token + "x")
    assert_nil Favorite.restore(@user, "")
    assert_nil Favorite.restore(@user, nil)
    travel_to(2.days.from_now) { assert_nil Favorite.restore(@user, token) }
    assert_equal 0, Favorite.count
  end

  test "这期间同一链接又被收藏过，恢复返回现有那条" do
    old = travel_to(3.days.ago) { Favorite.keep(@user, @item) }
    token = old.undo_token
    old.destroy!
    current = Favorite.keep(@user, @item)

    assert_equal current, Favorite.restore(@user, token)
    assert_equal 1, @user.favorites.count
  end
end
```

`test/models/user_test.rb`：

```diff
--- a/test/models/user_test.rb
+++ b/test/models/user_test.rb
@@ -1,6 +1,16 @@
 require "test_helper"
 
 class UserTest < ActiveSupport::TestCase
+  # R-10.11：注销（F-22）落地时删用户即可，收藏跟着走；数据库外键也是级联的
+  test "用户删除时收藏一并删除" do
+    Favorite.keep(users(:guest), items(:hn_one))
+    Favorite.keep(users(:drew), items(:hn_one))
+
+    users(:guest).destroy!
+
+    assert_equal [ users(:drew).id ], Favorite.pluck(:user_id)
+  end
+
   test "fixture 的角色" do
     assert users(:drew).admin?
     assert_not users(:guest).admin?
```

- [ ] **Step 2: 跑测试，确认失败**

```bash
bin/rails test test/models/favorite_test.rb test/models/user_test.rb
```

预期：全是 `NameError: uninitialized constant Favorite`。

- [ ] **Step 3: 迁移**

`db/migrate/20260930090000_create_favorites.rb`（新建）：

```ruby
# 收藏（PRD 5.10，设计 docs/superpowers/specs/2026-09-30-favorites-design.md §3）：一人一链接一条，带收藏时的快照。
# 不引用条目行：管理员重抓会整栏换掉条目的 id（Issue::Sections#replace_section!），收藏按 url_hash 认（D27）。
# 只有 created_at：一行写完不再改
class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites, id: { type: :string, limit: 25 } do |t|
      t.string :user_id, limit: 25, null: false
      t.string :url_hash, limit: 64, null: false
      t.string :url, limit: 2048, null: false
      t.string :title, limit: 300, null: false
      t.string :title_zh, limit: 300
      t.string :summary, limit: 500
      t.string :summary_zh, limit: 500
      t.string :source_id, limit: 25, null: false
      t.string :publication, limit: 10, null: false
      t.string :period_key, limit: 10, null: false
      t.string :section, limit: 100
      t.string :anchor, limit: 120
      t.datetime :created_at, null: false

      t.index [ :user_id, :url_hash ], unique: true
      t.index [ :user_id, :created_at ]
      t.foreign_key :users, on_delete: :cascade
      t.foreign_key :sources
      t.check_constraint "publication IN ('daily', 'weekly')", name: "favorites_publication"
      t.check_constraint "length(url_hash) = 64", name: "favorites_url_hash_len"
      t.check_constraint "length(url) <= 2048", name: "favorites_url_len"
      t.check_constraint "length(title) <= 300", name: "favorites_title_len"
      t.check_constraint "length(title_zh) <= 300", name: "favorites_title_zh_len"
      t.check_constraint "length(summary) <= 500", name: "favorites_summary_len"
      t.check_constraint "length(summary_zh) <= 500", name: "favorites_summary_zh_len"
      t.check_constraint "length(section) <= 100", name: "favorites_section_len"
      t.check_constraint "length(anchor) <= 120", name: "favorites_anchor_len"
    end
  end
end
```

```bash
bin/rails db:migrate:primary
git status --short db/
```

预期：`git status` 里只有 `db/schema.rb` 改了、迁移文件是新的；`db/queue_schema.rb` 没动（动了就 `git checkout -- db/queue_schema.rb`）。`db/schema.rb` 的改动应当只有这些（CHECK 约束的写法以本机 PostgreSQL 实际导出的为准）：

```diff
--- a/db/schema.rb
+++ b/db/schema.rb
@@ -10,7 +10,7 @@
 #
 # It's strongly recommended that you check this file into your version control system.
 
-ActiveRecord::Schema[8.1].define(version: 2026_09_28_090000) do
+ActiveRecord::Schema[8.1].define(version: 2026_09_30_090000) do
   # These are extensions that must be enabled in order to support this database
   enable_extension "pg_catalog.plpgsql"
   enable_extension "pg_trgm"
@@ -90,6 +90,33 @@
     t.check_constraint "trigger::text = ANY (ARRAY['scheduled'::character varying::text, 'manual'::character varying::text])", name: "backup_runs_trigger"
   end
 
+  create_table "favorites", id: { type: :string, limit: 25 }, force: :cascade do |t|
+    t.string "anchor", limit: 120
+    t.datetime "created_at", null: false
+    t.string "period_key", limit: 10, null: false
+    t.string "publication", limit: 10, null: false
+    t.string "section", limit: 100
+    t.string "source_id", limit: 25, null: false
+    t.string "summary", limit: 500
+    t.string "summary_zh", limit: 500
+    t.string "title", limit: 300, null: false
+    t.string "title_zh", limit: 300
+    t.string "url", limit: 2048, null: false
+    t.string "url_hash", limit: 64, null: false
+    t.string "user_id", limit: 25, null: false
+    t.index ["user_id", "created_at"], name: "index_favorites_on_user_id_and_created_at"
+    t.index ["user_id", "url_hash"], name: "index_favorites_on_user_id_and_url_hash", unique: true
+    t.check_constraint "length(anchor::text) <= 120", name: "favorites_anchor_len"
+    t.check_constraint "length(section::text) <= 100", name: "favorites_section_len"
+    t.check_constraint "length(summary::text) <= 500", name: "favorites_summary_len"
+    t.check_constraint "length(summary_zh::text) <= 500", name: "favorites_summary_zh_len"
+    t.check_constraint "length(title::text) <= 300", name: "favorites_title_len"
+    t.check_constraint "length(title_zh::text) <= 300", name: "favorites_title_zh_len"
+    t.check_constraint "length(url::text) <= 2048", name: "favorites_url_len"
+    t.check_constraint "length(url_hash::text) = 64", name: "favorites_url_hash_len"
+    t.check_constraint "publication::text = ANY (ARRAY['daily'::character varying, 'weekly'::character varying]::text[])", name: "favorites_publication"
+  end
+
   create_table "fetch_runs", id: { type: :string, limit: 25 }, force: :cascade do |t|
     t.integer "attempt", default: 1, null: false
     t.datetime "created_at", null: false
@@ -311,6 +338,8 @@
   add_foreign_key "alert_events", "sources", on_delete: :nullify
   add_foreign_key "audit_logs", "users", on_delete: :nullify
   add_foreign_key "auth_identities", "users", on_delete: :cascade
+  add_foreign_key "favorites", "sources"
+  add_foreign_key "favorites", "users", on_delete: :cascade
   add_foreign_key "fetch_runs", "issues"
   add_foreign_key "fetch_runs", "sources"
   add_foreign_key "items", "issues"
```

- [ ] **Step 4: 模型**

`app/models/favorite.rb`（新建）：

```ruby
# 收藏（PRD 5.10）：读者留下的一条链接。按 url_hash 认，一人一链接一条（D27）；收藏时把条目抄成快照，
# 不引用条目行——管理员重抓会整栏换掉条目的 id（Issue::Sections#replace_section!），引用了就会丢。
# 只有本人可见（R-10.8）：读写都从 user.favorites 进来。
class Favorite < ApplicationRecord
  include Favorite::Undoing

  PER_PAGE = 20
  ANCHOR_LIMIT = 120

  belongs_to :user
  belongs_to :source

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  # R-10.9 链接有条目被下架（F-29）就不列；收藏记录留着，恢复上架后重新出现
  scope :listed, -> { where.not(url_hash: Item.where(hidden: true).select(:url_hash)) }

  class << self
    # 收藏一条条目。同一链接已经收藏过就返回原来那条：重复提交不报错（R-10.5），收藏时间与所在期也不变
    def keep(user, item)
      user.favorites.create_with(snapshot_of(item)).find_or_create_by!(url_hash: item.url_hash)
    end

    # 这些收藏对应的条目现在还在不在，按（刊物、周期键、来源、链接）对上号。
    # 条目 id 不存：重抓会换掉它，每次现查——译文可能是收藏之后才生成的，日刊的所在期要落到条目锚点
    def live_items(favorites)
      Item.visible.where(url_hash: favorites.map(&:url_hash)).includes(:issue)
        .index_by { |item| [ item.issue.kind, item.issue.period_key, item.source_id, item.url_hash ] }
    end

    private
      def snapshot_of(item)
        {
          url: item.url, title: item.title, title_zh: item.title_zh, summary: item.summary, summary_zh: item.summary_zh,
          source_id: item.source_id, publication: item.issue.kind, period_key: item.issue.period_key, section: item.section,
          # 周刊的落点跟搜索结果的所在期是同一个值（Item#anchor）；日刊落到条目本身，渲染时现查
          anchor: (item.anchor.slice(0, ANCHOR_LIMIT) if item.issue.kind == "weekly")
        }
      end
  end

  def live_key = [ publication, period_key, source_id, url_hash ]

  # 所在期的标签（R-10.6，同搜索结果）：「2026年9月8日」/「2026年 · 第 36 周 · 工具」
  def where_label = PeriodKey.issue_label(publication, period_key, section: section)
end
```

`app/models/favorite/undoing.rb`（新建）：

```ruby
# 取消后的恢复（R-10.7）。取消是真删：服务端不留「已取消」的行（7.8 收藏到用户取消为止）。
# 删之前交给前端一张签过名的凭据，里面是这条收藏的全部字段；读者点「恢复」时凭它把同一条原样插回去，
# id 与收藏时间都不变。凭据一天后失效，只认签发给的那个人。
module Favorite::Undoing
  extend ActiveSupport::Concern

  UNDO_TTL = 1.day
  UNDO_COLUMNS = %w[ id url_hash url title title_zh summary summary_zh source_id publication period_key section anchor ].freeze

  class_methods do
    # 凭据无效、过期、不是这个人的，返回 nil。同一链接这期间又被收藏过，返回现有那条
    def restore(user, token)
      payload = undo_verifier.verified(token.to_s, purpose: :undo)

      if payload && payload["user_id"] == user.id
        attributes = payload.slice(*UNDO_COLUMNS).merge("created_at" => Time.iso8601(payload["created_at"]))
        user.favorites.create_with(attributes).find_or_create_by!(url_hash: payload["url_hash"])
      end
    end

    def undo_verifier = Rails.application.message_verifier("favorites/undo")
  end

  def undo_token
    payload = attributes.slice(*UNDO_COLUMNS).merge("user_id" => user_id, "created_at" => created_at.utc.iso8601(6))
    self.class.undo_verifier.generate(payload, expires_in: UNDO_TTL, purpose: :undo)
  end
end
```

`app/models/user.rb`：

```diff
--- a/app/models/user.rb
+++ b/app/models/user.rb
@@ -5,6 +5,8 @@
 
   has_many :auth_identities, dependent: :destroy
   has_many :sessions, dependent: :destroy
+  # 收藏是个人数据（N-4）：人没了收藏一起没（R-10.11）；一条语句删完，不逐条回调
+  has_many :favorites, dependent: :delete_all
 
   validates :display_name, presence: true, length: { maximum: 100 }
   validates :email, length: { maximum: 254 }, allow_nil: true
```

`config/initializers/filter_parameter_logging.rb`：

```diff
--- a/config/initializers/filter_parameter_logging.rb
+++ b/config/initializers/filter_parameter_logging.rb
@@ -4,5 +4,7 @@
 # Use this to limit dissemination of sensitive information.
 # See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
 Rails.application.config.filter_parameters += [
-  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
+  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
+  # 收藏的恢复凭据里是整条收藏的内容（标题、链接），不进请求日志（R-10.8）
+  :undo
 ]
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
bin/rails test test/models/favorite_test.rb test/models/user_test.rb
bin/rubocop app/models/favorite.rb app/models/favorite/undoing.rb app/models/user.rb config/initializers/filter_parameter_logging.rb test/models/favorite_test.rb test/models/user_test.rb
```

预期：`0 failures, 0 errors`（`favorite_test.rb` 是 12 条）；rubocop `no offenses detected`。

- [ ] **Step 6: 提交**

```bash
git add db/migrate/20260930090000_create_favorites.rb db/schema.rb app/models/favorite.rb app/models/favorite/undoing.rb app/models/user.rb config/initializers/filter_parameter_logging.rb test/models/favorite_test.rb test/models/user_test.rb
git -c commit.gpgsign=false commit -m "收藏表与模型：按链接认、带快照，取消后凭签名凭据恢复（PRD 5.10）" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: 收藏的控制器与路由

**Files:**
- Create: `app/controllers/favorites_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/favorites_controller_test.rb`（新建）

**Interfaces:**
- Consumes: Task 2 的 `Favorite.keep` / `restore` / `undo_token` / `listed` / `newest_first` / `live_items` / `live_key` / `where_label` / `PER_PAGE`；Task 1 的 `Search::Highlighter.excerpt`；`ApplicationController#footer_props`（已有）。
- Produces:
  - 路由助手 `favorites_path`（`GET` 收藏页、`POST` 收藏）、`favorite_path(url_hash)`（`DELETE` 取消）。`url_hash` 必须是 64 位十六进制。
  - `GET /favorites?page=n` → Inertia 页面 `Favorites/Index`，props：`entries: [{ url_hash, publication, source_name, where: { label, href }, url, title, title_zh, snippet, summary_zh }]`、`favorites: string[]`、`page`、`pages`、`daily_time`、`latest_weekly_key`、`latest_daily_key`。页码超过最后一页 302 到最后一页。
  - `POST /favorites`，JSON 体 `{ item_id }` 或 `{ undo }` → `201 { url_hash }`；条目不存在、已下架、凭据无效 → 404。
  - `DELETE /favorites/:url_hash` → `200 { undo }`；这个人没有这条收藏 → 204。
  - 两个动作合计每用户每分钟 60 次，超限 429；未登录 401（收藏页本身未登录是 302 到 `/login?next=/favorites`）。

- [ ] **Step 1: 写失败的测试**

`test/controllers/favorites_controller_test.rb`（新建）：

```ruby
require "test_helper"

# 收藏页的 props 契约与书签的两个动作（PRD 5.10，AC-10.x）
class FavoritesControllerTest < ActionDispatch::IntegrationTest
  TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  setup do
    sign_in_as(users(:drew))
    @item = items(:hn_one)
  end

  def replace_hn_column
    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Another", url: "https://h.example/other", rank: 1) ])
  end

  # ── 收藏页 ──

  test "没有收藏：空列表，带去最新日刊要的键（AC-10.10）" do
    get favorites_path

    assert_response :success
    assert_equal "Favorites/Index", page_component
    assert_equal [], page_props["entries"]
    assert_equal [], page_props["favorites"]
    assert_equal 1, page_props["page"]
    assert_equal 0, page_props["pages"]
    assert_equal "2026-09-08", page_props["latest_daily_key"]
    assert_equal "06:00", page_props["daily_time"]
  end

  test "日刊收藏的一行：刊物、来源、所在期落到那一栏的那一条、原文" do
    Favorite.keep(users(:drew), @item)

    get favorites_path

    entry = page_props["entries"].sole
    assert_equal @item.url_hash, entry["url_hash"]
    assert_equal "daily", entry["publication"]
    assert_equal "Hacker News", entry["source_name"]
    assert_equal "2026年9月8日", entry.dig("where", "label")
    assert_equal daily_issue_path("2026-09-08", source: sources(:hn).id, anchor: "item-#{@item.id}"), entry.dig("where", "href")
    assert_equal "https://example.com/termlog", entry["url"]
    assert_equal TITLE, entry["title"]
    assert_nil entry["title_zh"]
    assert_nil entry["snippet"]
    assert_nil entry["summary_zh"]
    assert_equal [ @item.url_hash ], page_props["favorites"]
    assert_equal 1, page_props["pages"]
  end

  test "周刊收藏的所在期落到板块锚点（AC-10.8）" do
    weekly = index_item("Zed", issue: issues(:weekly_w36), source: sources(:ruanyf), section: "工具", summary: "一个用 Rust 写的代码编辑器。",
                        meta: { "issue_no" => 366, "anchor" => "工具" })
    Favorite.keep(users(:drew), weekly)

    get favorites_path

    entry = page_props["entries"].sole
    assert_equal "weekly", entry["publication"]
    assert_equal "阮一峰科技爱好者周刊", entry["source_name"]
    assert_equal "2026年 · 第 36 周 · 工具", entry.dig("where", "label")
    assert_equal weekly_issue_path("2026-W36", anchor: "issue-366-工具"), entry.dig("where", "href")
    assert_equal "一个用 Rust 写的代码编辑器。", entry["snippet"]
  end

  test "摘要片段不超过 160 字" do
    Favorite.keep(users(:drew), index_item("Long one", summary: "word " * 90))

    get favorites_path

    snippet = page_props["entries"].sole["snippet"]
    assert_operator snippet.length, :<=, 160
    assert snippet.end_with?("…")
  end

  test "收藏之后才生成的译文也显示" do
    Favorite.keep(users(:drew), @item)
    @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器")

    get favorites_path

    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", page_props["entries"].sole["title_zh"]
  end

  # AC-10.3 重抓把条目行换掉、新内容不含这条链接：收藏仍在，用收藏时的快照；所在期打开那一栏，不带条目锚点
  test "条目被重抓换掉后，收藏行用快照" do
    @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器")
    Favorite.keep(users(:drew), @item)
    replace_hn_column

    get favorites_path

    entry = page_props["entries"].sole
    assert_equal TITLE, entry["title"]
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", entry["title_zh"]
    assert_equal "Hacker News", entry["source_name"]
    assert_equal "2026年9月8日", entry.dig("where", "label")
    assert_equal daily_issue_path("2026-09-08", source: sources(:hn).id), entry.dig("where", "href")
    assert_equal "https://example.com/termlog", entry["url"]
  end

  test "别人的收藏看不到（AC-10.6）" do
    Favorite.keep(users(:guest), @item)

    get favorites_path

    assert_equal [], page_props["entries"]
    assert_equal [], page_props["favorites"]
  end

  test "被下架的条目不出现，恢复上架后回来（AC-10.13）" do
    Favorite.keep(users(:drew), @item)
    @item.update!(hidden: true)

    get favorites_path
    assert_equal [], page_props["entries"]
    assert_equal 0, page_props["pages"]

    @item.update!(hidden: false)
    get favorites_path
    assert_equal [ TITLE ], page_props["entries"].map { |entry| entry["title"] }
  end

  test "按收藏时间倒序，每页 20 条；页码越界跳到最后一页" do
    21.times { |n| travel_to(Time.utc(2026, 9, 9, 0, n)) { Favorite.keep(users(:drew), index_item("Item #{n}")) } }

    get favorites_path
    assert_equal 20, page_props["entries"].size
    assert_equal "Item 20", page_props["entries"].first["title"]
    assert_equal 1, page_props["page"]
    assert_equal 2, page_props["pages"]

    get favorites_path(page: 2)
    assert_equal [ "Item 0" ], page_props["entries"].map { |entry| entry["title"] }
    assert_equal 2, page_props["page"]

    get favorites_path(page: 9)
    assert_redirected_to favorites_path(page: 2)
  end

  test "不是数字的页码当第 1 页" do
    Favorite.keep(users(:drew), @item)

    get favorites_path(page: "abc")
    assert_equal 1, page_props["page"]

    get favorites_path, params: { page: [ "2" ] }
    assert_equal 1, page_props["page"]
  end

  # ── 书签的两个动作 ──

  test "POST 收藏一条条目（AC-10.1）" do
    post favorites_path, params: { item_id: @item.id }, as: :json

    assert_response :created
    assert_equal({ "url_hash" => @item.url_hash }, response.parsed_body)
    favorite = users(:drew).favorites.sole
    assert_equal @item.url_hash, favorite.url_hash
    assert_equal TITLE, favorite.title
  end

  test "重复收藏不报错也不多一条（R-10.5）" do
    2.times { post favorites_path, params: { item_id: @item.id }, as: :json }

    assert_response :created
    assert_equal 1, Favorite.count
  end

  test "不存在或已下架的条目收藏不了" do
    post favorites_path, params: { item_id: "nope" }, as: :json
    assert_response :not_found

    @item.update!(hidden: true)
    post favorites_path, params: { item_id: @item.id }, as: :json
    assert_response :not_found

    post favorites_path, as: :json
    assert_response :not_found
    assert_equal 0, Favorite.count
  end

  # AC-10.4 取消是真删；凭回来的凭据恢复，还是原来那一条
  test "DELETE 取消并给回恢复凭据，POST 凭据原样恢复" do
    favorite = travel_to(3.days.ago) { Favorite.keep(users(:drew), @item) }

    delete favorite_path(@item.url_hash), as: :json

    assert_response :success
    undo = response.parsed_body["undo"]
    assert undo.present?
    assert_equal 0, Favorite.count

    post favorites_path, params: { undo: undo }, as: :json

    assert_response :created
    assert_equal({ "url_hash" => @item.url_hash }, response.parsed_body)
    restored = Favorite.sole
    assert_equal favorite.id, restored.id
    assert_equal favorite.created_at, restored.created_at
  end

  test "条目被重抓换掉之后照样能恢复" do
    Favorite.keep(users(:drew), @item)
    delete favorite_path(@item.url_hash), as: :json
    undo = response.parsed_body["undo"]
    replace_hn_column

    post favorites_path, params: { undo: undo }, as: :json

    assert_response :created
    assert_equal TITLE, Favorite.sole.title
  end

  test "无效的凭据恢复不了" do
    post favorites_path, params: { undo: "nope" }, as: :json

    assert_response :not_found
    assert_equal 0, Favorite.count
  end

  test "取消一条不存在的收藏不报错；别人的收藏删不掉" do
    Favorite.keep(users(:guest), @item)

    delete favorite_path(@item.url_hash), as: :json

    assert_response :no_content
    assert_equal 1, users(:guest).favorites.count
  end

  test "恢复凭据不进请求日志" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("undo" => "secret")["undo"]
  end

  test "一分钟 60 次以上回 429（AC-10.11）" do
    60.times { post favorites_path, params: { item_id: "nope" }, as: :json }

    post favorites_path, params: { item_id: @item.id }, as: :json
    assert_response :too_many_requests
    assert_equal 0, Favorite.count

    delete favorite_path(@item.url_hash), as: :json
    assert_response :too_many_requests
  end

  test "收藏页本身不限流" do
    61.times { get favorites_path }

    assert_response :success
  end

  test "未登录：收藏页跳登录并带 next（AC-10.7），书签的动作回 401" do
    delete session_path

    get favorites_path
    assert_redirected_to login_path(next: "/favorites")

    post favorites_path, params: { item_id: @item.id }, as: :json
    assert_response :unauthorized

    delete favorite_path(@item.url_hash), as: :json
    assert_response :unauthorized
    assert_equal 0, Favorite.count
  end
end
```

- [ ] **Step 2: 跑测试，确认失败**

```bash
bin/rails test test/controllers/favorites_controller_test.rb
```

预期：除「恢复凭据不进请求日志」外全部 error，`NameError: undefined local variable or method 'favorites_path'`。

- [ ] **Step 3: 路由**

`config/routes.rb`：

```diff
--- a/config/routes.rb
+++ b/config/routes.rb
@@ -19,6 +19,10 @@
     resources :clicks, only: :create
   end
 
+  # 收藏（PRD 5.10）：GET /favorites 是收藏页；POST /favorites 与 DELETE /favorites/:url_hash 是条目上那颗书签的
+  # 两个动作。资源的键是链接的 url_hash（一人一链接一条，D27），不是行 id
+  resources :favorites, only: [ :index, :create, :destroy ], param: :url_hash, constraints: { url_hash: /\h{64}/ }
+
   # P2-② 管理后台（PRD 5.3、5.6）：CRUD 资源（STYLE.md），全部继承 Admin::BaseController。
   # 启停是 enablement 资源（POST 启用 / DELETE 停用）；某期某源重抓、补生成、立即生成今日日刊各是一个资源
   namespace :admin do
```

- [ ] **Step 4: 控制器**

`app/controllers/favorites_controller.rb`（新建）：

```ruby
# 收藏（PRD 5.10）。index 是收藏页；create / destroy 是条目上那颗书签的两个动作：前端用 fetch 调、这里回 JSON
# （跟 search/clicks、测试抓取一样不是页面）。资源的键是链接的 url_hash（一人一链接一条，D27），不是行 id。
# 书签的动作按用户每分钟 60 次（R-10.10），收藏页本身不限。
class FavoritesController < ApplicationController
  rate_limit to: 60, within: 1.minute, by: -> { Current.user.id }, with: -> { head :too_many_requests }, only: [ :create, :destroy ]

  # R-10.6 按收藏时间倒序，每页 20 条；页码超过最后一页（取消后页数变少、手改地址）跳到最后一页
  def index
    scope = Current.user.favorites.listed
    pages = (scope.count.to_f / Favorite::PER_PAGE).ceil

    if pages.positive? && page_number > pages
      redirect_to favorites_path(page: pages)
    else
      favorites = scope.newest_first.includes(:source).offset((page_number - 1) * Favorite::PER_PAGE).limit(Favorite::PER_PAGE).to_a
      live = Favorite.live_items(favorites)

      render inertia: "Favorites/Index", props: {
        entries: favorites.map { |favorite| entry_props(favorite, live[favorite.live_key]) },
        favorites: favorites.map(&:url_hash),
        page: page_number,
        pages: pages
      }.merge(footer_props)
    end
  end

  # 收藏一条条目；或者凭取消时拿到的凭据，把刚取消的那条原样恢复（R-10.7）
  def create
    favorite = if params[:undo].present?
      Favorite.restore(Current.user, params[:undo])
    elsif item = Item.visible.find_by(id: params[:item_id].to_s)
      Favorite.keep(Current.user, item)
    end

    if favorite
      render json: { url_hash: favorite.url_hash }, status: :created
    else
      head :not_found
    end
  end

  # 取消是真删，回一张恢复凭据。已经不在了（重复提交、别人的链接）也不报错（R-10.5）
  def destroy
    if favorite = Current.user.favorites.find_by(url_hash: params[:url_hash])
      favorite.destroy!
      render json: { undo: favorite.undo_token }
    else
      head :no_content
    end
  end

  private
    # create / destroy 是 fetch 发来的：被 302 带去登录页的话 fetch 会跟着跳，拿回一页 HTML 当成功。
    # 会话过期时给 401，前端据此整页去登录（PRD 5.10 边界）；收藏页本身（GET）照常跳 /login?next=
    def request_authentication
      if request.get? || request.head?
        super
      else
        head :unauthorized
      end
    end

    # ?page[]=… 这类不是数字的值都当第 1 页
    def page_number
      @page_number ||= [ Integer(params[:page].to_s, 10, exception: false) || 1, 1 ].max
    end

    # 行的字段照搜索结果行（R-10.6）。条目还在就用它现在的译文：译文可能是收藏之后才生成的（R-9.10）
    def entry_props(favorite, item)
      {
        url_hash: favorite.url_hash,
        publication: favorite.publication,
        source_name: favorite.source.name,
        where: { label: favorite.where_label, href: where_href(favorite, item) },
        url: favorite.url,
        title: favorite.title,
        title_zh: item&.title_zh.presence || favorite.title_zh,
        snippet: Search::Highlighter.excerpt(favorite.summary),
        summary_zh: item&.summary_zh.presence || favorite.summary_zh
      }
    end

    # 所在期（同搜索结果）：日刊带 ?source= 切到那一栏，条目还在就落到它；周刊落到板块锚点
    def where_href(favorite, item)
      if favorite.publication == "daily"
        daily_issue_path(favorite.period_key, source: favorite.source_id, anchor: ("item-#{item.id}" if item))
      else
        weekly_issue_path(favorite.period_key, anchor: favorite.anchor)
      end
    end
end
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
bin/rails test test/controllers/favorites_controller_test.rb
bin/rubocop app/controllers/favorites_controller.rb config/routes.rb test/controllers/favorites_controller_test.rb
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

预期：`21 runs, … 0 failures, 0 errors`；rubocop 与 brakeman 都没有告警。

- [ ] **Step 6: 提交**

```bash
git add app/controllers/favorites_controller.rb config/routes.rb test/controllers/favorites_controller_test.rb
git -c commit.gpgsign=false commit -m "收藏页的 props 与书签的两个动作：GET / POST / DELETE /favorites" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: 日刊、周刊、搜索页带上收藏状态

**Files:**
- Modify: `app/models/issue/presenting.rb`、`app/controllers/application_controller.rb`、`app/controllers/daily_issues_controller.rb`、`app/controllers/weekly_issues_controller.rb`、`app/controllers/searches_controller.rb`
- Test: `test/controllers/daily_issues_controller_test.rb`、`test/controllers/weekly_issues_controller_test.rb`、`test/controllers/searches_controller_test.rb`、`test/controllers/admin/users_controller_test.rb`

**Interfaces:**
- Consumes: `user.favorites`、`Favorite.keep`（Task 2）。
- Produces:
  - 条目 props（日刊的 `items_by_source[...][]` 与周刊的 `sections[].groups[].items[]`）多一个 `url_hash: string`。
  - 搜索结果 props（`results[]`）多一个 `url_hash: string`。
  - `Daily/Show`、`Weekly/Show`、`Search/Show` 三个页面的 props 多一个 `favorites: string[]`：这一页的条目里当前读者收藏过的 `url_hash`。缺期、那一周没有期、没有搜索结果时是 `[]`。
  - `ApplicationController#favorite_hashes(url_hashes) → [String]`（私有；入参可以是数组，也可以是只选了 `url_hash` 的关系）。

- [ ] **Step 1: 写失败的测试**

`test/controllers/daily_issues_controller_test.rb`（加在类的末尾）：

```diff
--- a/test/controllers/daily_issues_controller_test.rb
+++ b/test/controllers/daily_issues_controller_test.rb
@@ -248,5 +248,39 @@
       get daily_issues_path(month: "2027-01")
       assert_response :not_found
     end
+  end
+
+  # PRD 5.10：条目带 url_hash，页面带这一期里当前读者收藏过的链接（书签的开合由前端对着它画）
+  test "条目带 url_hash，favorites 列出这一期里收藏过的链接" do
+    get daily_issue_path("2026-09-08")
+    assert_equal items(:hn_one).url_hash, page_props.dig("items_by_source", sources(:hn).id).sole["url_hash"]
+    assert_equal [], page_props["favorites"]
+
+    Favorite.keep(users(:drew), items(:hn_one))
+    get daily_issue_path("2026-09-08")
+    assert_equal [ items(:hn_one).url_hash ], page_props["favorites"]
+  end
+
+  # AC-10.2 收藏按链接认：同一链接在另一期再出现也显示已收藏；别人的收藏不算（AC-10.6）
+  test "同一链接在另一期也算已收藏，别人的收藏不算" do
+    Favorite.keep(users(:drew), items(:hn_one))
+    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", generation_started_at: Time.current,
+                          published_at: Time.current, source_states: { sources(:hn).id => "ok" })
+    later.items.create!(source: sources(:hn), title: "Same link again", url: items(:hn_one).url, url_hash: items(:hn_one).url_hash,
+                        fetched_at: Time.current, rank: 1)
+
+    get daily_issue_path("2026-09-09")
+    assert_equal [ items(:hn_one).url_hash ], page_props["favorites"]
+
+    delete session_path
+    sign_in_as(users(:guest))
+    get daily_issue_path("2026-09-09")
+    assert_equal [], page_props["favorites"]
   end
+
+  test "缺期的 favorites 是空列表" do
+    get daily_issue_path("2026-09-03")
+
+    assert_equal [], page_props["favorites"]
+  end
 end
```

`test/controllers/weekly_issues_controller_test.rb`（这个文件里有两个测试类，加在第一个类 `WeeklyIssuesControllerTest` 的末尾，那里才有 `ruanyf_item`）：

```diff
--- a/test/controllers/weekly_issues_controller_test.rb
+++ b/test/controllers/weekly_issues_controller_test.rb
@@ -106,6 +106,25 @@
     assert_equal "2026-W35", page_props.dig("issue", "prev_key")
     assert_nil page_props.dig("issue", "next_key")
   end
+
+  # PRD 5.10：周刊条目同样带 url_hash，页面带这一期里收藏过的链接
+  test "条目带 url_hash，favorites 列出这一期里收藏过的链接" do
+    item = ruanyf_item("一个终端下的日志工具", section: "工具")
+
+    get weekly_issue_path("2026-W36")
+    assert_equal item.url_hash, page_props["sections"].sole["groups"].sole["items"].sole["url_hash"]
+    assert_equal [], page_props["favorites"]
+
+    Favorite.keep(users(:drew), item)
+    get weekly_issue_path("2026-W36")
+    assert_equal [ item.url_hash ], page_props["favorites"]
+  end
+
+  test "那一周没有期时 favorites 是空列表" do
+    get weekly_issue_path("2026-W30")
+
+    assert_equal [], page_props["favorites"]
+  end
 end
 
 # 周刊归档：按年一页，每周一行（PRD 6.2、R-2.7）。上海 2026-09-10 12:00 时本周是 2026-W37。
```

`test/controllers/searches_controller_test.rb`（加在类的末尾）：

```diff
--- a/test/controllers/searches_controller_test.rb
+++ b/test/controllers/searches_controller_test.rb
@@ -178,4 +178,18 @@
     assert_equal "unavailable", page_props["state"]
     assert_nil Search::Log.sole.result_count
   end
+
+  # PRD 5.10：结果带 url_hash，页面带这一页结果里收藏过的链接
+  test "结果带 url_hash，favorites 列出这一页里收藏过的链接" do
+    get search_path
+    assert_equal [], page_props["favorites"]
+
+    get search_path(q: "kuber rust")
+    assert_equal @item.url_hash, page_props["results"].sole["url_hash"]
+    assert_equal [], page_props["favorites"]
+
+    Favorite.keep(users(:drew), @item)
+    get search_path(q: "kuber rust")
+    assert_equal [ @item.url_hash ], page_props["favorites"]
+  end
 end
```

`test/controllers/admin/users_controller_test.rb`（这一条现在就该通过：它钉住的是「后台的用户页没有收藏信息」，防以后有人加进去）：

```diff
--- a/test/controllers/admin/users_controller_test.rb
+++ b/test/controllers/admin/users_controller_test.rb
@@ -16,4 +16,15 @@
     get admin_users_path
     assert_response :forbidden
   end
+
+  # R-10.8、AC-10.6：收藏只有本人可见，后台的用户页不带任何收藏信息
+  test "用户列表不带收藏信息" do
+    Favorite.keep(users(:guest), items(:hn_one))
+    sign_in_as(users(:drew))
+
+    get admin_users_path
+
+    assert_equal %w[ display_name email id last_login_label providers_label role ], page_props["users"].first.keys.sort
+    assert_not_includes response.body, items(:hn_one).url
+  end
 end
```

- [ ] **Step 2: 跑测试，确认失败**

```bash
bin/rails test test/controllers/daily_issues_controller_test.rb test/controllers/weekly_issues_controller_test.rb test/controllers/searches_controller_test.rb test/controllers/admin/users_controller_test.rb
```

预期：新加的 7 条里，日刊 3 条、周刊 2 条、搜索 1 条失败（`url_hash` 与 `favorites` 都是 `nil`）；后台用户页那一条通过。

- [ ] **Step 3: 实现**

`app/models/issue/presenting.rb`：

```diff
--- a/app/models/issue/presenting.rb
+++ b/app/models/issue/presenting.rb
@@ -311,11 +311,13 @@
     end
 
     # 阅读页保留完整的已存摘要（上限 500 字）；周刊详情另带完整 content（D24）；
+    # url_hash 给书签用：收藏按链接认（D27），页面的 favorites 列的就是它；
     # title_zh 是 HN 与 Hackaday 标题的中文译文、summary_zh 是 GitHub Trending 简介的中文译文（D25），
     # 跟推荐理由同一次生成，没生成前是 nil。
     def item_props(item)
       {
         id: item.id,
+        url_hash: item.url_hash,
         title: item.title,
         title_zh: item.title_zh,
         url: item.url,
```

`app/controllers/application_controller.rb`：

```diff
--- a/app/controllers/application_controller.rb
+++ b/app/controllers/application_controller.rb
@@ -31,6 +31,12 @@
       { daily_time: Setting.get("daily_time"), latest_weekly_key: Issue.latest_weekly_key, latest_daily_key: Issue.latest_daily_key }
     end
 
+    # 这一页的条目里，当前读者收藏过哪些链接（R-10.2）：只给 url_hash，书签的开合由前端对着它画。
+    # 按链接认，所以同一链接在另一期、另一个来源再出现也算
+    def favorite_hashes(url_hashes)
+      Current.user.favorites.where(url_hash: url_hashes).pluck(:url_hash)
+    end
+
     # 附录 B 的 404 页，带页脚：地址形状不对、月份或年份越界都落到这里，
     # 读者看到的是站内的一页，不是 public/404.html 那张没有报头页脚的静态页。
     # layout 显式指定的理由同 render_forbidden：Admin::BaseController 把 RecordNotFound 也接到这里，
```

`app/controllers/daily_issues_controller.rb`：

```diff
--- a/app/controllers/daily_issues_controller.rb
+++ b/app/controllers/daily_issues_controller.rb
@@ -24,6 +24,7 @@
         missing: issue.nil?,
         sources: sources,
         items_by_source: issue&.items_by_source || {},
+        favorites: issue ? favorite_hashes(issue.items.visible.select(:url_hash)) : [],
         active_source_id: params[:source].presence_in(sources.pluck(:id)) || sources.dig(0, :id),
         latest_weekly_key: Issue.latest_weekly_key,
         latest_daily_key: Issue.latest_daily_key,
```

`app/controllers/weekly_issues_controller.rb`：

```diff
--- a/app/controllers/weekly_issues_controller.rb
+++ b/app/controllers/weekly_issues_controller.rb
@@ -13,7 +13,10 @@
   # R-2.7 那一周没有期不是 404：期头照常显示周次与日期范围，正文只有「本周无内容」
   def show
     if period_key = valid_period_key
-      render inertia: "Weekly/Show", props: Issue.weekly_props_for(period_key).merge(footer_props)
+      issue = Issue.weekly.find_by(period_key: period_key)
+      favorites = issue ? favorite_hashes(issue.items.visible.select(:url_hash)) : []
+
+      render inertia: "Weekly/Show", props: Issue.weekly_props_for(period_key, issue: issue).merge(favorites: favorites, **footer_props)
     else
       render_not_found
     end
```

`app/controllers/searches_controller.rb`：

```diff
--- a/app/controllers/searches_controller.rb
+++ b/app/controllers/searches_controller.rb
@@ -56,6 +56,7 @@
         date_presets: date_presets,
         state: state,
         results: results_props(query, result),
+        favorites: result ? favorite_hashes(result.entries.map { |entry| entry.record.item.url_hash }) : [],
         total: result&.total || 0,
         page: query.page,
         pages: result&.pages || 0,
@@ -90,6 +91,7 @@
       item = record.item
       {
         item_id: item.id,
+        url_hash: item.url_hash,
         rank: entry.rank,
         publication: record.publication,
         source_name: item.source.name,
```

- [ ] **Step 4: 跑测试，确认通过**

```bash
bin/rails test
bin/rubocop
```

预期：`bin/rails test` 是 `757 runs, … 0 failures, 0 errors`（基线 714 加上前四个任务的 43 条）；rubocop `no offenses detected`。

- [ ] **Step 5: 提交**

```bash
git add app/models/issue/presenting.rb app/controllers/application_controller.rb app/controllers/daily_issues_controller.rb app/controllers/weekly_issues_controller.rb app/controllers/searches_controller.rb test/controllers/daily_issues_controller_test.rb test/controllers/weekly_issues_controller_test.rb test/controllers/searches_controller_test.rb test/controllers/admin/users_controller_test.rb
git -c commit.gpgsign=false commit -m "日刊、周刊、搜索页带上收藏状态：条目的 url_hash 与页面的 favorites" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: 前端基础：类型、地址、图标、收藏状态管理、书签按钮与样式

**Files:**
- Create: `app/frontend/lib/favorites.tsx`、`app/frontend/components/FavoriteButton.tsx`
- Modify: `app/frontend/types/lowpass.ts`、`app/frontend/lib/paths.ts`、`app/frontend/components/Icon.tsx`、`app/frontend/styles/tokens.css`
- Test: `test/frontend/components/FavoriteButton.test.tsx`（新建）、`test/frontend/lib/paths.test.ts`、`test/frontend/support/inertia.tsx`、`test/frontend/support/props.ts`

**Interfaces:**
- Consumes: Task 3 的两个端点与状态码；Task 4 的 props 形状；已有的 `Toasts` / `useToasts`（`components/Toast.tsx`）、`Icon`。
- Produces:
  - 类型：`Item.url_hash: string`、`SearchResult.url_hash: string`、`FavoriteEntry = { url_hash; publication; source_name; where: { label; href }; url; title; title_zh: string | null; snippet: string | null; summary_zh: string | null }`。
  - 地址：`FAVORITES = '/favorites'`、`favoritesHref(page = 1)`（第 1 页不写 `page`）、`favoriteHref(urlHash)`、`loginHref(next)`。
  - `FavoritesProvider`，props `{ favorites: string[] }`；`useFavorites(): Favorites | null`（没有 Provider 时是 `null`），`Favorites = { has(urlHash): boolean; removed(urlHash): boolean; toggle({ urlHash, itemId? }): void; restore(urlHash): void }`；`COPY`（三句提示）。
  - `FavoriteButton`，props `{ urlHash: string; title: string; itemId?: string; className?: string; ref?: React.Ref<HTMLButtonElement> }`。渲染 `<button class="favorite-button …">`，已收藏时带 `data-on`；`aria-label` 是「收藏：{title}」或「取消收藏：{title}」；没有 Provider 时渲染 `null`。
  - 图标名 `'bookmark'`。
  - 样式类：`.favorite-button`、`.item-mark`、`.search-mark`、`.favorite-removed`；`.item-row` 的网格多一列 `mark`。
  - 测试替身：`router.replaceProp`（spy）；样例工厂 `item()` 与 `searchResult()` 带 `url_hash`（`'hash-termlog'`、`'hash-k8s-rust'`），新工厂 `favoriteEntry(overrides)`。

- [ ] **Step 1: 写失败的测试**

`test/frontend/support/inertia.tsx`（替身加一个方法）：

```diff
--- a/test/frontend/support/inertia.tsx
+++ b/test/frontend/support/inertia.tsx
@@ -36,6 +36,8 @@
   post: vi.fn(),
   patch: vi.fn(),
   replace: vi.fn(),
+  // 收藏把最新的列表写回当前页的 props（lib/favorites.tsx）；单测里只看它被叫到没有
+  replaceProp: vi.fn(),
   on: vi.fn((event: RouterEvent, listener: RouterListener) => {
     const listeners = routerListeners.get(event) ?? new Set<RouterListener>()
     listeners.add(listener)
```

`test/frontend/support/props.ts`：

```diff
--- a/test/frontend/support/props.ts
+++ b/test/frontend/support/props.ts
@@ -10,6 +10,7 @@
   BackupStatus,
   CurrentUser,
   DailyIssue,
+  FavoriteEntry,
   InterestArea,
   Item,
   ReasonsStatus,
@@ -40,6 +41,7 @@
 export function item(overrides: Partial<Item> = {}): Item {
   return {
     id: 'itm-hn-1',
+    url_hash: 'hash-termlog',
     title: 'Show HN: A terminal log viewer written in Rust',
     title_zh: null,
     url: 'https://example.com/termlog',
@@ -151,6 +153,7 @@
 export function searchResult(overrides: Partial<SearchResult> = {}): SearchResult {
   return {
     item_id: 'itm-hn-1',
+    url_hash: 'hash-k8s-rust',
     rank: 1,
     publication: 'daily',
     source_name: 'Hacker News',
@@ -171,6 +174,22 @@
   }
 }
 
+// 收藏页的一行（FavoritesController#entry_props）：默认是一条日刊收藏，没有译文与摘要
+export function favoriteEntry(overrides: Partial<FavoriteEntry> = {}): FavoriteEntry {
+  return {
+    url_hash: 'hash-termlog',
+    publication: 'daily',
+    source_name: 'Hacker News',
+    where: { label: '2026年9月8日', href: '/daily/2026-09-08?source=src-hn#item-itm-hn-1' },
+    url: 'https://example.com/termlog',
+    title: 'Show HN: A terminal log viewer written in Rust',
+    title_zh: null,
+    snippet: null,
+    summary_zh: null,
+    ...overrides,
+  }
+}
+
 // ApplicationController 的 inertia_share 每页都带的当前用户
 export function currentUser(overrides: Partial<CurrentUser> = {}): CurrentUser {
   return { display_name: 'Drew Lee', avatar_url: null, email: 'drew@example.com', admin: false, ...overrides }
```

`test/frontend/lib/paths.test.ts`：

```diff
--- a/test/frontend/lib/paths.test.ts
+++ b/test/frontend/lib/paths.test.ts
@@ -10,6 +10,7 @@
   ADMIN_TODAY_ISSUE,
   DAILY_ARCHIVE,
   DAILY_LATEST,
+  FAVORITES,
   LOGIN,
   SEARCH,
   SEARCH_CLICKS,
@@ -27,7 +28,10 @@
   authCallbackHref,
   authHref,
   dailyHref,
+  favoriteHref,
+  favoritesHref,
   latestWeeklyHref,
+  loginHref,
   monthHref,
   searchHref,
   weeklyHref,
@@ -107,6 +111,16 @@
     expect(ADMIN_TEST_ALERT).toBe('/admin/test_alert')
   })
 
+  // P4 收藏：资源的键是链接的 url_hash；第 1 页不写 page
+  it('收藏页、书签的两个动作与带 next 的登录页', () => {
+    expect(FAVORITES).toBe('/favorites')
+    expect(favoritesHref()).toBe('/favorites')
+    expect(favoritesHref(1)).toBe('/favorites')
+    expect(favoritesHref(3)).toBe('/favorites?page=3')
+    expect(favoriteHref('abc123')).toBe('/favorites/abc123')
+    expect(loginHref('/daily/2026-09-08?source=src-hn')).toBe('/login?next=%2Fdaily%2F2026-09-08%3Fsource%3Dsrc-hn')
+  })
+
   // ④ 推荐理由：兴趣画像 CRUD、整期重生成理由端点
   it('兴趣画像与推荐理由', () => {
     expect(ADMIN_INTEREST_AREAS).toBe('/admin/interest_areas')
```

`test/frontend/components/FavoriteButton.test.tsx`（新建）：

```tsx
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import FavoriteButton from '@/components/FavoriteButton'
import { FavoritesProvider } from '@/lib/favorites'
import { router } from '../support/inertia'

// 条目上的书签与它背后的 FavoritesProvider（PRD 5.10、6.3，D30）：点一下立刻换态，请求走 fetch；
// 成功不出提示，失败回滚并提示附录 B 的句子；请求结束把最新的列表写回 Inertia 当前页。

const HASH = 'a'.repeat(64)
const TITLE = 'Show HN: A terminal log viewer written in Rust'
const ADD = `收藏：${TITLE}`
const REMOVE = `取消收藏：${TITLE}`

const ok = (body: Record<string, string> = {}, status = 201) => ({ ok: true, status, json: async () => body })
const rejected = (status: number) => ({ ok: false, status, json: async () => ({}) })

function tree(favorites: string[]) {
  return (
    <FavoritesProvider favorites={favorites}>
      <FavoriteButton itemId="itm-hn-1" urlHash={HASH} title={TITLE} />
    </FavoritesProvider>
  )
}

function mount(favorites: string[] = []) {
  return render(tree(favorites))
}

function stubFetch(response: unknown) {
  const fetchMock = vi.fn().mockResolvedValue(response)
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="tok-123">'
})

afterEach(() => {
  document.head.innerHTML = ''
  vi.unstubAllGlobals()
  router.replaceProp.mockClear()
  router.visit.mockClear()
  window.history.replaceState({}, '', '/')
})

describe('FavoriteButton', () => {
  it('页面没有套 FavoritesProvider 时不渲染', () => {
    const { container } = render(<FavoriteButton itemId="itm-hn-1" urlHash={HASH} title={TITLE} />)

    expect(container).toBeEmptyDOMElement()
  })

  it('未收藏是描线书签，名字带条目标题；已收藏带 data-on（实心）', () => {
    const { unmount } = mount()
    expect(screen.getByRole('button', { name: ADD })).not.toHaveAttribute('data-on')
    expect(screen.getByRole('button', { name: ADD })).toHaveClass('favorite-button')
    unmount()

    mount([HASH])
    expect(screen.getByRole('button', { name: REMOVE })).toHaveAttribute('data-on')
  })

  it('className 追加在 favorite-button 后面', () => {
    render(
      <FavoritesProvider favorites={[]}>
        <FavoriteButton className="item-mark" itemId="itm-hn-1" urlHash={HASH} title={TITLE} />
      </FavoritesProvider>,
    )

    expect(screen.getByRole('button', { name: ADD })).toHaveClass('favorite-button', 'item-mark')
  })

  // AC-10.1：点一下就换态，不等服务端；请求带条目 id 与 CSRF 令牌
  it('点一下收藏：立刻换成已收藏，POST 条目 id，结束后把列表写回当前页', async () => {
    const fetchMock = stubFetch(ok({ url_hash: HASH }))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(screen.getByRole('button', { name: REMOVE })).toHaveAttribute('data-on')
    expect(fetchMock).toHaveBeenCalledTimes(1)
    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe('/favorites')
    expect(init.method).toBe('POST')
    expect(init.body).toBe(JSON.stringify({ item_id: 'itm-hn-1' }))
    expect(init.headers['X-CSRF-Token']).toBe('tok-123')
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', [HASH]))
    // R-10.5 成功不出提示
    expect(screen.queryByRole('status')).toBeNull()
  })

  it('再点一下取消：DELETE /favorites/<url_hash>，列表写回空', async () => {
    const fetchMock = stubFetch(ok({ undo: 'signed-token' }, 200))
    mount([HASH])

    await userEvent.click(screen.getByRole('button', { name: REMOVE }))

    expect(screen.getByRole('button', { name: ADD })).not.toHaveAttribute('data-on')
    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe(`/favorites/${HASH}`)
    expect(init.method).toBe('DELETE')
    expect(init.body).toBeUndefined()
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', []))
  })

  // AC-10.9
  it('收藏没保存上：回到未收藏，提示附录 B 那一句', async () => {
    stubFetch(rejected(500))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(await screen.findByText('收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: ADD })).not.toHaveAttribute('data-on')
    expect(router.replaceProp).toHaveBeenCalledWith('favorites', [])
  })

  it('断网（fetch 直接 reject）同样回滚并提示', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(await screen.findByText('收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
  })

  it('取消没保存上：回到已收藏，提示「取消收藏没有保存，请重试。」', async () => {
    stubFetch(rejected(500))
    mount([HASH])

    await userEvent.click(screen.getByRole('button', { name: REMOVE }))

    expect(await screen.findByText('取消收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: REMOVE })).toHaveAttribute('data-on')
  })

  // AC-10.11
  it('限流 429：回滚并提示限流那一句', async () => {
    stubFetch(rejected(429))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    expect(await screen.findByText('操作过于频繁，请稍后再试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
  })

  it('同一句失败提示不叠两条', async () => {
    stubFetch(rejected(500))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))
    await screen.findByText('收藏没有保存，请重试。')
    await userEvent.click(screen.getByRole('button', { name: ADD }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledTimes(2))

    expect(screen.getAllByText('收藏没有保存，请重试。')).toHaveLength(1)
  })

  // PRD 5.10 边界：会话过期不保存，去登录页并带上当前地址，不提示失败
  it('会话过期 401：回滚，去登录页并带上当前地址', async () => {
    window.history.replaceState({}, '', '/daily/2026-09-08?source=src-hn')
    stubFetch(rejected(401))
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))

    await waitFor(() => expect(router.visit).toHaveBeenCalledWith('/login?next=%2Fdaily%2F2026-09-08%3Fsource%3Dsrc-hn'))
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
    expect(screen.queryByText('收藏没有保存，请重试。')).toBeNull()
  })

  it('请求还在路上时再点不重复发', async () => {
    let settle: (value: unknown) => void = () => undefined
    const fetchMock = vi.fn().mockReturnValue(new Promise((resolve) => { settle = resolve }))
    vi.stubGlobal('fetch', fetchMock)
    mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))
    await userEvent.click(screen.getByRole('button', { name: REMOVE }))

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(screen.getByRole('button', { name: REMOVE })).toBeInTheDocument()

    settle(ok({ url_hash: HASH }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', [HASH]))
  })

  it('读者已经离开这一页，请求回来后不再写当前页的 props', async () => {
    let settle: (value: unknown) => void = () => undefined
    vi.stubGlobal('fetch', vi.fn().mockReturnValue(new Promise((resolve) => { settle = resolve })))
    const view = mount()

    await userEvent.click(screen.getByRole('button', { name: ADD }))
    view.unmount()
    settle(ok({ url_hash: HASH }))
    await new Promise((resolve) => setTimeout(resolve, 0))

    expect(router.replaceProp).not.toHaveBeenCalled()
  })

  // 换期、生成中的轮询、历史恢复都会带来一份新的 favorites
  it('服务端给了新的列表就以它为准', () => {
    const view = mount()
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()

    view.rerender(tree([HASH]))
    expect(screen.getByRole('button', { name: REMOVE })).toBeInTheDocument()

    view.rerender(tree([]))
    expect(screen.getByRole('button', { name: ADD })).toBeInTheDocument()
  })
})
```

- [ ] **Step 2: 跑测试，确认失败**

```bash
npx vitest run test/frontend/components/FavoriteButton.test.tsx test/frontend/lib/paths.test.ts
```

预期：两个文件都失败——`FavoriteButton.test.tsx` 找不到 `@/components/FavoriteButton`，`paths.test.ts` 里 `FAVORITES` 是 `undefined`。

- [ ] **Step 3: 类型、地址、图标**

`app/frontend/types/lowpass.ts`：

```diff
--- a/app/frontend/types/lowpass.ts
+++ b/app/frontend/types/lowpass.ts
@@ -4,8 +4,8 @@
 // RSS 的首图与「时间是抓取时间不是发布时间」标记（Adapters::Rss、Adapters::RuanyfWeekly）。
 export type ItemMeta = { score?: number; comments?: number; comments_url?: string; language?: string; stars?: number; stars_today?: number; issue_no?: number; issue_title?: string; degraded?: boolean; anchor?: string; image_url?: string; image_urls?: string[]; time_from_fetch?: boolean };
 // title_zh 是 HN 与 Hackaday 标题的中文译文，summary_zh 是 GitHub Trending 简介的中文译文（D25）；
-// 都跟推荐理由同一次生成，没生成前与不译的源都是 null。
-export type Item = { id: string; title: string; title_zh: string | null; url: string; summary: string | null; summary_zh: string | null; content: string | null; section: string | null; author: string | null; published_at: string | null; rank: number | null; meta: ItemMeta; reason: string | null; interest_tag: string | null };
+// 都跟推荐理由同一次生成，没生成前与不译的源都是 null。url_hash 给书签用：收藏按链接认（D27）。
+export type Item = { id: string; url_hash: string; title: string; title_zh: string | null; url: string; summary: string | null; summary_zh: string | null; content: string | null; section: string | null; author: string | null; published_at: string | null; rank: number | null; meta: ItemMeta; reason: string | null; interest_tag: string | null };
 export type IssueState = "generating" | "published" | "empty";
 // status 与 time_label 是服务端定稿的期头文案（附录 B）：没有开 SSR，页面上读得到的字符串都得先进 props。
 export type DailyIssue = { period_key: string; year: number; date_label: string; weekday: string; state: IssueState | null; time_label: string | null; status: string | null; daily_time: string; published_at: string | null; revised_at: string | null; generated_late: boolean; is_yesterday: boolean; prev_key: string | null; next_key: string | null };
@@ -38,8 +38,12 @@
 export type DatePresets = Record<"7d" | "30d", DatePreset>;
 // 命中 run：hit 为真的那一段画 2px 墨色下划线（D22）
 export type HitRun = { text: string; hit: boolean };
-export type SearchResult = { item_id: string; rank: number; publication: Publication; source_name: string; where: { label: string; href: string }; published_label: string; url: string; title_runs: HitRun[]; snippet_runs: HitRun[] | null };
+export type SearchResult = { item_id: string; url_hash: string; rank: number; publication: Publication; source_name: string; where: { label: string; href: string }; published_label: string; url: string; title_runs: HitRun[]; snippet_runs: HitRun[] | null };
 
+// 收藏（PRD 5.10）：日刊、周刊、搜索、收藏四个页面的 props 都带 favorites——这一页里已收藏链接的 url_hash 列表。
+// 收藏页的一行（FavoritesController#entry_props）：字段照搜索结果行，标题不带命中 run；snippet 是不超过 160 字的摘要片段
+export type FavoriteEntry = { url_hash: string; publication: Publication; source_name: string; where: { label: string; href: string }; url: string; title: string; title_zh: string | null; snippet: string | null; summary_zh: string | null };
+
 // P2-① 登录（PRD 5.5）：ApplicationController 的 inertia_share 每页都带的两样，加登录页与设置页的字段
 export type CurrentUser = { display_name: string; avatar_url: string | null; email: string | null; admin: boolean };
 export type Flash = { id?: string; notice?: string; alert?: string };
```

`app/frontend/lib/paths.ts`：

```diff
--- a/app/frontend/lib/paths.ts
+++ b/app/frontend/lib/paths.ts
@@ -43,8 +43,15 @@
   return text ? `${SEARCH}?${text}` : SEARCH
 }
 
+// P4 收藏（config/routes.rb 的 resources :favorites）：资源的键是链接的 url_hash，不是行 id；第 1 页不写 page
+export const FAVORITES = '/favorites'
+export const favoritesHref = (page = 1) => (page > 1 ? `${FAVORITES}?page=${page}` : FAVORITES)
+export const favoriteHref = (urlHash: string) => `${FAVORITES}/${urlHash}`
+
 // P2-① 登录（config/routes.rb 的 login / session / settings，OmniAuth 的 /auth/:provider 与回调）
 export const LOGIN = '/login'
+// 会话过期后去登录页并带上当前地址（R-5.7：next 只认站内相对路径）
+export const loginHref = (next: string) => `${LOGIN}?next=${encodeURIComponent(next)}`
 export const SESSION = '/session'
 export const SETTINGS = '/settings'
 export const ADMIN_JOBS = '/admin/jobs'
```

`app/frontend/components/Icon.tsx`：

```diff
--- a/app/frontend/components/Icon.tsx
+++ b/app/frontend/components/Icon.tsx
@@ -1,4 +1,4 @@
-import { Archive, ArrowUp, ArrowUpRight, BookOpen, Check, ChevronLeft, ChevronRight, Clock, LogOut, MessageSquare, MessagesSquare, Plus, RefreshCw, Search, Star, TriangleAlert, User, X } from 'lucide'
+import { Archive, ArrowUp, ArrowUpRight, BookOpen, Bookmark, Check, ChevronLeft, ChevronRight, Clock, LogOut, MessageSquare, MessagesSquare, Plus, RefreshCw, Search, Star, TriangleAlert, User, X } from 'lucide'
 import { MorphIcon } from 'morphicons/react'
 
 // Lucide 提供图形数据，Morphicons 在同一个 SVG 内衔接状态；只导入实际使用的图标。
@@ -10,6 +10,7 @@
   'arrow-up': ArrowUp,
   archive: Archive,
   'book-open': BookOpen,
+  bookmark: Bookmark,
   clock: Clock,
   'message-square': MessageSquare,
   'messages-square': MessagesSquare,
```

- [ ] **Step 4: 收藏状态管理与书签按钮**

`app/frontend/lib/favorites.tsx`（新建）：

```tsx
import { router } from '@inertiajs/react'
import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, useState } from 'react'
import type * as React from 'react'

import { Toasts, useToasts } from '@/components/Toast'
import { FAVORITES, favoriteHref, loginHref } from '@/lib/paths'

// 收藏（PRD 5.10）。页面的 props 带着这一页里已收藏链接的 url_hash 列表；书签点一下先改本地状态
// （R-10.5：不整页刷新、成功不出提示），请求走 fetch（同 lib/search.ts，CSRF 令牌从布局的 meta 读）。
// 请求结束后把最新的列表写回 Inertia 当前页（router.replaceProp 只改历史里的 props，不发请求）：
// 离开再按后退，恢复出来的页面与服务端一致。失败回滚并提示附录 B 的句子。
export const COPY = {
  addFailed: '收藏没有保存，请重试。',
  removeFailed: '取消收藏没有保存，请重试。',
  limited: '操作过于频繁，请稍后再试。',
}

export type FavoriteTarget = { urlHash: string; itemId?: string }

export type Favorites = {
  has: (urlHash: string) => boolean
  // 这一次页面停留里取消过、还留在列表里等着「恢复」的（R-10.7）
  removed: (urlHash: string) => boolean
  toggle: (target: FavoriteTarget) => void
  restore: (urlHash: string) => void
}

const Context = createContext<Favorites | null>(null)

// 没有套 FavoritesProvider 的地方（单测里单独渲染的条目行）拿到 null，书签就不画
export function useFavorites(): Favorites | null {
  return useContext(Context)
}

class Rejected extends Error {
  status: number

  constructor(status: number) {
    super(`HTTP ${status}`)
    this.status = status
  }
}

async function send(method: 'POST' | 'DELETE', url: string, body?: Record<string, string>): Promise<Record<string, string>> {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
  const response = await fetch(url, {
    method,
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': token },
    body: body ? JSON.stringify(body) : undefined,
  })
  if (!response.ok) throw new Rejected(response.status)
  return response.status === 204 ? {} : ((await response.json()) as Record<string, string>)
}

function without(record: Record<string, string | null>, key: string): Record<string, string | null> {
  const { [key]: _dropped, ...rest } = record
  return rest
}

export function FavoritesProvider({ favorites, children }: React.PropsWithChildren<{ favorites: string[] }>) {
  // 真相放在 ref 里：连续两次点击读到的都是最新的一份，不会踩到过期的闭包；tick 只负责让界面跟上
  const kept = useRef(new Set(favorites))
  // 这条链接的请求还在路上：不重复发
  const busy = useRef(new Set<string>())
  // 取消的请求还没回来，读者就点了「恢复」：凭据到手后接着恢复
  const waiting = useRef(new Set<string>())
  const mounted = useRef(true)
  const [tick, redraw] = useReducer((count: number) => count + 1, 0)
  // url_hash → 恢复凭据；null 是取消的请求还没回来
  const [undo, setUndo] = useState<Record<string, string | null>>({})
  const { toasts, push, dismiss } = useToasts()

  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])

  // 服务端给了新的列表（换期、生成中的轮询、历史恢复）就以它为准。按内容比：自己刚写回去的那一份内容没变，不算新的
  const given = favorites.join(',')
  useEffect(() => {
    kept.current = new Set(given === '' ? [] : given.split(','))
    redraw()
  }, [given])

  const mark = useCallback((urlHash: string, on: boolean) => {
    if (on) kept.current.add(urlHash)
    else kept.current.delete(urlHash)
    redraw()
  }, [])

  const settle = useCallback((urlHash: string) => {
    busy.current.delete(urlHash)
    // 读者已经离开这一页就不写了：replaceProp 改的是「当前页」，写过去会盖掉别的页面的列表
    if (mounted.current) router.replaceProp('favorites', [...kept.current])
  }, [])

  const fail = useCallback(
    (error: unknown, text: string) => {
      const status = error instanceof Rejected ? error.status : 0
      if (status === 401) {
        // 会话过期：去登录页，登录后回到这一页；这一次不补做（PRD 5.10 边界）
        router.visit(loginHref(window.location.pathname + window.location.search))
      } else {
        const shown = status === 429 ? COPY.limited : text
        push('fail', shown, shown)
      }
    },
    [push],
  )

  // 收藏：书签带着条目 id 来，「恢复」带着取消时拿到的凭据来
  const add = useCallback(
    (urlHash: string, body: Record<string, string>) => {
      if (busy.current.has(urlHash)) return
      busy.current.add(urlHash)
      mark(urlHash, true)

      send('POST', FAVORITES, body)
        .then(() => setUndo((current) => without(current, urlHash)))
        .catch((error: unknown) => {
          mark(urlHash, false)
          fail(error, COPY.addFailed)
        })
        .finally(() => settle(urlHash))
    },
    [mark, fail, settle],
  )

  const remove = useCallback(
    (urlHash: string) => {
      if (busy.current.has(urlHash)) return
      busy.current.add(urlHash)
      mark(urlHash, false)
      setUndo((current) => ({ ...current, [urlHash]: null }))
      let token: string | undefined

      send('DELETE', favoriteHref(urlHash))
        .then((data) => {
          token = data.undo
          // 服务端说这条本来就不在了（204，没有凭据）：没什么可恢复的
          setUndo((current) => (token ? { ...current, [urlHash]: token } : without(current, urlHash)))
        })
        .catch((error: unknown) => {
          mark(urlHash, true)
          setUndo((current) => without(current, urlHash))
          fail(error, COPY.removeFailed)
        })
        .finally(() => {
          settle(urlHash)
          if (waiting.current.delete(urlHash) && token) add(urlHash, { undo: token })
        })
    },
    [mark, fail, settle, add],
  )

  const value = useMemo<Favorites>(
    () => ({
      has: (urlHash) => kept.current.has(urlHash),
      removed: (urlHash) => urlHash in undo && !kept.current.has(urlHash),
      toggle: ({ urlHash, itemId }) => {
        if (kept.current.has(urlHash)) remove(urlHash)
        else if (itemId) add(urlHash, { item_id: itemId })
      },
      restore: (urlHash) => {
        const token = undo[urlHash]
        if (token) add(urlHash, { undo: token })
        else if (urlHash in undo) waiting.current.add(urlHash)
      },
    }),
    // tick 进依赖：收藏集合变了，value 得换一个新的，读它的书签才会重画
    [tick, undo, add, remove],
  )

  return (
    <Context.Provider value={value}>
      {/* 没有提示时不画提示区：单测里它会就地画一个 role="status"，跟页面自己的状态区撞名 */}
      {toasts.length > 0 ? <Toasts items={toasts} onDismiss={dismiss} /> : null}
      {children}
    </Context.Provider>
  )
}
```

`app/frontend/components/FavoriteButton.tsx`（新建）：

```tsx
import type * as React from 'react'

import Icon from '@/components/Icon'
import { useFavorites } from '@/lib/favorites'

// 条目上的书签（PRD 6.3「收藏按钮」、D30）：点一下收藏，再点取消，不弹确认。两态靠形状分——描线是未收藏，
// 实心是已收藏（tokens.css 的 .favorite-button[data-on]），不靠颜色。可读名称随状态换成「收藏」/「取消收藏」
// 并带条目标题（附录 B）。44px 见方的独立目标，与标题链接分开。页面没有套 FavoritesProvider 时不渲染。
export type FavoriteButtonProps = {
  urlHash: string
  title: string
  // 收藏页的行没有条目 id：那里的书签只会取消，恢复走「恢复」那个按钮
  itemId?: string
  className?: string
  ref?: React.Ref<HTMLButtonElement>
}

export default function FavoriteButton({ urlHash, title, itemId, className, ref }: FavoriteButtonProps) {
  const favorites = useFavorites()
  if (!favorites) return null

  const on = favorites.has(urlHash)

  return (
    <button
      ref={ref}
      type="button"
      className={className ? `favorite-button ${className}` : 'favorite-button'}
      data-on={on ? '' : undefined}
      aria-label={`${on ? '取消收藏' : '收藏'}：${title}`}
      onClick={() => favorites.toggle({ urlHash, itemId })}
    >
      <Icon name="bookmark" size={18} color="currentColor" />
    </button>
  )
}
```

- [ ] **Step 5: 样式**

`app/frontend/styles/tokens.css`（加在文件末尾，逐字来自界面稿的 `<style id="proposed">`）：

```diff
--- a/app/frontend/styles/tokens.css
+++ b/app/frontend/styles/tokens.css
@@ -812,3 +812,26 @@
   .model-name-field, .model-name-field > .field, .model-name-detail { width: 100% !important; max-width: 100%; }
   .source-band-meta { width: 100%; }
 }
+
+/* ─── 收藏（P4，PRD 5.10、6.3）──────────────────────────────────────────
+   界面稿：docs/design/notes/2026-09-30-favorites-mock.html。
+   书签：44px 见方的独立目标（PRD 6.4），描线是未收藏、实心是已收藏——两态靠形状分，不靠颜色（D30）。
+   条目行里它在行末另占一列；手机上与序号同一行、靠右，不挤标题。搜索结果与收藏页的行里它在底行右端。
+   18px 的图标居中在 44px 的目标里，两边各空 13px：右边距收回 13px，图标的右缘才跟正文右缘、分页按钮对齐。 */
+.favorite-button { flex: none; display: inline-flex; align-items: center; justify-content: center; width: 44px; height: 44px; padding: 0; margin-right: -13px;
+                   border: 0; background: none; color: var(--ink2); cursor: pointer; }
+.favorite-button:hover, .favorite-button[data-on] { color: var(--ink); }
+.favorite-button[data-on] svg, .favorite-button[data-on] svg path { fill: currentColor; }
+.favorite-button:focus-visible { outline: 2px solid var(--ink); outline-offset: -6px; }
+.item-row { grid-template-columns: 28px minmax(0, 1fr) 31px; grid-template-areas: "rank body mark"; }
+.item-mark { grid-area: mark; margin-top: -8px; }
+.search-mark { margin-left: auto; }
+/* 收藏页上取消的那一行：原地留一句状态与「恢复」（R-10.7） */
+.favorite-removed { display: inline-flex; align-items: center; gap: 12px; min-height: 44px; font-family: var(--font-cjk); font-size: var(--fs-13); color: var(--ink2); }
+@media (max-width: 767px) {
+  .item-row { grid-template-columns: minmax(0, 1fr) 31px; grid-template-areas: "rank mark" "body body"; align-items: center; }
+  .item-mark { margin-top: -12px; margin-bottom: -12px; }
+}
+@media (min-width: 1920px) {
+  .item-row { grid-template-columns: 32px minmax(0, 1fr) 31px; }
+}
```

- [ ] **Step 6: 跑测试，确认通过**

```bash
npm run check
npm test
```

预期：`npm run check` 没有错误；`npm test` 是 `Test Files  40 passed`、`Tests  371 passed`（基线 356，加 `FavoriteButton.test.tsx` 的 14 条与 `paths.test.ts` 的 1 条）。

- [ ] **Step 7: 提交**

```bash
git add app/frontend/lib/favorites.tsx app/frontend/components/FavoriteButton.tsx app/frontend/types/lowpass.ts app/frontend/lib/paths.ts app/frontend/components/Icon.tsx app/frontend/styles/tokens.css test/frontend/components/FavoriteButton.test.tsx test/frontend/lib/paths.test.ts test/frontend/support/inertia.tsx test/frontend/support/props.ts
git -c commit.gpgsign=false commit -m "书签按钮与收藏状态管理：乐观更新、失败回滚、写回 Inertia 当前页" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: 书签接进条目行、搜索结果行与三个阅读页；分页抽成共用组件

**Files:**
- Create: `app/frontend/components/Pager.tsx`
- Modify: `app/frontend/components/ItemRow.tsx`、`app/frontend/components/SearchResultRow.tsx`、`app/frontend/pages/Daily/Show.tsx`、`app/frontend/pages/Weekly/Show.tsx`、`app/frontend/pages/Search/Show.tsx`
- Test: `test/frontend/components/Pager.test.tsx`（新建）、`test/frontend/components/ItemRow.test.tsx`、`test/frontend/pages/DailyShow.test.tsx`、`test/frontend/pages/WeeklyShow.test.tsx`、`test/frontend/pages/SearchShow.test.tsx`

**Interfaces:**
- Consumes: `FavoritesProvider`、`FavoriteButton`、`Item.url_hash`、`SearchResult.url_hash`（Task 5）；页面 props 的 `favorites`（Task 4）。
- Produces:
  - `Pager`，props `{ prevHref: string | null; nextHref: string | null; page: number; pages: number }`，渲染的还是 `<nav class="search-pager" aria-label="分页">`。
  - `ItemRow` 导出具名组件 `Translation`（props `{ text: string }`），给收藏页的行用。
  - `DailyShowProps`、`WeeklyShowProps`、`SearchShowProps` 各多一个必填的 `favorites: string[]`。
  - 日刊页生成中的轮询多重载一个 `favorites`。

- [ ] **Step 1: 写失败的测试**

`test/frontend/components/Pager.test.tsx`（新建）：

```tsx
import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Pager from '@/components/Pager'

// 分页「上一页 · n / m · 下一页」：搜索页与收藏页共用，地址由调用方给

describe('Pager', () => {
  it('两头都有地址时是两个链接，中间是「n / m」', () => {
    render(<Pager prevHref="/favorites" nextHref="/favorites?page=3" page={2} pages={3} />)
    const pager = within(screen.getByRole('navigation', { name: '分页' }))

    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('href', '/favorites')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/favorites?page=3')
    expect(screen.getByRole('navigation', { name: '分页' })).toHaveTextContent('2 / 3')
  })

  it('没有地址的那一头退成不可点态', () => {
    render(<Pager prevHref={null} nextHref={null} page={1} pages={1} />)
    const pager = within(screen.getByRole('navigation', { name: '分页' }))

    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('aria-disabled', 'true')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('aria-disabled', 'true')
  })
})
```

`test/frontend/components/ItemRow.test.tsx`：

```diff
--- a/test/frontend/components/ItemRow.test.tsx
+++ b/test/frontend/components/ItemRow.test.tsx
@@ -3,6 +3,7 @@
 import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
 
 import ItemRow from '@/components/ItemRow'
+import { FavoritesProvider } from '@/lib/favorites'
 import { setPageProps } from '../support/inertia'
 import { item } from '../support/props'
 
@@ -412,3 +413,43 @@
     expect(screen.queryByRole('button', { name: '重生成' })).toBeNull()
   })
 })
+
+describe('ItemRow 书签（PRD 5.10）', () => {
+  const TITLE = 'Show HN: A terminal log viewer written in Rust'
+
+  it('页面套了 FavoritesProvider：条目行末有书签，排在正文后面，状态照 favorites', () => {
+    const { container, unmount } = render(
+      <FavoritesProvider favorites={[]}>
+        <ItemRow item={hn()} adapter="hacker_news" rank={1} />
+      </FavoritesProvider>,
+    )
+    const mark = screen.getByRole('button', { name: `收藏：${TITLE}` })
+    expect(mark).toHaveClass('favorite-button', 'item-mark')
+    // Tab 先到标题再到书签：书签在 DOM 里排在正文后面
+    expect(container.querySelector('.item-body')?.nextElementSibling).toBe(mark)
+    unmount()
+
+    render(
+      <FavoritesProvider favorites={['hash-termlog']}>
+        <ItemRow item={hn()} adapter="hacker_news" rank={1} />
+      </FavoritesProvider>,
+    )
+    expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toHaveAttribute('data-on')
+  })
+
+  it('周刊那一版同样有书签', () => {
+    render(
+      <FavoritesProvider favorites={[]}>
+        <ItemRow item={item({ title: '人生的容错率' })} adapter="ruanyf_weekly" rank={1} variant="weekly" heading="h4" />
+      </FavoritesProvider>,
+    )
+
+    expect(screen.getByRole('button', { name: '收藏：人生的容错率' })).toBeInTheDocument()
+  })
+
+  it('没有 FavoritesProvider 时条目行里没有书签', () => {
+    const { container } = render(<ItemRow item={hn()} adapter="hacker_news" rank={1} />)
+
+    expect(container.querySelector('.favorite-button')).toBeNull()
+  })
+})
```

`test/frontend/pages/DailyShow.test.tsx`（样例 props 补 `favorites`；轮询的断言多一个键；末尾加一条）：

```diff
--- a/test/frontend/pages/DailyShow.test.tsx
+++ b/test/frontend/pages/DailyShow.test.tsx
@@ -22,6 +22,7 @@
     missing: false,
     sources,
     items_by_source: { 'src-hn': [item()] },
+    favorites: [],
     active_source_id: 'src-hn',
     latest_weekly_key: '2026-W36',
     ...overrides,
@@ -71,7 +72,7 @@
     const { unmount } = show({ issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新', time_label: '06:00' }) })
 
     vi.advanceTimersByTime(10_000)
-    expect(router.reload).toHaveBeenCalledWith({ only: ['issue', 'missing', 'sources', 'items_by_source'] })
+    expect(router.reload).toHaveBeenCalledWith({ only: ['issue', 'missing', 'sources', 'items_by_source', 'favorites'] })
     unmount()
 
     router.reload.mockClear()
@@ -297,3 +298,13 @@
  expect(screen.getByRole('status')).toHaveTextContent('这一天已有期')
  expect(screen.getByRole('button', { name: '补生成本期' })).toBeEnabled()
 })
+
+// PRD 5.10：页面把 favorites 交给 FavoritesProvider，条目行的书签对着它画
+it('条目行有书签，已收藏的链接是实心', () => {
+  const { unmount } = show()
+  expect(screen.getByRole('button', { name: '收藏：Show HN: A terminal log viewer written in Rust' })).not.toHaveAttribute('data-on')
+  unmount()
+
+  show({ favorites: ['hash-termlog'] })
+  expect(screen.getByRole('button', { name: '取消收藏：Show HN: A terminal log viewer written in Rust' })).toHaveAttribute('data-on')
+})
```

`test/frontend/pages/WeeklyShow.test.tsx`（三处渲染补 `favorites`；末尾加一条）：

```diff
--- a/test/frontend/pages/WeeklyShow.test.tsx
+++ b/test/frontend/pages/WeeklyShow.test.tsx
@@ -11,6 +11,7 @@
   const props: WeeklyShowProps = {
     issue: weeklyIssue(),
     sections: [weeklySection()],
+    favorites: [],
     daily_time: '06:00',
     latest_weekly_key: '2026-W36',
     ...overrides,
@@ -21,7 +22,7 @@
 
 describe('周刊期头', () => {
   it('周次是 h1，年份与日期范围在右侧', () => {
-    render(<Show issue={weeklyIssue()} sections={[]} daily_time="06:00" latest_weekly_key="2026-W36" />)
+    render(<Show issue={weeklyIssue()} sections={[]} favorites={[]} daily_time="06:00" latest_weekly_key="2026-W36" />)
 
     expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('第 36 周')
     expect(screen.getByText('2026')).toBeInTheDocument()
@@ -48,6 +49,7 @@
       <Show
         issue={weeklyIssue({ state: null, status: '本周无内容', published_at: null })}
         sections={[]}
+        favorites={[]}
         daily_time="06:00"
         latest_weekly_key="2026-W36"
       />,
@@ -335,4 +337,14 @@
   } finally {
     vi.unstubAllGlobals()
   }
+})
+
+// PRD 5.10：周刊条目同样有书签；降级成整期一条的节是一句提示，不是条目行，没有书签（R-10.4）
+it('周刊条目有书签，降级的节没有', () => {
+  const { unmount } = show({ favorites: ['hash-termlog'] })
+  expect(screen.getByRole('button', { name: '取消收藏：人生的容错率' })).toHaveAttribute('data-on')
+  unmount()
+
+  const { container } = show({ sections: [weeklySection({ degraded: true })] })
+  expect(container.querySelector('.favorite-button')).toBeNull()
 })
```

`test/frontend/pages/SearchShow.test.tsx`：

```diff
--- a/test/frontend/pages/SearchShow.test.tsx
+++ b/test/frontend/pages/SearchShow.test.tsx
@@ -21,6 +21,7 @@
     date_presets: { '7d': { from: '2026-09-05', to: '2026-09-11' }, '30d': { from: '2026-08-13', to: '2026-09-11' } },
     state: 'initial',
     results: [],
+    favorites: [],
     total: 0,
     page: 1,
     pages: 0,
@@ -279,6 +280,17 @@
     expect(title).toHaveAttribute('rel', 'noopener noreferrer')
     expect(within(row).getByRole('link', { name: /^所在期\s*·\s*2026年9月8日$/ })).toHaveAttribute('href', '/daily/2026-09-08?source=src-hn#item-itm-hn-1')
     expect(within(row).getByRole('link', { name: '原文' })).toHaveAttribute('href', 'https://example.com/k8s-rust')
+  })
+
+  // PRD 5.10：书签在底行右端，名字用没有高亮切分的整句标题
+  it('结果行有书签，状态照 favorites', () => {
+    const { container, unmount } = results()
+    const mark = within(container.querySelector('.search-links') as HTMLElement).getByRole('button', { name: '收藏：Kubernetes operator in Rust' })
+    expect(mark).toHaveClass('favorite-button', 'search-mark')
+    unmount()
+
+    results({ favorites: ['hash-k8s-rust'] })
+    expect(screen.getByRole('button', { name: '取消收藏：Kubernetes operator in Rust' })).toHaveAttribute('data-on')
   })
 
   // 日刊的所在期就是那一天，日期与它相同：眉行只写一次；周刊的所在期是「2026年 · 第 36 周 · 工具」，日期另有信息，两个都写
```

- [ ] **Step 2: 跑测试，确认失败**

```bash
npm run check
npx vitest run test/frontend/components/Pager.test.tsx test/frontend/components/ItemRow.test.tsx test/frontend/pages/DailyShow.test.tsx test/frontend/pages/WeeklyShow.test.tsx test/frontend/pages/SearchShow.test.tsx
```

预期：`npm run check` 报三个页面的 props 里没有 `favorites`；vitest 里 `Pager.test.tsx` 找不到模块，其余四个文件里新加的书签断言失败、日刊轮询那一条失败。

- [ ] **Step 3: 共用的分页组件**

`app/frontend/components/Pager.tsx`（新建）：

```tsx
import { Ctrl } from '@/components/Ctrl'

// 分页「上一页 · n / m · 下一页」（R-4.7、R-10.6，画布 pager()）：搜索页与收藏页共用，地址由调用方给；
// 没有上一页或下一页时那一头退成不可点态。
export type PagerProps = { prevHref: string | null; nextHref: string | null; page: number; pages: number }

export default function Pager({ prevHref, nextHref, page, pages }: PagerProps) {
  return (
    <nav className="search-pager" aria-label="分页">
      <Ctrl href={prevHref} label="上一页" icon="chevron-left" side="left" />
      <span className="search-page">
        {page} / {pages}
      </span>
      <Ctrl href={nextHref} label="下一页" icon="chevron-right" side="right" />
    </nav>
  )
}
```

- [ ] **Step 4: 条目行与搜索结果行**

`app/frontend/components/ItemRow.tsx`（书签在 DOM 里排在正文后面：Tab 先到标题再到书签；视觉位置由网格区域 `mark` 定）：

```diff
--- a/app/frontend/components/ItemRow.tsx
+++ b/app/frontend/components/ItemRow.tsx
@@ -2,6 +2,7 @@
 import { Fragment, useState } from 'react'
 
 import Chip from '@/components/Chip'
+import FavoriteButton from '@/components/FavoriteButton'
 import Icon, { type IconName } from '@/components/Icon'
 import { Mixed, absoluteStamp, compactCount, latinLang, relativeAge } from '@/lib/typeset'
 import type { Adapter, Item } from '@/types/lowpass'
@@ -10,6 +11,7 @@
 // 说明译文（GitHub Trending，D25）、元数据、兴趣标签、推荐理由。元数据行只有数字与记号，不出现中文单位（设计 skill）。
 // 周刊那一版（variant="weekly"）只有序号、标题、摘要与发布时间（D19）。
 // 标签锚定条目行末端；窄屏自然换行，仍属于同一阅读组。
+// 书签（PRD 5.10）在条目行末另占一格，手机上与序号同一行、靠右；DOM 里排在正文后面，Tab 先到标题再到书签。
 // 画布：docs/design/src/pages_front3.py 的 item() 与 item_m()。
 
 const data = { fontFamily: 'var(--font-data)', fontSize: 'var(--fs-13)', color: 'var(--ink2)' } as const
@@ -107,8 +109,8 @@
 
 // D25 译文紧跟它译的那段原文：HN 与 Hackaday 在标题下，GitHub Trending 在简介下。不是链接（卡片只有标题可点）。
 // 中文走文楷，夹在里面的产品名、项目名走 Newsreader，跟原文同一字体（设计 skill「译文排进 Newsreader」那条偏差的改法）；
-// 字号与颜色交给 CSS 按断点走。
-function Translation({ text }: { text: string }) {
+// 字号与颜色交给 CSS 按断点走。收藏页的行也用它。
+export function Translation({ text }: { text: string }) {
   return (
     <p className="item-translation">
       <Mixed text={text} font="latin" size="inherit" color="inherit" weight={400} />
@@ -192,6 +194,8 @@
         <Meta item={item} adapter={adapter} rank={rank} variant={variant} />
         {!weekly && item.reason ? <div className="item-reason">{item.reason}</div> : null}
       </div>
+
+      <FavoriteButton className="item-mark" itemId={item.id} urlHash={item.url_hash} title={item.title} />
     </article>
   )
 }
```

`app/frontend/components/SearchResultRow.tsx`：

```diff
--- a/app/frontend/components/SearchResultRow.tsx
+++ b/app/frontend/components/SearchResultRow.tsx
@@ -1,6 +1,7 @@
 import { Link } from '@inertiajs/react'
 
 import Chip from '@/components/Chip'
+import FavoriteButton from '@/components/FavoriteButton'
 import HitText from '@/components/HitText'
 import Icon from '@/components/Icon'
 import { reportClick } from '@/lib/search'
@@ -8,7 +9,7 @@
 import type { HitRun, SearchResult } from '@/types/lowpass'
 
 // 结果行（R-4.6、画布 search_row()）：眉行「刊物反白签 · 来源名 · 所在期 · 日期」，标题与摘要片段带命中下划线，
-// 底行「所在期 · …」与「原文 ↗」。点标题或原文先上报一次 search_click（9.1）再由浏览器打开（R-8.4 新标签页）；
+// 底行「所在期 · …」与「原文 ↗」，右端是书签（PRD 5.10）。点标题或原文先上报一次 search_click（9.1）再由浏览器打开（R-8.4 新标签页）；
 // 所在期是站内直链，不计。
 
 const LABELS: Record<SearchResult['publication'], string> = { daily: '日刊', weekly: '周刊' }
@@ -54,6 +55,7 @@
           <span>原文</span>
           <Icon name="arrow-up-right" size={12} />
         </a>
+        <FavoriteButton className="search-mark" itemId={result.item_id} urlHash={result.url_hash} title={runText(result.title_runs)} />
       </div>
     </article>
   )
```

- [ ] **Step 5: 三个阅读页**

`app/frontend/pages/Daily/Show.tsx`：

```diff
--- a/app/frontend/pages/Daily/Show.tsx
+++ b/app/frontend/pages/Daily/Show.tsx
@@ -10,6 +10,7 @@
 import SourceState from '@/components/SourceState'
 import SourceTabs from '@/components/SourceTabs'
 import { useScrollToHash } from '@/lib/anchors'
+import { FavoritesProvider } from '@/lib/favorites'
 import { DAILY_ARCHIVE, adminIssueBackfillHref, dailyHref, latestWeeklyHref } from '@/lib/paths'
 import { usePolling } from '@/lib/polling'
 import { Mixed } from '@/lib/typeset'
@@ -23,6 +24,8 @@
   missing: boolean
   sources: SourceSummary[]
   items_by_source: Record<string, Item[]>
+  // 这一期里当前读者收藏过的链接（url_hash），书签对着它画（PRD 5.10）
+  favorites: string[]
   active_source_id: string | null
   latest_weekly_key: string | null
   latest_daily_key?: string | null
@@ -104,11 +107,11 @@
 }
 
 // 「生成中，约 1 分钟后刷新」要说到做到：生成中每 10 秒部分重载这一期，定稿（发布或空刊）了就停。
-// 只重载期与各栏，不动读者选中的来源（那是本地状态）。
-const GENERATING_RELOAD = ['issue', 'missing', 'sources', 'items_by_source']
+// 只重载期与各栏，不动读者选中的来源（那是本地状态）。条目出来了书签才有东西可画，所以 favorites 一起重载。
+const GENERATING_RELOAD = ['issue', 'missing', 'sources', 'items_by_source', 'favorites']
 const GENERATING_POLL_MS = 10_000
 
-export default function Show({ issue, missing, sources, items_by_source, active_source_id, latest_daily_key, backfill_available }: DailyShowProps) {
+export default function Show({ issue, missing, sources, items_by_source, favorites, active_source_id, latest_daily_key, backfill_available }: DailyShowProps) {
   useScrollToHash(issue.period_key)
   usePolling(issue.state === 'generating', GENERATING_RELOAD, GENERATING_POLL_MS)
   const notice = bodyNotice(issue, missing)
@@ -131,7 +134,7 @@
   }
 
   return (
-    <>
+    <FavoritesProvider favorites={favorites}>
       <IssueHead issue={issue} archiveHref={DAILY_ARCHIVE} hrefFor={dailyHref} />
 
       {/* R-1.6 缺期没有来源索引条，列表区只有「本期未生成」那一句 */}
@@ -150,8 +153,7 @@
           notice={notice}
         />
       )}
-
-    </>
+    </FavoritesProvider>
   )
 }
 
```

`app/frontend/pages/Weekly/Show.tsx`：

```diff
--- a/app/frontend/pages/Weekly/Show.tsx
+++ b/app/frontend/pages/Weekly/Show.tsx
@@ -8,6 +8,7 @@
 import Layout from '@/components/Layout'
 import PageHead from '@/components/PageHead'
 import { useScrollToHash } from '@/lib/anchors'
+import { FavoritesProvider } from '@/lib/favorites'
 import { WEEKLY_ARCHIVE, latestWeeklyHref, weeklyHref } from '@/lib/paths'
 import { Mixed, latinLang } from '@/lib/typeset'
 import type { FooterData, WeeklyGroup, WeeklyIssue, WeeklySection } from '@/types/lowpass'
@@ -25,6 +26,8 @@
 export type WeeklyShowProps = FooterData & {
   issue: WeeklyIssue
   sections: WeeklySection[]
+  // 这一期里当前读者收藏过的链接（url_hash），书签对着它画（PRD 5.10）
+  favorites: string[]
 }
 
 // 反白横带：期号是来源的说明信息，跟随源名形成一个阅读组；右端只保留原文操作。
@@ -182,10 +185,10 @@
   )
 }
 
-export default function Show({ issue, sections }: WeeklyShowProps) {
+export default function Show({ issue, sections, favorites }: WeeklyShowProps) {
   useScrollToHash(issue.period_key)
   return (
-    <>
+    <FavoritesProvider favorites={favorites}>
       <PageHead
         big={issue.week_label}
         title={`周刊 · ${issue.year} · ${issue.week_label}`}
@@ -204,7 +207,7 @@
       ) : (
         sections.map((section) => <Section key={`${section.source.id}-${section.issue_no ?? 0}`} section={section} />)
       )}
-    </>
+    </FavoritesProvider>
   )
 }
 
```

`app/frontend/pages/Search/Show.tsx`（本地的 `Pager` 改成薄薄一层 `SearchPager`，算好地址交给共用的 `Pager`）：

```diff
--- a/app/frontend/pages/Search/Show.tsx
+++ b/app/frontend/pages/Search/Show.tsx
@@ -5,9 +5,11 @@
 import { Ctrl } from '@/components/Ctrl'
 import Icon from '@/components/Icon'
 import Layout from '@/components/Layout'
+import Pager from '@/components/Pager'
 import SearchFilters, { hasActiveFilters } from '@/components/SearchFilters'
 import SearchResultRow from '@/components/SearchResultRow'
 import Seg from '@/components/Seg'
+import { FavoritesProvider } from '@/lib/favorites'
 import { dailyHref, latestWeeklyHref, searchHref } from '@/lib/paths'
 import { Mixed } from '@/lib/typeset'
 import type { DatePresets, FooterData, SearchFilters as Filters, SearchResult, SearchSourceOption, SearchState } from '@/types/lowpass'
@@ -24,6 +26,8 @@
   date_presets: DatePresets
   state: SearchState
   results: SearchResult[]
+  // 这一页结果里当前读者收藏过的链接（url_hash），书签对着它画（PRD 5.10）
+  favorites: string[]
   total: number
   page: number
   pages: number
@@ -105,18 +109,17 @@
   )
 }
 
-// R-4.7 分页「上一页 · n / m · 下一页」（画布 pager()）
-function Pager({ q, committedQuery, filters, page, pages }: { q: string; committedQuery: string; filters: Filters; page: number; pages: number }) {
+// R-4.7 分页：草稿里的查询词变了，翻页就从新查询的第 1 页开始
+function SearchPager({ q, committedQuery, filters, page, pages }: { q: string; committedQuery: string; filters: Filters; page: number; pages: number }) {
   const pageFor = (target: number) => q === committedQuery ? target : 1
 
   return (
-    <nav className="search-pager" aria-label="分页">
-      <Ctrl href={page > 1 ? hrefOf(q, filters, pageFor(page - 1)) : null} label="上一页" icon="chevron-left" side="left" />
-      <span className="search-page">
-        {page} / {pages}
-      </span>
-      <Ctrl href={page < pages ? hrefOf(q, filters, pageFor(page + 1)) : null} label="下一页" icon="chevron-right" side="right" />
-    </nav>
+    <Pager
+      prevHref={page > 1 ? hrefOf(q, filters, pageFor(page - 1)) : null}
+      nextHref={page < pages ? hrefOf(q, filters, pageFor(page + 1)) : null}
+      page={page}
+      pages={pages}
+    />
   )
 }
 
@@ -172,7 +175,7 @@
               <SearchResultRow key={result.item_id} result={result} q={q} />
             ))}
           </div>
-          {pages > 1 ? <Pager q={props.navigationQuery} committedQuery={q} filters={filters} page={page} pages={pages} /> : null}
+          {pages > 1 ? <SearchPager q={props.navigationQuery} committedQuery={q} filters={filters} page={page} pages={pages} /> : null}
         </>
       )
   }
@@ -205,7 +208,7 @@
   const navigationQuery = draft.trim()
 
   return (
-    <>
+    <FavoritesProvider favorites={props.favorites}>
       <Head title={props.q ? `搜索 · ${props.q}` : '搜索'} />
       {/* PRD 6.4 标题层级：这一页的 h1 是页名「搜索」（PRD 6.2），只给读屏器，视觉上期头本身就是标题；结果标题是 h2 */}
       <h1 className="sr-only">搜索</h1>
@@ -213,7 +216,7 @@
       <SearchFilters q={navigationQuery} filters={props.filters} sourceOptions={props.source_options} datePresets={props.date_presets} />
       <div id="search-status" className={loading ? 'search-loading' : notice ? 'search-notice state-line' : 'sr-only'} role="status" aria-live="polite" aria-atomic="true">{liveText}</div>
       <Body {...props} navigationQuery={navigationQuery} onModifyQuery={modifyQuery} loading={loading} />
-    </>
+    </FavoritesProvider>
   )
 }
 
```

- [ ] **Step 6: 跑测试，确认通过**

```bash
npm run check
npm test
```

预期：`npm run check` 没有错误；`npm test` 是 `Test Files  41 passed`、`Tests  379 passed`。

- [ ] **Step 7: 提交**

```bash
git add app/frontend/components/Pager.tsx app/frontend/components/ItemRow.tsx app/frontend/components/SearchResultRow.tsx app/frontend/pages/Daily/Show.tsx app/frontend/pages/Weekly/Show.tsx app/frontend/pages/Search/Show.tsx test/frontend/components/Pager.test.tsx test/frontend/components/ItemRow.test.tsx test/frontend/pages/DailyShow.test.tsx test/frontend/pages/WeeklyShow.test.tsx test/frontend/pages/SearchShow.test.tsx
git -c commit.gpgsign=false commit -m "书签接进条目行、搜索结果行与三个阅读页；分页抽成共用组件" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: 收藏页与头像菜单入口

**Files:**
- Create: `app/frontend/pages/Favorites/Index.tsx`
- Modify: `app/frontend/components/Masthead.tsx`
- Test: `test/frontend/pages/FavoritesIndex.test.tsx`（新建）、`test/frontend/components/Masthead.test.tsx`

**Interfaces:**
- Consumes: Task 3 的页面 props（`entries`、`favorites`、`page`、`pages` 与页脚三样）；`FavoriteEntry`、`FAVORITES`、`favoritesHref`、`FavoritesProvider`、`useFavorites`、`FavoriteButton`（Task 5）；`Pager`、`Translation`（Task 6）；已有的 `PageHead`、`IssueNotice`、`Chip`、`Mixed`、`Layout`。
- Produces: Inertia 页面 `Favorites/Index`（`FavoritesIndexProps`）；头像菜单在「账户信息」后面多一项「收藏」，指向 `/favorites`。

- [ ] **Step 1: 写失败的测试**

`test/frontend/pages/FavoritesIndex.test.tsx`（新建）：

```tsx
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import Index, { type FavoritesIndexProps } from '@/pages/Favorites/Index'
import { router } from '../support/inertia'
import { favoriteEntry } from '../support/props'

// 收藏页（PRD 5.10、R-10.6、R-10.7）：行沿用搜索结果行；取消后原地留「已取消收藏」与「恢复」。
// 文案是附录 B 原句。

const TITLE = 'Show HN: A terminal log viewer written in Rust'

function show(overrides: Partial<FavoritesIndexProps> = {}) {
  const props: FavoritesIndexProps = {
    entries: [favoriteEntry()],
    favorites: ['hash-termlog'],
    page: 1,
    pages: 1,
    latest_daily_key: '2026-09-08',
    daily_time: '06:00',
    latest_weekly_key: '2026-W36',
    ...overrides,
  }

  return render(<Index {...props} />)
}

const ok = (body: Record<string, string> = {}, status = 201) => ({ ok: true, status, json: async () => body })

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="tok-123">'
})

afterEach(() => {
  document.head.innerHTML = ''
  vi.unstubAllGlobals()
  router.replaceProp.mockClear()
})

describe('收藏页的行', () => {
  it('页名是 h1「收藏」；一行有刊物签、来源、所在期、标题外链、所在期链接、原文与书签', () => {
    const { container } = show()

    expect(screen.getByRole('heading', { level: 1, name: '收藏' })).toBeInTheDocument()
    expect(document.title).toBe('收藏 · Lowpass')

    const row = container.querySelector('.search-row') as HTMLElement
    const eyebrow = row.querySelector('.search-eyebrow') as HTMLElement
    expect(eyebrow).toHaveTextContent('日刊')
    expect(eyebrow).toHaveTextContent('Hacker News')
    expect(eyebrow).toHaveTextContent('2026年9月8日')

    const title = within(row).getByRole('link', { name: TITLE })
    expect(within(row).getByRole('heading', { level: 2 })).toContainElement(title)
    expect(title).toHaveAttribute('href', 'https://example.com/termlog')
    expect(title).toHaveAttribute('target', '_blank')
    expect(title.getAttribute('rel')).toContain('noopener')
    expect(title).toHaveAttribute('lang', 'en')

    expect(within(row).getByRole('link', { name: /^所在期\s*·\s*2026年9月8日$/ })).toHaveAttribute('href', '/daily/2026-09-08?source=src-hn#item-itm-hn-1')
    expect(within(row).getByRole('link', { name: '原文' })).toHaveAttribute('href', 'https://example.com/termlog')
    expect(within(row).getByRole('button', { name: `取消收藏：${TITLE}` })).toHaveAttribute('data-on')
  })

  it('译文与摘要片段有就显示，没有就没有那一行', () => {
    const { container, unmount } = show()
    expect(container.querySelector('.item-translation')).toBeNull()
    expect(container.querySelector('.search-snippet')).toBeNull()
    unmount()

    const view = show({
      entries: [
        favoriteEntry({ title_zh: 'Show HN：一个用 Rust 写的终端日志查看器' }),
        favoriteEntry({ url_hash: 'hash-ruff', title: 'astral-sh/ruff', url: 'https://github.com/astral-sh/ruff', source_name: 'GitHub Trending', snippet: 'An extremely fast Python linter.', summary_zh: '一个极快的 Python 代码检查工具。' }),
      ],
      favorites: ['hash-termlog', 'hash-ruff'],
    })

    const rows = view.container.querySelectorAll('.search-row')
    // D25 的位置：标题译文紧跟标题，简介译文紧跟简介
    expect(rows[0].querySelector('.search-title')?.nextElementSibling).toHaveTextContent('Show HN：一个用 Rust 写的终端日志查看器')
    expect(rows[0].querySelector('.search-title')?.nextElementSibling).toHaveClass('item-translation')
    expect(rows[1].querySelector('.search-snippet')).toHaveTextContent('An extremely fast Python linter.')
    expect(rows[1].querySelector('.search-snippet')?.nextElementSibling).toHaveTextContent('一个极快的 Python 代码检查工具。')
  })

  it('周刊收藏的刊物签是「周刊」，所在期带周次与板块', () => {
    const { container } = show({
      entries: [favoriteEntry({ publication: 'weekly', source_name: '阮一峰科技爱好者周刊', where: { label: '2026年 · 第 36 周 · 工具', href: '/weekly/2026-W36#issue-366-%E5%B7%A5%E5%85%B7' } })],
    })

    expect(container.querySelector('.search-eyebrow')).toHaveTextContent('周刊')
    expect(screen.getByRole('link', { name: /^所在期\s*·\s*2026年\s*·\s*第 36 周\s*·\s*工具$/ })).toHaveAttribute('href', '/weekly/2026-W36#issue-366-%E5%B7%A5%E5%85%B7')
  })

  // 离开再回来时，历史恢复出来的旧列表里可能还带着已经取消的那一行（R-10.7：离开后不再出现）
  it('不在 favorites 里、这一次停留里也没取消过的行不画', () => {
    const { container } = show({ favorites: [] })

    expect(container.querySelectorAll('.search-row')).toHaveLength(0)
  })
})

describe('取消与恢复（R-10.7、AC-10.4）', () => {
  it('取消后那一行原地留下「已取消收藏」与「恢复」，恢复凭取消时拿到的凭据', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(ok({ undo: 'signed-token' }, 200))
      .mockResolvedValueOnce(ok({ url_hash: 'hash-termlog' }))
    vi.stubGlobal('fetch', fetchMock)
    const { container } = show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))

    expect(container.querySelectorAll('.search-row')).toHaveLength(1)
    expect(screen.getByText('已取消收藏')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: `取消收藏：${TITLE}` })).toBeNull()
    const restore = screen.getByRole('button', { name: '恢复' })
    // 焦点跟到换上来的控件，读屏读到的说明是「已取消收藏」
    expect(restore).toHaveFocus()
    expect(restore).toHaveAccessibleDescription('已取消收藏')
    expect(fetchMock.mock.calls[0][0]).toBe('/favorites/hash-termlog')
    expect(fetchMock.mock.calls[0][1].method).toBe('DELETE')
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledWith('favorites', []))

    await userEvent.click(restore)

    const mark = screen.getByRole('button', { name: `取消收藏：${TITLE}` })
    expect(mark).toHaveAttribute('data-on')
    expect(mark).toHaveFocus()
    expect(screen.queryByText('已取消收藏')).toBeNull()
    expect(fetchMock.mock.calls[1][0]).toBe('/favorites')
    expect(fetchMock.mock.calls[1][1].method).toBe('POST')
    expect(fetchMock.mock.calls[1][1].body).toBe(JSON.stringify({ undo: 'signed-token' }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenLastCalledWith('favorites', ['hash-termlog']))
  })

  it('取消没保存上：那一行回到已收藏并提示', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500, json: async () => ({}) }))
    show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))

    expect(await screen.findByText('取消收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toHaveAttribute('data-on')
    expect(screen.queryByText('已取消收藏')).toBeNull()
  })

  it('恢复没保存上：那一行仍是「已取消收藏」，可以再点恢复', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(ok({ undo: 'signed-token' }, 200))
      .mockResolvedValueOnce({ ok: false, status: 500, json: async () => ({}) })
      .mockResolvedValueOnce(ok({ url_hash: 'hash-termlog' }))
    vi.stubGlobal('fetch', fetchMock)
    show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))
    await waitFor(() => expect(router.replaceProp).toHaveBeenCalledTimes(1))
    await userEvent.click(screen.getByRole('button', { name: '恢复' }))

    expect(await screen.findByText('收藏没有保存，请重试。')).toBeInTheDocument()
    expect(screen.getByText('已取消收藏')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: '恢复' }))
    await waitFor(() => expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toBeInTheDocument())
    expect(fetchMock).toHaveBeenCalledTimes(3)
  })

  // 网慢的时候，读者可能在取消的请求回来之前就点了「恢复」：不丢这一下
  it('取消的请求还没回来就点「恢复」：凭据到手后接着恢复', async () => {
    let settle: (value: unknown) => void = () => undefined
    const fetchMock = vi.fn()
      .mockReturnValueOnce(new Promise((resolve) => { settle = resolve }))
      .mockResolvedValueOnce(ok({ url_hash: 'hash-termlog' }))
    vi.stubGlobal('fetch', fetchMock)
    show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))
    await userEvent.click(screen.getByRole('button', { name: '恢复' }))

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(screen.getByText('已取消收藏')).toBeInTheDocument()

    settle(ok({ undo: 'signed-token' }, 200))

    await waitFor(() => expect(screen.getByRole('button', { name: `取消收藏：${TITLE}` })).toBeInTheDocument())
    expect(fetchMock).toHaveBeenCalledTimes(2)
    expect(fetchMock.mock.calls[1][1].body).toBe(JSON.stringify({ undo: 'signed-token' }))
  })

  // 服务端说这条本来就不在了（204，没有凭据）：没什么可恢复的，这一行直接消失
  it('取消时服务端已经没有这条收藏：行消失', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 204, json: async () => ({}) }))
    const { container } = show()

    await userEvent.click(screen.getByRole('button', { name: `取消收藏：${TITLE}` }))

    await waitFor(() => expect(container.querySelectorAll('.search-row')).toHaveLength(0))
  })
})

describe('空态与分页', () => {
  // AC-10.10：一句原因加一个动作（附录 B）
  it('没有收藏：「还没有收藏。」与去最新日刊的链接', () => {
    const { container } = show({ entries: [], favorites: [], pages: 0 })

    expect(container.querySelector('.state-line')).toHaveTextContent('还没有收藏。')
    expect(screen.getByRole('link', { name: '阅读最新日刊' })).toHaveAttribute('href', '/daily/2026-09-08')
    expect(container.querySelectorAll('.search-row')).toHaveLength(0)
    expect(screen.queryByRole('navigation', { name: '分页' })).toBeNull()
  })

  it('一期日刊都没有时链接回首页', () => {
    show({ entries: [], favorites: [], pages: 0, latest_daily_key: null })

    expect(screen.getByRole('link', { name: '阅读最新日刊' })).toHaveAttribute('href', '/')
  })

  it('只有一页时没有分页；多页时地址是 /favorites?page=n，第 1 页不写 page', () => {
    const { unmount } = show()
    expect(screen.queryByRole('navigation', { name: '分页' })).toBeNull()
    unmount()

    show({ page: 2, pages: 3 })
    const pager = within(screen.getByRole('navigation', { name: '分页' }))
    expect(pager.getByRole('link', { name: '上一页' })).toHaveAttribute('href', '/favorites')
    expect(pager.getByRole('link', { name: '下一页' })).toHaveAttribute('href', '/favorites?page=3')
    expect(screen.getByRole('navigation', { name: '分页' })).toHaveTextContent('2 / 3')
  })

  // D28：不显示收藏总数
  it('页面上没有收藏总数', () => {
    const { container } = show()

    expect(container.textContent).not.toMatch(/共\s*\d+\s*条|\d+\s*条收藏/)
  })
})
```

`test/frontend/components/Masthead.test.tsx`：

```diff
--- a/test/frontend/components/Masthead.test.tsx
+++ b/test/frontend/components/Masthead.test.tsx
@@ -75,7 +75,7 @@
     expect(screen.queryByRole('button', { name: '账户' })).toBeNull()
   })
 
-  it('有当前用户时账户位是按钮，点开菜单：邮箱、设置、登出；成员没有管理', async () => {
+  it('有当前用户时账户位是按钮，点开菜单：邮箱、账户信息、收藏、登出；成员没有管理', async () => {
     setPageProps({ current_user: currentUser() })
     render(<Masthead />)
 
@@ -89,6 +89,8 @@
     const menu = screen.getByRole('menu')
     expect(within(menu).getByText('drew@example.com')).toBeInTheDocument()
     expect(within(menu).getByRole('menuitem', { name: '账户信息' })).toHaveAttribute('href', '/settings')
+    // D29：收藏页的唯一入口在头像菜单里，报头其余部分不变（AC-10.12）
+    expect(within(menu).getByRole('menuitem', { name: '收藏' })).toHaveAttribute('href', '/favorites')
     expect(within(menu).queryByRole('menuitem', { name: '管理' })).toBeNull()
     expect(within(menu).getByRole('menuitem', { name: '登出' })).toBeInTheDocument()
   })
@@ -159,7 +161,7 @@
     const menu = screen.getByRole('menu')
 
     expect(menu.querySelector('.menu-head')).toHaveAttribute('role', 'none')
-    expect(within(menu).getAllByRole('menuitem').map((item) => item.textContent)).toEqual(['账户信息', '登出'])
+    expect(within(menu).getAllByRole('menuitem').map((item) => item.textContent)).toEqual(['账户信息', '收藏', '登出'])
   })
 
   it('菜单卡没有阴影（设计 L1）', async () => {
@@ -178,6 +180,8 @@
    const button = screen.getByRole('button', { name: '账户' })
    await userEvent.click(button)
    await userEvent.keyboard('{ArrowDown}')
+   expect(screen.getByRole('menuitem', { name: '收藏' })).toHaveFocus()
+   await userEvent.keyboard('{ArrowDown}')
    expect(screen.getByRole('menuitem', { name: '管理' })).toHaveFocus()
    await userEvent.keyboard('{End}')
    expect(screen.getByRole('menuitem', { name: '登出' })).toHaveFocus()
```

- [ ] **Step 2: 跑测试，确认失败**

```bash
npx vitest run test/frontend/pages/FavoritesIndex.test.tsx test/frontend/components/Masthead.test.tsx
```

预期：`FavoritesIndex.test.tsx` 找不到 `@/pages/Favorites/Index`；`Masthead.test.tsx` 里有 3 条失败（菜单里没有「收藏」）。

- [ ] **Step 3: 收藏页**

`app/frontend/pages/Favorites/Index.tsx`（新建）：

```tsx
import { Link, usePage } from '@inertiajs/react'
import { useEffect, useId, useRef } from 'react'
import type * as React from 'react'

import Chip from '@/components/Chip'
import FavoriteButton from '@/components/FavoriteButton'
import Icon from '@/components/Icon'
import IssueNotice from '@/components/IssueNotice'
import { Translation } from '@/components/ItemRow'
import Layout from '@/components/Layout'
import PageHead from '@/components/PageHead'
import Pager from '@/components/Pager'
import { FavoritesProvider, useFavorites } from '@/lib/favorites'
import { DAILY_LATEST, dailyHref, favoritesHref, latestWeeklyHref } from '@/lib/paths'
import { Mixed, latinLang } from '@/lib/typeset'
import type { FavoriteEntry, FooterData, Publication } from '@/types/lowpass'

// 收藏页（PRD 5.10、R-10.6）：按收藏时间倒序，每页 20 条。行沿用搜索结果行的装置（眉行、标题、片段、底行两个链接），
// 标题不带命中下划线，译文照日刊页的位置（D25），底行右端是书签。不显示总数、不分组、不筛选（D28）。
// 取消后那一行原地留下「已取消收藏」与「恢复」，离开或刷新页面才消失（R-10.7）。文案是附录 B 原句。

export type FavoritesIndexProps = FooterData & {
  entries: FavoriteEntry[]
  favorites: string[]
  page: number
  pages: number
}

const LABELS: Record<Publication, string> = { daily: '日刊', weekly: '周刊' }
const DOT = <span className="search-dot">·</span>

function Row({ entry }: { entry: FavoriteEntry }) {
  const favorites = useFavorites()
  const kept = favorites?.has(entry.url_hash) ?? false
  const removed = favorites?.removed(entry.url_hash) ?? false
  const markRef = useRef<HTMLButtonElement>(null)
  const restoreRef = useRef<HTMLButtonElement>(null)
  const was = useRef(kept)
  const statusId = useId()

  // 取消与恢复会把读者刚按的那个控件换掉：焦点跟到换上来的那个，不掉回 body（PRD 6.4）
  useEffect(() => {
    if (was.current !== kept) (kept ? markRef : restoreRef).current?.focus()
    was.current = kept
  }, [kept])

  // 既不在收藏里、这一次停留里也没取消过：是历史恢复出来的旧列表里已经不在的那一行（R-10.7 离开后不再出现）
  if (!kept && !removed) return null

  return (
    <article className="search-row">
      <div className="search-eyebrow">
        <Chip text={LABELS[entry.publication]} />
        <Mixed text={entry.source_name} font="latin" weight={500} size="var(--fs-13)" color="var(--ink2)" />
        {DOT}
        <Mixed text={entry.where.label} size="var(--fs-13)" color="var(--ink2)" />
      </div>

      <h2 className="search-title">
        <a className="t" href={entry.url} target="_blank" rel="noopener noreferrer" lang={latinLang(entry.title)}>
          <Mixed text={entry.title} font="latin" size="var(--fs-20)" color={kept ? 'var(--ink)' : 'var(--ink2)'} />
        </a>
      </h2>
      {entry.title_zh ? <Translation text={entry.title_zh} /> : null}

      {entry.snippet ? (
        <p className="search-snippet" lang={latinLang(entry.snippet)}>
          <Mixed text={entry.snippet} font="latin" size="var(--fs-15)" color="var(--ink2)" />
        </p>
      ) : null}
      {entry.summary_zh ? <Translation text={entry.summary_zh} /> : null}

      <div className="search-links">
        <Link className="t" href={entry.where.href}>
          <Mixed text={`所在期 · ${entry.where.label}`} size="var(--fs-13)" color="var(--ink)" />
        </Link>
        <a className="search-original" href={entry.url} target="_blank" rel="noopener noreferrer">
          <span>原文</span>
          <Icon name="arrow-up-right" size={12} />
        </a>
        {kept ? (
          <FavoriteButton ref={markRef} className="search-mark" urlHash={entry.url_hash} title={entry.title} />
        ) : (
          <span className="favorite-removed search-mark">
            <span id={statusId}>已取消收藏</span>
            <button ref={restoreRef} type="button" className="link-button" aria-describedby={statusId} onClick={() => favorites?.restore(entry.url_hash)}>
              恢复
            </button>
          </span>
        )}
      </div>
    </article>
  )
}

export default function Index({ entries, favorites, page, pages, latest_daily_key }: FavoritesIndexProps) {
  return (
    <FavoritesProvider favorites={favorites}>
      <PageHead big="收藏" />

      {entries.length === 0 ? (
        <IssueNotice text="还没有收藏。">
          <Link className="ctrl" href={latest_daily_key ? dailyHref(latest_daily_key) : DAILY_LATEST}>
            阅读最新日刊
          </Link>
        </IssueNotice>
      ) : (
        <>
          <div className="search-results">
            {entries.map((entry) => (
              <Row key={entry.url_hash} entry={entry} />
            ))}
          </div>
          {pages > 1 ? (
            <Pager prevHref={page > 1 ? favoritesHref(page - 1) : null} nextHref={page < pages ? favoritesHref(page + 1) : null} page={page} pages={pages} />
          ) : null}
        </>
      )}
    </FavoritesProvider>
  )
}

// 持久布局（application.tsx）：页脚要的字段从 props 来，跟 Search/Show 同一种写法
function FavoritesLayout({ children }: React.PropsWithChildren) {
  const { daily_time, latest_weekly_key } = usePage<FavoritesIndexProps>().props

  return <Layout footer={{ nextAt: daily_time, latestWeeklyHref: latestWeeklyHref(latest_weekly_key) }}>{children}</Layout>
}

Index.layout = (page: React.ReactNode) => <FavoritesLayout>{page}</FavoritesLayout>
```

- [ ] **Step 4: 头像菜单**

`app/frontend/components/Masthead.tsx`：

```diff
--- a/app/frontend/components/Masthead.tsx
+++ b/app/frontend/components/Masthead.tsx
@@ -3,7 +3,7 @@
 import type * as React from 'react'
 
 import Icon from '@/components/Icon'
-import { ADMIN_SOURCES, DAILY_LATEST, SEARCH, SESSION, SETTINGS, latestWeeklyHref } from '@/lib/paths'
+import { ADMIN_SOURCES, DAILY_LATEST, FAVORITES, SEARCH, SESSION, SETTINGS, latestWeeklyHref } from '@/lib/paths'
 import { Mixed } from '@/lib/typeset'
 import type { CurrentUser, SharedProps } from '@/types/lowpass'
 
@@ -41,7 +41,7 @@
 }
 
 // 头像菜单（R-8.2，画布 pages_front3.py 的 menu_sheet()）：32px 圆是按钮，点开右对齐 220px 纸卡，
-// 顶部等宽邮箱（没邮箱用显示名），「设置」「管理」（仅 admin，指向后台的信息源页）「登出」。
+// 顶部等宽邮箱（没邮箱用显示名），「账户信息」「收藏」（收藏页的唯一入口，D29）「管理」（仅 admin，指向后台的信息源页）「登出」。
 // Escape、点卡外、选中任一项都关闭；打开时焦点进第一项。画布那张卡带阴影，这里不取：
 // 设计规则说纸面里不许有阴影，1px 墨线足够分层（设计 L1）。
 function AccountMenu({ user }: { user: CurrentUser }) {
@@ -124,6 +124,9 @@
           <Link role="menuitem" className="menu-item" href={SETTINGS} onClick={close}>
             账户信息
           </Link>
+          <Link role="menuitem" className="menu-item" href={FAVORITES} onClick={close}>
+            收藏
+          </Link>
           {user.admin ? (
             <Link role="menuitem" className="menu-item" href={ADMIN_SOURCES} onClick={close}>
               管理
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
npm run check
npm test
```

预期：`npm run check` 没有错误；`npm test` 是 `Test Files  42 passed`、`Tests  392 passed`。

- [ ] **Step 6: 提交**

```bash
git add app/frontend/pages/Favorites/Index.tsx app/frontend/components/Masthead.tsx test/frontend/pages/FavoritesIndex.test.tsx test/frontend/components/Masthead.test.tsx
git -c commit.gpgsign=false commit -m "收藏页与头像菜单入口" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: 系统测试：在浏览器里走一遍

前面的测试各管一半（控制器测试看不到前端，Vitest 连不到服务端）。这一组在真浏览器里把两半接起来，并把 CSRF 校验打开：fetch 的令牌读错了，书签会回滚，测试就红。

**Files:**
- Test: `test/system/favoriting_test.rb`（新建）

**Interfaces:**
- Consumes: 前七个任务的全部。
- Produces: 4 条系统测试。

- [ ] **Step 1: 写测试**

`test/system/favoriting_test.rb`（新建）：

```ruby
require "application_system_test_case"

# P4 出口：真的在浏览器里收藏一条、从头像菜单进收藏页、取消再恢复（AC-10.1、10.4、10.12）。
# 书签的请求是 fetch 发的：集成测试看不到前端那一半，这里把 CSRF 校验也打开——令牌读错了就是 422，书签会回滚
class FavoritingTest < ApplicationSystemTestCase
  TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  setup do
    sign_in_with_browser(users(:drew))
  end

  test "收藏一条，从头像菜单进收藏页，取消后恢复" do
    with_forgery_protection do
      visit daily_issue_path("2026-09-08")

      find("button[aria-label='收藏：#{TITLE}']").click
      assert_selector "button[aria-label='取消收藏：#{TITLE}'][data-on]"
      wait_until { users(:drew).favorites.count == 1 }

      find("button[aria-label='账户']").click
      within(".menu-card") { click_on "收藏" }

      assert_current_path favorites_path
      assert_selector "h1", text: "收藏"
      assert_selector ".search-row", text: TITLE

      find("button[aria-label='取消收藏：#{TITLE}']").click
      assert_text "已取消收藏"
      wait_until { users(:drew).favorites.count.zero? }

      click_on "恢复"
      assert_no_text "已取消收藏"
      assert_selector "button[aria-label='取消收藏：#{TITLE}'][data-on]"
      wait_until { users(:drew).favorites.count == 1 }

      refresh
      assert_selector ".search-row", text: TITLE
    end
  end

  # R-10.7：收藏页上取消后离开再回来，那一行不再出现；回到所在期，条目是未收藏
  test "取消后刷新，那一行不再出现，所在期里的书签回到未收藏" do
    Favorite.keep(users(:drew), items(:hn_one))
    visit favorites_path

    find("button[aria-label='取消收藏：#{TITLE}']").click
    assert_text "已取消收藏"
    wait_until { users(:drew).favorites.count.zero? }

    refresh
    assert_text "还没有收藏。"

    click_on "阅读最新日刊"
    assert_current_path daily_issue_path("2026-09-08")
    assert_selector "button[aria-label='收藏：#{TITLE}']"
    assert_no_selector "button[aria-label='取消收藏：#{TITLE}']"
  end

  # 离开再按后退：恢复出来的页面与服务端一致（书签的状态写回了 Inertia 当前页）
  test "收藏后离开再后退，书签仍是已收藏" do
    visit daily_issue_path("2026-09-08")

    find("button[aria-label='收藏：#{TITLE}']").click
    wait_until { users(:drew).favorites.count == 1 }

    find("a[aria-label='搜索']").click
    assert_current_path search_path

    page.go_back
    assert_current_path daily_issue_path("2026-09-08")
    assert_selector "button[aria-label='取消收藏：#{TITLE}'][data-on]"
  end

  # AC-10.14：手机宽度下书签仍是 44 见方的目标，页面不横向溢出
  test "手机宽度下书签是 44 见方，页面不横向溢出" do
    page.current_window.resize_to(375, 812)
    visit daily_issue_path("2026-09-08")

    assert_selector ".favorite-button"
    width, height = evaluate_script("(() => { const box = document.querySelector('.favorite-button').getBoundingClientRect(); return [box.width, box.height] })()")
    assert_operator width, :>=, 44
    assert_operator height, :>=, 44
    assert evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private
    def wait_until
      Timeout.timeout(5) { sleep 0.1 until yield }
    end

    # test 环境默认关掉 CSRF 校验（config/environments/test.rb）：打开它，fetch 带的 X-CSRF-Token 才真的被校验
    def with_forgery_protection
      was = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = was
    end
end
```

- [ ] **Step 2: 跑测试**

```bash
env RAILS_ENV=test bin/vite build --mode test
bin/rails test test/system/favoriting_test.rb
```

预期：`4 runs, … 0 failures, 0 errors`。实现已经在了，这一组应当直接通过；哪一条红了，说明前后端没接上——看 `tmp/screenshots/` 里的截图，从那一条断言往回查，不要改断言。连跑三遍都应当是绿的（没有时序上的偶发失败）。

- [ ] **Step 3: 跑全部系统测试**

```bash
bin/rails test:system
bin/rubocop test/system/favoriting_test.rb
```

预期：`21 runs, … 0 failures, 0 errors`（基线 17 加 4）。

- [ ] **Step 4: 提交**

```bash
git add test/system/favoriting_test.rb
git -c commit.gpgsign=false commit -m "系统测试：收藏、从头像菜单进收藏页、取消与恢复" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: 界面字体子集与首屏预算

界面文案多了一个不在文楷界面子集里的字（「藏」），补上；再加一个量首屏的脚本，让「不超过 300 KB」能一条命令核对，并进 `bin/ci`。

**Files:**
- Create: `script/first_screen_size`
- Modify: `config/ci.rb`、`app/frontend/fonts/lxgw-wenkai-screen-ui.woff2`、`app/frontend/fonts/lxgw-wenkai-screen-ui-extra.woff2`、`app/frontend/fonts/lxgw-wenkai-screen-ui-admin.woff2`、`app/frontend/styles/fonts-subset.css`（后四个由 `script/subset_fonts` 生成）

**Interfaces:**
- Consumes: `npm run build` 的产物 `public/vite/.vite/manifest.json`。
- Produces: `script/first_screen_size`——打印首屏各项与合计，合计超过 300 KB 以 1 退出；`bin/ci` 在「Frontend: build」之后多一步「Frontend: first screen budget」。

- [ ] **Step 1: 重跑界面字体子集**

`script/subset_fonts` 要 Python 的 fontTools 与 brotli。装在 `tmp/` 下的虚拟环境里（`tmp/` 不进版本库），用完删掉：

```bash
python3 -m venv tmp/subset-venv
tmp/subset-venv/bin/pip install --quiet fonttools brotli
tmp/subset-venv/bin/python script/subset_fonts --check
```

预期：`子集里缺这些界面字，跑一次 script/subset_fonts：藏`，退出码 1。

```bash
tmp/subset-venv/bin/python script/subset_fonts
tmp/subset-venv/bin/python script/subset_fonts --check
git checkout -- app/frontend/fonts/maple-mono-nl.woff2 app/frontend/fonts/bodoni-moda-brand.woff2
rm -rf tmp/subset-venv
git status --short app/frontend/fonts app/frontend/styles
```

预期：第二次 `--check` 输出 `界面字都在子集里`。Maple 与 Bodoni 两个文件的字符集没变，脚本只是把它们重新压了一遍，所以还原掉。`git status` 里剩下四个文件：三个 `lxgw-wenkai-screen-ui*.woff2` 与 `fonts-subset.css`。`fonts-subset.css` 的改动是：首屏子集多一个 `U+85cf`（藏）；`U+518d`、`U+590d`、`U+6062`、`U+8fd8`（再、复、恢、还）从后台子集挪到读者其余页的子集。

- [ ] **Step 2: 量首屏的脚本**

`script/first_screen_size`（新建）：

```ruby
#!/usr/bin/env ruby
# 首屏资源有多大（PRD N-1：不超过 300 KB）。先 npm run build，再跑这个脚本；超出预算以 1 退出。
#
# 首屏 = 打开 /daily/<周期键> 时浏览器必须下载的东西：
#   - JS：入口 entrypoints/application.tsx、日刊页 pages/Daily/Show.tsx，以及它们静态 import 的分片（按 gzip 后算）
#   - CSS：entrypoints/application.css（按 gzip 后算）
#   - 字体：布局里 preload 的文楷界面子集、Maple Mono 子集、Newsreader 拉丁分片（woff2 本身已压缩，按原大小算）
# 正文与推荐理由里的汉字按需下载的文楷分片不算：那是内容，不是界面。报头的 Bodoni 已经内联进 CSS。
require "json"
require "zlib"

BUILD = File.expand_path("../public/vite", __dir__)
BUDGET_KB = 300
ENTRIES = %w[ entrypoints/application.tsx pages/Daily/Show.tsx ].freeze
STYLES = %w[ entrypoints/application.css ].freeze
FONTS = %w[
  fonts/lxgw-wenkai-screen-ui.woff2
  fonts/maple-mono-nl.woff2
  ../../node_modules/@fontsource-variable/newsreader/files/newsreader-latin-wght-normal.woff2
].freeze

manifest = JSON.parse(File.read(File.join(BUILD, ".vite/manifest.json")))

# 一个入口加上它静态 import 的分片；动态 import（别的页面）不算
collect = lambda do |key, found|
  chunk = manifest.fetch(key)
  unless found.include?(chunk["file"])
    found << chunk["file"]
    chunk.fetch("imports", []).each { |imported| collect.call(imported, found) }
  end
  found
end

gzipped = ->(name) { Zlib.gzip(File.binread(File.join(BUILD, name)), level: Zlib::BEST_COMPRESSION).bytesize }
raw = ->(name) { File.size(File.join(BUILD, name)) }

scripts = ENTRIES.each_with_object([]) { |entry, found| collect.call(entry, found) }.sort
rows = scripts.map { |name| [ "JS #{name}", gzipped.call(name) ] }
rows += STYLES.map { |key| manifest.fetch(key)["file"] }.map { |name| [ "CSS #{name}", gzipped.call(name) ] }
rows += FONTS.map { |key| manifest.fetch(key)["file"] }.map { |name| [ "字体 #{name}", raw.call(name) ] }

rows.each { |label, size| puts format("%8.2f KB  %s", size / 1024.0, label) }
total = rows.sum { |_, size| size } / 1024.0
puts format("%8.2f KB  合计（预算 %d KB）", total, BUDGET_KB)
exit(total <= BUDGET_KB ? 0 : 1)
```

```bash
chmod +x script/first_screen_size
npm run build
script/first_screen_size
```

预期：逐行列出 JS、CSS 与字体，最后一行是 `297.70 KB  合计（预算 300 KB）` 上下（差几十字节正常），退出码 0。超过 300 就停下来：不要为了过线去删功能或改预算，把各项数字报给产品负责人。

- [ ] **Step 3: 进 `bin/ci`**

设计文档的 K14：这一步改了合并门禁。产品负责人没有点头就跳过这一步，只留脚本。

`config/ci.rb`：

```diff
--- a/config/ci.rb
+++ b/config/ci.rb
@@ -11,6 +11,8 @@
   step "Frontend: unit tests", "npm test"
   step "Frontend: audit", "npm audit --audit-level=high"
   step "Frontend: build", "npm run build"
+  # 首屏资源不超过 300 KB（PRD N-1，ADR T1 的守门指标）：读上一步的构建产物，超出就红
+  step "Frontend: first screen budget", "script/first_screen_size"
 
   step "Security: Gem audit", "bin/bundler-audit"
   step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
```

```bash
bin/rubocop script/first_screen_size config/ci.rb
```

预期：`no offenses detected`。

- [ ] **Step 4: 提交**

```bash
git add script/first_screen_size config/ci.rb app/frontend/fonts/lxgw-wenkai-screen-ui.woff2 app/frontend/fonts/lxgw-wenkai-screen-ui-extra.woff2 app/frontend/fonts/lxgw-wenkai-screen-ui-admin.woff2 app/frontend/styles/fonts-subset.css
git -c commit.gpgsign=false commit -m "首屏预算脚本进 bin/ci；界面字体子集补上「藏」" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: 文档同步、八个宽度与全量门禁

**Files:**
- Create: `docs/design/notes/2026-09-30-favorites-acceptance.md`
- Modify: `AGENTS.md`、`docs/engineering-conventions.md`、`docs/development.md`、`.claude/skills/lowpass-design-taste/reference/lowpass-tokens.md`

**Interfaces:**
- Consumes: 前九个任务的结果与数字。
- Produces: 约定与设计令牌里有了收藏；一份验收记录。

- [ ] **Step 1: 约定与开发文档**

`AGENTS.md`（这个文件要保持短：只加一条约定，改一处括注）：

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -28,11 +28,12 @@
 - 出站 HTTP：超时、有限重试、标明 lowpass 的 User-Agent、响应体上限；429 / 403 不追加重试；feed 地址先经 `surfguard` 解析成公网 IP 再连。模型端点（管理员在后台填）与备份存储地址（`BACKUP_BUCKET_URL`，环境配置）是明示例外：可信地址，只要求 https（本机 http 可），不经 surfguard。
 - 后台任务：Solid Queue，浅 job 调富模型（`_later` 入队、`_now` 同步）；周期任务写在 `config/recurring.yml`；job 幂等，某期某源同时只允许一个重抓。
 - 认证：OAuth（OmniAuth）。`Session` 记录 + 签名 cookie；`Current` 承载 session、user 与请求属性；登录回调限流在 OmniAuth 之前的 Rack 中间件，搜索用 `rate_limit` 按用户；`next` 只接受站内相对路径；development 有 `developer` 策略的开发登录。
-- 前端：控制器是 CRUD 资源，每个动作渲染一个 Inertia 页面；props 必须有类型；首屏资源不超过 300 KB；颜色、字体、字号只从设计 skill 的令牌取。
+- 前端：控制器是 CRUD 资源，每个动作渲染一个 Inertia 页面；props 必须有类型；首屏资源不超过 300 KB（`script/first_screen_size`，`bin/ci` 里有一步）；颜色、字体、字号只从设计 skill 的令牌取。
 - 数据库：只支持 PostgreSQL 18，开发容器、CI 与生产同一个大版本，要升一起升。`string` / `text` 列写明 `limit`（值来自 PRD 7.2）并加 CHECK 约束；唯一性放数据库。条目 `content` 上限 50000 字，只给阮一峰周刊正文使用。
 - 测试：Minitest + fixtures；不碰网络，源站样本放 `test/fixtures/files/`；`bin/rails test` 快速循环，`bin/ci` 是合并门禁（rubocop、brakeman、bundler-audit、gitleaks、测试、系统测试）。
 - 环境与部署：mise 钉工具版本；`bin/setup` 幂等；`bin/dev` 起 rails + vite + jobs；密钥只从环境读。`main` 分支用 Kamal 部署（CI 全绿后由 GitHub Actions 自动跑 `kamal deploy`）：起步 `web` 单容器（Solid Queue 作 Puma 插件，ADR T4 的 A）加 PostgreSQL 18 accessory，拆 `job` 角色是 `config/deploy.yml` 里的配置级变更；新增常驻进程先改 ADR 里的内存预算；队列面板 `mission_control-jobs` 挂在 `/admin/jobs`。主库每天 03:00 加密备份到 S3 兼容存储（`BACKUP_*`，恢复与演练见 `docs/development.md`「备份」），`/health` 给外部拨测，`/up` 只给 kamal-proxy。
 - 推荐理由：模型接入只认 OpenAI 兼容协议，地址 / 模型名 / 单价 / 上限在后台，密钥只从环境读；生成与发布解耦，一期一个 job。译文（D25：HN 与 RSS 源译标题，GitHub Trending 译简介）搭同一次调用，不合规只当没有，「缺理由」只看理由。
+- 收藏：按 `url_hash` 认，一人一链接一条，收藏时抄快照、不引用条目行（重抓会换掉条目 id）；取消是真删，恢复靠一天有效的签名凭据；只有本人可见，不进后台与审计。书签的两个动作是 fetch + JSON，资源的键是 `url_hash`。
 
 ## 不要做
 
```

`docs/engineering-conventions.md`：

```diff
--- a/docs/engineering-conventions.md
+++ b/docs/engineering-conventions.md
@@ -64,6 +64,19 @@
 停用源的历史条目保留可搜（R-4.8）。
 不要为了搜索改条目表本身。〔改造自 fizzy `app/models/concerns/searchable.rb` 与 `app/models/search/`〕
 
+## 收藏
+
+留存夹，不是稍后读队列（PRD 5.10、D26）。设计见 `docs/superpowers/specs/2026-09-30-favorites-design.md`。
+
+- 一条收藏按链接的 `url_hash` 认，`(user_id, url_hash)` 唯一（D27）。收藏时把条目抄成快照，**不引用条目行**：管理员重抓是整栏先删后插，
+  条目 id 全换。收藏页渲染时按（刊物、周期键、来源、`url_hash`）现查条目还在不在（`Favorite.live_items`），在就用它现在的译文与条目锚点。
+- 取消是真删，服务端不留「已取消」的行。删的同时回一张签名凭据（`Favorite::Undoing`，`MessageVerifier`，一天有效，只认本人），
+  收藏页的「恢复」凭它把同一条原样插回去；凭据参数 `undo` 在 `filter_parameters` 里，不进请求日志。
+- 书签的两个动作（`POST /favorites`、`DELETE /favorites/:url_hash`）是 fetch + JSON，不是 Inertia 访问；未登录回 401 而不是 302。
+  页面 props 里每个条目带 `url_hash`，页面级的 `favorites` 是这一页里已收藏的 `url_hash` 列表；前端的状态、回滚与提示都在
+  `lib/favorites.tsx` 的 `FavoritesProvider` 里，成功后用 `router.replaceProp` 写回 Inertia 当前页。
+- 只有本人可见：读写都从 `Current.user.favorites` 进来，后台、审计日志、错误上报里都没有收藏；用户删除时外键级联。
+
 ## 抓取与出站 HTTP
 
 - 适配器放在模型层（`app/models/<source>/…`），输出 7.2 契约的规范化条目；网络 I/O 与解析分开，解析可以拿固定样本单测。
@@ -121,7 +134,7 @@
 
 Inertia + React + TypeScript + shadcn/ui（ADR T1、T6），不是 fizzy 的 Hotwire / importmap。〔不采用其前端〕
 仍然适用的：控制器是 CRUD 资源、动作只做一件事并渲染一个 Inertia 页面；props 是前后端唯一契约，必须有类型；
-首屏资源不超过 300 KB（N-1）；颜色、字体、字号只从设计 skill 的令牌取。字体是首屏的大头：霞鹜文楷的 npm 包按字频切成 97 片，界面固定文案的字另外按读者首屏、读者其余页、后台合成三个小子集（`script/subset_fonts` 生成字体与 `app/frontend/styles/fonts-subset.css`，声明在包之后，unicode-range 重叠时先用子集），Maple Mono 与 Bodoni 也只留用得到的字形。界面文案新加了汉字就重跑一次（`--check` 列出没收进来的字）；漏收不会缺字，只是回落到包的分片、首屏多下载一片。
+首屏资源不超过 300 KB（N-1，`script/first_screen_size` 读生产构建的清单来量，`bin/ci` 里有一步守着）；颜色、字体、字号只从设计 skill 的令牌取。字体是首屏的大头：霞鹜文楷的 npm 包按字频切成 97 片，界面固定文案的字另外按读者首屏、读者其余页、后台合成三个小子集（`script/subset_fonts` 生成字体与 `app/frontend/styles/fonts-subset.css`，声明在包之后，unicode-range 重叠时先用子集），Maple Mono 与 Bodoni 也只留用得到的字形。界面文案新加了汉字就重跑一次（`--check` 列出没收进来的字）；漏收不会缺字，只是回落到包的分片、首屏多下载一片。
 
 ## 数据库与迁移
 
@@ -135,7 +148,7 @@
 
 - Minitest + fixtures（`fixtures :all`，并行 worker），`bin/rails test` 做快速循环。〔采用〕
 - `bin/ci` 是完整门禁，用 `ActiveSupport::ContinuousIntegration` 按 `config/ci.rb` 依次跑：setup、rubocop（rubocop-rails-omakase）、
-  前端类型检查、前端单元测试、前端依赖审计、前端构建、bundler-audit、brakeman、gitleaks、test 模式的 Vite 构建、Rails 测试、
+  前端类型检查、前端单元测试、前端依赖审计、前端构建、首屏预算、bundler-audit、brakeman、gitleaks、test 模式的 Vite 构建、Rails 测试、
   系统测试、种子数据（`db:seed:replant`）。全绿才能合并与部署；每步的命令见 `docs/development.md`「测试与 CI」。〔采用〕
 - 测试辅助放 `test/test_helpers/`，例如 `sign_in_as`；时间敏感的测试用 `travel_to` 卡在 05:59 / 06:00 / 06:20 边界；不碰网络。
 - 前端单元测试（Vitest + Testing Library，jsdom）里，`getByRole` 的 `name` 落在 `Mixed` / `HitText` 拆出的多段 `<span>` 上时
```

`docs/development.md`：

````diff
--- a/docs/development.md
+++ b/docs/development.md
@@ -350,8 +350,8 @@
 ```
 bin/rails test          # 快速循环，不连网络
 npm test                # 前端单元测试（Vitest，jsdom），npm run test:watch 是监视模式
-bin/rails test:system   # 无头 Chrome 里读一期日刊、搜一条并回到所在期、走一遍登录与登出
-                         # （test/system/reading_test.rb、searching_test.rb、signing_in_test.rb）
+bin/rails test:system   # 无头 Chrome 里读一期日刊、搜一条并回到所在期、走一遍登录与登出、收藏一条再取消与恢复
+                         # （test/system/reading_test.rb、searching_test.rb、signing_in_test.rb、favoriting_test.rb）
 bin/ci                  # 合并门禁，见 config/ci.rb
 ```
 
@@ -373,7 +373,8 @@
 
 `bin/ci` 依次跑：Setup（`bin/setup --skip-server`）、Style: Ruby（`bin/rubocop`）、Frontend: typecheck
 （`npm run check`）、Frontend: unit tests（`npm test`）、Frontend: audit（`npm audit --audit-level=high`）、
-Frontend: build（`npm run build`）、Security: Gem audit（`bin/bundler-audit`）、
+Frontend: build（`npm run build`）、Frontend: first screen budget（`script/first_screen_size`：读上一步的构建产物，
+日刊页首屏的 JS、CSS 与界面字体合计超过 300 KB 就失败，PRD N-1）、Security: Gem audit（`bin/bundler-audit`）、
 Security: Brakeman code analysis、Security: Secrets
 （`gitleaks detect --source . --no-banner --redact`，规则继承自 gitleaks 内置集，豁免的误报与理由见
 仓库根目录的 `.gitleaks.toml`）、Frontend: build for tests（`env RAILS_ENV=test bin/vite build --mode
````

`.claude/skills/lowpass-design-taste/reference/lowpass-tokens.md`（加在文件末尾）：

```diff
--- a/.claude/skills/lowpass-design-taste/reference/lowpass-tokens.md
+++ b/.claude/skills/lowpass-design-taste/reference/lowpass-tokens.md
@@ -88,3 +88,11 @@
 - 手机后台优先显示身份、状态、常用操作；次要字段收进原生详情，兴趣画像默认摘要、明确进入编辑。
 - 桌面和手机的加载进度使用纸/墨双色线，在任何底色上都可见；减少动态偏好禁用图标变形与过渡。
 - 历史详情、搜索结果和文档标题显示年份；有明确年份的归档行仍保留简短标签。
+
+## 2026-09-30 收藏的书签（已批准，界面稿 `docs/design/notes/2026-09-30-favorites-mock.html`）
+
+- 书签 `favorite-button`：Lucide `bookmark`，18px 图标居中在 44 × 44 的目标里；未收藏是次墨描线，已收藏是墨色实心（同一个图形填墨），悬停转墨色。两态靠形状分，不靠颜色；没有新颜色、没有圆角。不用 ★（元数据行里是 star 数）与 ♥。
+- 位置：条目行末另占一列（手机上与序号同一行、靠右）；搜索结果与收藏页的行里在底行右端。图标右缘与正文右缘、分页按钮对齐（按钮右边距收回 13px）。
+- 收藏页：期头「收藏」文楷 56，行沿用搜索结果行；取消后标题转次墨，底行右端是「已取消收藏」（文楷 13 次墨）加「恢复」（link-button）。空态沿用期级状态那一句加一个描边按钮。
+- 入口只在头像菜单里（第二项「收藏」），报头不加东西（PRD D29）。
+
```

没做 Task 9 的 Step 3（K14 未获批准）的话，上面几份文档里说它在 `bin/ci` 里的那几处，改成只说有这个脚本。

- [ ] **Step 2: 全量门禁**

```bash
bin/ci
```

预期：每一步都是绿的。关键数字：Rails 测试 757、前端单元测试 392、系统测试 21、首屏 297.70 KB 上下。

- [ ] **Step 3: 八个宽度（AC-10.14）**

在真实页面上量，不是界面稿。开发库里要有一期日刊与一期周刊：

```bash
ruby script/seed_sample_issue
ruby script/seed_sample_weekly
bin/rails server -p 3000
```

浏览器打开 `http://localhost:3000/`，用登录页的「开发登录」进去（随便填一个显示名与邮箱），在日刊页点两三颗书签。然后在这个页面的控制台里跑下面这段（它用同源的 iframe 把四个页面各按八个宽度装一遍）：

```js
const widths = [320, 375, 390, 481, 600, 768, 1024, 1440]
const weekly = document.querySelector('.masthead-nav a[href^="/weekly"]').getAttribute('href')
const pages = [location.pathname, weekly, '/search?q=rust', '/favorites']
const measure = (url, width) => new Promise((resolve) => {
  const frame = document.createElement('iframe')
  frame.style.cssText = `position:fixed;left:-5000px;top:0;width:${width}px;height:900px;border:0`
  frame.src = url
  frame.onload = async () => {
    const doc = frame.contentDocument
    for (let i = 0; i < 40 && !doc.querySelector('.favorite-button, .state-line, .search-row'); i++) await new Promise((r) => setTimeout(r, 100))
    await new Promise((r) => setTimeout(r, 300))
    const rects = [...doc.querySelectorAll('.favorite-button')].map((e) => e.getBoundingClientRect())
    const result = { url, width, overflow: doc.documentElement.scrollWidth > width, marks: rects.length, min: rects.length ? Math.min(...rects.map((r) => Math.min(r.width, r.height))) : null }
    frame.remove()
    resolve(result)
  }
  document.body.appendChild(frame)
})
const out = []
for (const url of pages) for (const width of widths) out.push(await measure(url, width))
console.table(out)
console.log(out.every((row) => !row.overflow && row.marks > 0 && row.min >= 44) ? '32 组全部通过' : '有不通过的组')
```

预期：32 行，每一行 `overflow` 是 `false`、`marks` 大于 0、`min` 是 44；最后一行输出 `32 组全部通过`。（样本数据里搜 `rust` 有结果；没有结果就换一个搜得到的词。）

再用键盘走一遍：在日刊页按 Tab，焦点依次到标题、评论、书签，书签上有 2px 墨色焦点框，按回车或空格能切换；在收藏页取消一条后焦点在「恢复」上。

看完把服务停掉。

- [ ] **Step 4: 验收记录**

`docs/design/notes/2026-09-30-favorites-acceptance.md`（新建。里面的数字是计划写成时在临时拷贝里量到的：逐个对一遍 Step 2 与 Step 3 实际看到的，不一样的改成实际值）：

```markdown
# 收藏（P4）验收记录

依据：PRD 5.10 的 AC-10.1 至 AC-10.14、10.1 的 P4 行、10.2 的 P4 退出清单；设计 `docs/superpowers/specs/2026-09-30-favorites-design.md`；界面稿 `docs/design/notes/2026-09-30-favorites-mock.html`。

## 逐条验收

| 验收标准 | 由什么验 |
|---|---|
| AC-10.1 点一下即收藏，不刷新、不出提示，收藏页第一条是它 | 系统测试「收藏一条，从头像菜单进收藏页，取消后恢复」；`favorites_controller_test.rb`「POST 收藏一条条目」；`FavoriteButton.test.tsx`「点一下收藏」 |
| AC-10.2 同一链接在另一期、在搜索里都显示已收藏，收藏页只有一条 | `favorite_test.rb`「同一链接只有一条」；`daily_issues_controller_test.rb`「同一链接在另一期也算已收藏」；`searches_controller_test.rb`「结果带 url_hash」 |
| AC-10.3 重抓后收藏仍在，标题、来源、所在期、原文都在 | `favorite_test.rb`「重抓换掉条目行，收藏还在」；`favorites_controller_test.rb`「条目被重抓换掉后，收藏行用快照」 |
| AC-10.4 取消后原地留「已取消收藏」与「恢复」，恢复并刷新后仍在原位 | 系统测试第 1 条；`favorites_controller_test.rb`「DELETE 取消并给回恢复凭据」；`FavoritesIndex.test.tsx`「取消后那一行原地留下」 |
| AC-10.5 取消后刷新不再出现，所在期里是未收藏 | 系统测试「取消后刷新，那一行不再出现」 |
| AC-10.6 别人看不到，后台没有任何收藏信息 | `favorites_controller_test.rb`「别人的收藏看不到」；`admin/users_controller_test.rb`「用户列表不带收藏信息」 |
| AC-10.7 未登录访问收藏页跳登录并带 next | `favorites_controller_test.rb`「未登录」 |
| AC-10.8 周刊收藏的所在期落到板块锚点 | `favorites_controller_test.rb`「周刊收藏的所在期落到板块锚点」 |
| AC-10.9 保存失败回滚并提示 | `FavoriteButton.test.tsx`「收藏没保存上」「断网」「取消没保存上」 |
| AC-10.10 空态 | `favorites_controller_test.rb`「没有收藏」；`FavoritesIndex.test.tsx`「没有收藏」 |
| AC-10.11 限流 | `favorites_controller_test.rb`「一分钟 60 次以上回 429」；`FavoriteButton.test.tsx`「限流 429」 |
| AC-10.12 头像菜单有「收藏」，报头其余不变 | `Masthead.test.tsx`；系统测试第 1 条 |
| AC-10.13 下架联动 | `favorite_test.rb`「listed 不含链接被下架的收藏」；`favorites_controller_test.rb`「被下架的条目不出现」 |
| AC-10.14 八个宽度、44 × 44、键盘与读屏 | 系统测试「手机宽度下书签是 44 见方」；下面的「八个宽度」；`FavoritesIndex.test.tsx` 的焦点与可读名称断言 |

10.2 的 P4 退出清单：修订后收藏仍在、两个用户互不可见、下架联动三项都有自动化测试（见上表 AC-10.3、10.6、10.13）。

## 测试与门禁

`bin/ci` 全部通过。各步的数字：

| 项 | 改动前 | 改动后 |
|---|---|---|
| Rails 测试（`bin/rails test`） | 714 | 757 |
| 前端单元测试（`npm test`） | 356 | 392 |
| 系统测试（`bin/rails test:system`） | 17 | 21 |
| rubocop、brakeman、类型检查 | 无告警 | 无告警 |

## 首屏

`npm run build && script/first_screen_size`：改动前 295.14 KB，改动后 297.70 KB，预算 300 KB。多出来的是书签与它的状态管理（JS 与 CSS 2.10 KB）和界面字体子集里的一个「藏」字（0.46 KB）。

## 八个宽度

日刊、周刊、搜索、收藏四个页面，320、375、390、481、600、768、1024、1440px 八个宽度，共 32 组：页面都不横向溢出，书签的触控目标都是 44 × 44。做法见实现计划 Task 10 的第 3 步。

## 复盘

上线满 4 周那天按 PRD 9.3 的三档决定后续（D32）。上线日期：（合并部署后由产品负责人补上）。
```

- [ ] **Step 5: 提交**

```bash
git add AGENTS.md docs/engineering-conventions.md docs/development.md .claude/skills/lowpass-design-taste/reference/lowpass-tokens.md docs/design/notes/2026-09-30-favorites-acceptance.md
git -c commit.gpgsign=false commit -m "文档：收藏的约定、书签的设计令牌与验收记录" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## 需求覆盖对照

| PRD | 落在哪个任务 |
|---|---|
| R-10.1 登录用户可收藏，互不可见 | Task 2（`user.favorites`）、Task 3（只经 `Current.user.favorites`） |
| R-10.2 收藏的是链接 | Task 2（唯一索引、`keep`）、Task 4（`favorite_hashes` 按 `url_hash`） |
| R-10.3 快照 | Task 2（`snapshot_of`、不引用条目行） |
| R-10.4 能收藏的位置 | Task 6（条目行、搜索结果行）、Task 7（收藏页上取消与恢复） |
| R-10.5 操作与反馈 | Task 5（乐观更新、回滚、提示）、Task 3（重复提交不报错） |
| R-10.6 收藏页 | Task 3（props、分页）、Task 7（页面） |
| R-10.7 取消后可恢复 | Task 2（凭据）、Task 3（`undo`）、Task 5 与 Task 7（行内状态、焦点） |
| R-10.8 私有 | Task 2（参数过滤）、Task 3、Task 4（后台用户页的测试） |
| R-10.9 下架 | Task 2（`listed`）、Task 3 |
| R-10.10 限流与上限 | Task 3（`rate_limit`）、Task 5（限流提示） |
| R-10.11 注销 | Task 2（外键级联、`dependent: :delete_all`） |
| R-10.12 不改期 | Task 2（独立的表，不碰 `items` 与搜索索引） |
| R-10.13 性能 | Task 4（每页多一条查询）、Task 9（首屏预算） |
| D29 入口在头像菜单 | Task 7 |
| D30 书签记号与反馈 | Task 5（样式、两态）、界面稿 |
| AC-10.1 至 AC-10.14 | 逐条对照见 Task 10 的验收记录 |
