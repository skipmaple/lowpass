# P1 搜索 设计文档

| 状态 | 日期 | 依据 |
|---|---|---|
| 产品负责人已批准方案与分节设计（2026-09-11），待审阅本文 | 2026-09-11 | PRD v0.3.7 第 5.4 节（F-14 到 F-17、R-4.1 到 R-4.11、AC-4.1 到 AC-4.7）、6.2 搜索页、9.1 埋点、D12、D21、D22；ADR-0001 T7；AGENTS.md 与 `docs/engineering-conventions.md` 的搜索约定；设计画布 `docs/design/src/pages_site.py` 的 `search`、`search_states`、`filters`、`search_row`、`pager` |

需求本身以 PRD 5.4 为准，本文只写实现设计：数据怎么放、查询怎么算、页面怎么组、怎么验。

## 1. 范围

做：关键词模糊搜索（英文前缀与拼写容错、中文免分词）、刊物 / 来源 / 日期筛选、命中高亮与摘要片段、所在期与原文链接、分页、相关度或时间排序（F-17）、限流、不可用态、搜索日志与两个埋点事件（search_submit、search_click）、验收脚本。

不做：引号短语精确匹配（PRD 标为后续）、搜索建议与历史（F-18，P2）、登录门禁（R-4.11 随 P2 的账号一起生效；P1 与 P0 一样不带登录）、告警渠道（P2，本阶段只 `Rails.error.report`）、下架条目的管理界面（F-29 的界面在 P2；索引层先支持 `hidden`）。

## 2. 决策

- 方案 A：PostgreSQL 内建，`pg_trgm` 做拉丁前缀与拼写容错，`ILIKE` 做中文子串，打分在 SQL 里求和后由数据库排序分页；高亮在应用层。与 ADR T7 的措辞差一点：ADR 写「应用层做权重」，本设计把权重求和放进 SQL，因为分页必须在数据库里按分数排序，否则第 2 页起结果不正确。ADR 在实现计划合并时补一句。
- 不引入 tsvector / 词干、不引入搜索引擎、不引入 `zhparser` 之类的分词扩展。
- 启用扩展只有 `pg_trgm`（PostgreSQL 自带的 contrib，16 与 17 都有）。`unaccent` 不启用：源站内容里的重音字母极少，PRD 没要求。

## 3. 数据模型

### 3.1 `search_records`（`Search::Record`，独立于 `items`）

| 列 | 类型 | 说明 |
|---|---|---|
| id | string(25) | UUIDv7 base36，同全站 |
| item_id | string(25) | 唯一；外键 `items(id)` `on_delete: :cascade`，装订整栏替换时旧条目一删，索引行随之消失 |
| issue_id | string(25) | 外键 `issues(id)` 级联删除；查询时联 `issues` 取 `state = 'published'` |
| source_id | string(25) | 外键 `sources(id)`；来源筛选与来源标签 |
| publication | string(10) | `daily` / `weekly`，CHECK 约束；刊物筛选与刊物标签 |
| period_key | string(10) | 所在期链接 |
| published_on | date | 日期筛选依据：日刊取期日期（`PeriodKey.date_of`），周刊取条目 `published_at` 的上海日期，没有则取该周周一 |
| title | string(300) | 条目标题 |
| section | string(100) | 板块名，可空 |
| source_name | string(100) | 来源名快照（源改名不影响历史索引） |
| summary | string(500) | 已清洗的摘要，可空 |
| anchor | string(120) | 周刊板块锚点 slug，可空（见 6.3） |
| created_at / updated_at | datetime | |

索引：`title`、`section`、`source_name`、`summary` 各一个 `gin (col gin_trgm_ops)`；`item_id` 唯一；`(publication, published_on)`；`source_id`；`issue_id`。

### 3.2 `search_logs`（`Search::Log`，D12）

`query`（string 100，明文）、`filters`（jsonb：type、source、from、to、sort）、`result_count`（integer）、`latency_ms`（integer）、`page`（integer）、`created_at`。不存用户、不存 IP。保留 30 天，`Search::Log.cleanup` 并入 `Scheduler#cleanup_if_due`。

### 3.3 `search_clicks`（`Search::Click`，9.1 的 search_click）

`query`（string 100，查询词快照，不设外键以便日志先过期）、`rank`（integer，结果序号，从 1 起）、`item_id`（string 25，外键 `items` 级联删除）、`created_at`。保留 90 天（9.1 埋点保留期），同一处清理。

## 4. 索引维护（R-4.8）

- `Item` 加 `Searchable` concern：`after_create_commit` / `after_update_commit` → `Search::Record.index!(item)`（upsert；`hidden` 为真则删行）；`after_destroy_commit` 由外键级联兜底，不再显式处理。
- 装订与整栏替换走 `insert_all!`，不触发回调：`Issue::Sections#replace_section!` 与 `#append_section!` 在插入后调用 `Search::Record.index_items!(ids)` 批量 upsert（一条 `insert_all` 带 `unique_by: :item_id`）。这是索引能在「期发布或修订后 1 分钟内可搜」的关键路径，测试必须覆盖。
- 生成中的期：索引行在条目写入时就存在，但查询只联 `issues.state = 'published'`（空刊无条目，无影响）。
- 停用源的历史条目仍在索引（不按 `sources.enabled` 过滤）。
- `Search::Record.rebuild!`：清空后按 `Item.visible.find_in_batches` 重建；提供 `bin/rails search:rebuild` 与 `Search::RebuildJob`（后台重建入口留给 P2 管理页）。
- 索引列保存的是搜索副本：清洗后的标题、板块、来源名、摘要再做 NFKC 归一化（全角字母数字转半角），展示仍用 `items` 原文；查询侧同样归一化（见 5.1），比较靠 `ILIKE` 与 `word_similarity` 的大小写不敏感。高亮在原文上做，原文含全角字母的极少数情况不高亮（接受）。

## 5. 查询

### 5.1 解析 `Search::Query.parse(params)`

1. `q` 去首尾空白，NFKC 归一化（全角字母数字标点转半角），最长 100 字符，超长截断并置 `truncated: true`，页面提示「已截断到 100 字」（附录 B 没有这句，实现计划里把它加进附录 B）。
2. 标点替换为空格（Unicode 标点类），按空白切分为片段。
3. 每个片段按脚本拆词：连续拉丁字母 / 数字为一个拉丁词（小写）；连续 CJK 字符为一个中文串，再拆为二元组（长度 1 的串本身即一个词）；混合片段（`Rust语言`）拆成 `rust` 与 `语言`。
4. 长度门槛（R-4.1）：拉丁词至少 2 个字符，中文词至少 1 个字符，不达标的丢弃；全部丢弃或原始 `q` 为空 → `blank?` 为真，不搜索。
5. 词去重，最多保留 8 个词（防止超长查询把 SQL 撑爆；超出部分丢弃，不提示）。
6. 筛选：`type` ∈ {daily, weekly} 否则忽略；`source` 逗号分隔的源 id，只保留库里存在的；`from` / `to` 为 `YYYY-MM-DD` 且合法日期，`from > to` 则互换；预设 `range` ∈ {7d, 30d, all, custom} 只是页面便利，服务端只认 `from` / `to`；`page` 1 到 50，其余当 1；`sort` ∈ {relevance, date}，默认 relevance。
7. 返回值是不可变的 `Search::Query`（terms、filters、page、sort、blank?、truncated?）。

### 5.2 匹配规则

- 拉丁词：长度 2 到 4 → 前缀或整词匹配（`col ~* '\m' || term`，词首边界）；长度 5 到 8 → `word_similarity(term, col) >= 0.55`（允许约 1 个错）；长度 ≥ 9 → `>= 0.45`（允许约 2 个错）。阈值是起点，验收脚本跑 50 条真实查询后可调；`kuber` 命中 `Kubernetes`（AC-4.1）靠 5 字符档的 `word_similarity`（`kuber` 对 `kubernetes` 约 0.8，远高于 0.55；精确值在实现时用真实数据库核对）。
- 中文词（二元组或单字）：`col ILIKE '%term%'`，`term` 经 `ILIKE` 转义。
- 每个词对四列分别判定；词命中 = 任一列命中。

### 5.3 打分与排序（R-4.2、R-4.3）

单条 SQL，`FROM search_records r JOIN issues i ON i.id = r.issue_id AND i.state = 'published'`，`WHERE` 为筛选条件 AND（至少一个词命中）：

```
score = Σ_term ( 4 × hit(title) + 2 × hit(section) + 2 × hit(source_name) + 1 × hit(summary) )
hits  = Σ_term ( hit(any column) )
```

`ORDER BY (hits = 词数) DESC, score DESC, published_on DESC, item_id`（`sort=date` 时 `published_on DESC, score DESC`）。`hit()` 是 `CASE WHEN … THEN 1 ELSE 0 END`，用 Arel 拼接、词值全部绑定参数。全半角：查询已归一为半角；索引文本里的全角标点对拉丁词无影响（词内不含标点），对中文子串匹配也无影响（中文词本身不含标点）。

`LIMIT 20 OFFSET (page-1)*20`，另一条 `COUNT(*)` 取总数（上限按 50 页截断显示）。两条语句都在 `SET LOCAL statement_timeout = '500ms'` 的事务里跑。

### 5.4 执行 `Search::Runner.call(query)`

返回 `Search::Result`：`entries`（每条含记录、分数、名次）、`total`、`page`、`pages`（≤ 50）、`latency_ms`、`status`（ok / timeout / error）。`ActiveRecord::QueryCanceled`（超时）与 `ActiveRecord::ConnectionNotEstablished` / `PG::ConnectionBad` 归为「不可用」，`Rails.error.report(e, handled: true)`，页面显示附录 B 的「搜索暂不可用，请稍后重试。」；其他异常照常抛出。

### 5.5 高亮与片段 `Search::Highlighter`

- 输入：一段文本与词表；输出：`[{ text, hit }]` 的 run 序列（前端按 run 渲染 2px 下划线，D22）。
- 命中判定与 5.2 一致但在 Ruby 里做：拉丁词用词首不区分大小写的前缀匹配（拼写容错命中的词只标出前缀相同的部分；拼错的整词不标，接受这一简化）；中文词按子串。
- 标题整段高亮；摘要片段：找第一个命中的位置，向前留约 40 个字符、总长不超过 160 个字符，两端不在词中间截断（拉丁按空格回退），截断处加「…」；没有命中则取前 160 字。
- 片段来源是 `summary`，为空则不显示片段行。

## 6. 页面与路由

### 6.1 路由与控制器

- `GET /search` → `SearchesController#show`，Inertia 页 `Search/Show`。参数即 R-4.5：`q`、`type`、`source`、`from`、`to`、`page`、`sort`，外加页面便利参数 `range`。
- `POST /search/clicks` → `Search::ClicksController#create`：参数 `item_id`、`rank`、`q`，写 `search_clicks`，返回 204；前端点击标题或原文时先 `fetch(keepalive)` 再跳转（不是重定向端点，避免开放跳转）。
- `rate_limit to: 60, within: 1.minute, by: -> { request.remote_ip }, with: -> { render_limited }`（P2 改为用户 id）；限流时不写搜索日志，页面显示附录 B 的「操作过于频繁，请稍后再试。」，HTTP 429。
- 报头的搜索图标改为真链接 `/search`（Task 17 的占位 span 变回 `Link`），D21。

### 6.2 页面 `Search/Show`（按画布）

期头：查询词文楷 32 + 反白「搜索」按钮（表单 GET，回车提交）；筛选栏三组：刊物分段（全部 / 日刊 / 周刊）、来源描边小签多选（所有源含停用）、日期分段（近 7 天 / 近 30 天 / 全部 / 自定义，自定义显示两个 40px 描边日期框）；结果计数「N 条结果」（PRD 明确要求的计数，允许）；结果行：刊物反白签、来源名、所在期、日期、标题（命中下划线）、片段（命中下划线）、「所在期 · …」与「原文 ↗」；分页「上一页 · n / m · 下一页」。排序切换放在结果计数同一行右侧（相关度 / 时间，分段控件）。

六态：未搜索（占位句「搜标题、摘要或来源。拼写不准也可以。」+ 最新日刊入口）；有结果；无结果（附录 B 原句 + 「清除筛选」按钮，清除筛选只保留 `q`）；限流；不可用；加载中由 Inertia 进度条表达。

props：`{ q, truncated, filters: { type, sources: string[], from, to, range, sort }, source_options: [{ id, name, enabled }], state: "initial" | "results" | "empty" | "limited" | "unavailable", results: [{ item_id, rank, publication, source_name, where: { label, href }, published_label, url, title_runs, snippet_runs }], total, page, pages, latest_daily_key }`。类型进 `types/lowpass.ts`。

### 6.3 所在期链接

- 日刊：`/daily/<period_key>?source=<source_id>#item-<item_id>`。日刊页给每个条目行加 `id="item-<item_id>"`，页面挂载后若有 hash 且该条目属于当前来源则滚动到它（`?source=` 已能切换来源）。
- 周刊：`/weekly/<period_key>#<anchor>`。周刊页的板块锚点从位置编号改为稳定 slug：阮一峰取条目 `meta.anchor`（Task 11 已生成的板块 slug），RSS 源用 `source-<source_id>`；`Search::Record.anchor` 在索引时算好同一个值。锚点稳定后，P0 遗留的「位置锚点」问题一并了结。
- 所在期标签文案：日刊「9月8日」，周刊「第 36 周 · 科技动态」（板块名可空则只写周次），文楷。

## 7. 日志与埋点

- 每次实际执行的搜索（非空查询、未限流）写一行 `search_logs`（含 `result_count`、`latency_ms`、`page`）；不可用态也记，`result_count` 为空。
- 点击标题或原文 → `search_clicks`；所在期直链不计。
- 有结果率 = `result_count > 0` 的占比，点击率 = 有点击的搜索占比；两者由 `script/search_eval` 与后台（P2）读取。

## 8. 性能（R-4.10）

- 目标 p95 < 500 ms。3 万条每年、四个 trigram GIN 索引，`word_similarity` 与 `ILIKE '%xx%'` 在 GIN 上都能走索引（`%xx%` 对 2 字中文子串会退化为顺扫，3 万行量级仍在预算内）。
- `statement_timeout` 500 ms 兜底，超时归不可用态而不是 500。
- `script/search_eval` 输出 p50 / p95 与有结果率。

## 9. 测试

- `test/models/search/query_test.rb`：长度门槛、截断、全半角归一、标点、拉丁 / 中文拆词、二元组、去重与 8 词上限、筛选参数合法性、`from > to` 互换、page 与 sort 兜底。
- `test/models/search/runner_test.rb`：AC-4.1（`kuber rust` 命中 "Kubernetes operator in Rust"）、AC-4.2（"终端工具" 与 "终端 日志" 都命中 "一个终端下的日志工具"）、权重与全命中优先、同分按时间倒序、`sort=date`、AC-4.3 的筛选组合与日期含首尾、来源 OR、分页与 50 页上限、只搜已发布期、停用源可搜、`hidden` 不可搜、超时归不可用态（用 `statement_timeout` 极小值触发）。
- `test/models/search/highlighter_test.rb`：run 划分、大小写、中文子串、片段 160 字与首个命中、无命中片段。
- `test/models/search/record_test.rb`：回调 upsert、`hidden` 删行、`index_items!` 批量、级联删除、`rebuild!`、`published_on` 取值、`anchor` 取值。
- `test/controllers/searches_controller_test.rb`：AC-4.7 参数往返、AC-4.5 空结果 props、AC-4.6 限流（`ActiveSupport::Cache::MemoryStore`）、不可用态、日志写入、点击端点写入与 204；`test/integration` 一条「装订 → 1 分钟内可搜」的端到端。
- Vitest：`Search/Show` 六态、筛选控件的地址参数、run 下划线渲染、清除筛选只留 `q`、点击上报后跳转。
- 系统测试：AC-4.4 搜到周刊条目 → 点所在期 → 落到周刊页对应板块锚点；日刊所在期落到条目并切到对应来源。
- 验收：`script/search_eval queries.txt` 读一行一条查询，打印每条的结果数、p95、有结果率（产品负责人提供 50 条真实查询后运行，目标 ≥ 85%）。

## 10. 迁移与运维

- 迁移一：`enable_extension "pg_trgm"`（开发容器与生产 accessory 都用 postgres 超级用户，可直接启用）；建三张表与索引。
- 迁移二（数据）：`Search::Record.rebuild!` 一次性重建现有条目的索引（放在 `db/seeds.rb` 之外，作为迁移后的 rake 步骤写进 `docs/development.md`；`bin/setup` 不自动跑）。
- `config/recurring.yml` 不加新任务；清理走已有的每日清理。
- `docs/development.md` 加「搜索」一节：重建索引、验收脚本、调阈值的位置。

## 11. 边界与已知取舍

- 拼写容错只作用于长度 ≥ 5 的拉丁词；中文没有拼写容错这一概念，只做子串。
- 二元组会让「终端工具」对含「端工」的文本也算命中一个词，靠全命中优先与分数压低影响；验收脚本会暴露是否需要改成「整串优先、二元组补充」。
- 高亮对拼错的词只标前缀相同部分或不标；不做模糊高亮。
- 计数 `COUNT(*)` 在极端长查询下多一次扫描，量级内可接受；超过 50 页只显示「50 / 50」。
- 索引文本是清洗后的展示文本，标题超过 300、摘要超过 500 的部分本来就不在库里。
- 实现时发现（2026-09-11）：数据库按 ctype 把汉字当词字符，贴着中文的拉丁词（「用Rust写的」）没有词首可认；索引副本在中外文交界处补空格，高亮把汉字后面也算词首。
- 「搜索暂不可用」在页面上只有超时一条路能到：连接断了的话，页面 props 本身要查库，请求先 500；设计里的 error 状态是模型层的分类，不是页面上看得到的状态。

## 12. 实现顺序（供计划拆任务）

1. 扩展、三张表、`Search::Record` 与 `Searchable`、批量索引接入装订、重建任务。
2. `Search::Query` 解析。
3. `Search::Runner` 打分排序分页与超时处理。
4. `Search::Highlighter`。
5. 控制器、限流、日志、点击端点、路由与报头链接。
6. 页面 `Search/Show` 与类型、日刊条目锚点、周刊稳定锚点。
7. 系统测试、`script/search_eval`、文档、ADR 补记、CI。
