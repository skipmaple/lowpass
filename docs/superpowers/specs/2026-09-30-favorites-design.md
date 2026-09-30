# P4 收藏 设计文档

| 状态 | 日期 | 依据 |
|---|---|---|
| PRD v0.4 的 5.10 节与 D26 至 D32 已由产品负责人批准（2026-09-30）；本文与界面稿已由产品负责人审过（2026-09-30），K14 同日批准进合并门禁 | 2026-09-30 | PRD v0.4.1 第 5.10 节（F-23、R-10.1 到 R-10.13、AC-10.1 到 AC-10.14）、6.1 到 6.3、7.8、7.9、N-1、N-4、9.3、附录 A 与 B；AGENTS.md 与 `docs/engineering-conventions.md`；设计 skill `.claude/skills/lowpass-design-taste/`；界面稿 `docs/design/notes/2026-09-30-favorites-mock.html` |

需求以 PRD 5.10 为准，本文只写实现设计：数据怎么放、接口怎么定、页面怎么组、怎么验。第 2 节的 K1 到 K15 是写设计时不得不做的默认决定，均可推翻。

本文的方案在一份临时拷贝里完整实现并跑过一遍（独立的临时数据库，没碰开发库与测试库，拷贝已删）：Rails 测试 714 → 757 项、前端单元测试 356 → 392 项、系统测试 17 → 21 项全部通过，rubocop 与 brakeman 无告警。实现计划里的代码取自那份拷贝。

## 1. 范围

做：日刊条目、周刊条目、搜索结果上的书签（收藏与取消）；收藏页 `/favorites`（倒序、分页、取消后原地恢复、空态）；头像菜单入口；私有、下架联动、限流、注销级联；首屏预算的检查脚本。

不做：PRD 5.10「本迭代不做」列的全部（已读、文件夹与标签、计数与提醒、分享、导出、筛选与只搜收藏、按收藏调画像、存全文、链接检测）；注销（F-22）与下架（F-29）的界面；埋点。

## 2. 默认决定

| 编号 | 问题 | 决定 |
|---|---|---|
| K1 | 一条收藏用什么认 | 链接的 `url_hash`。路由是 `DELETE /favorites/:url_hash`，页面 props 与前端状态里都只有 `url_hash`，不出现收藏行的 id。理由：D27 定了一人一链接一条，`(user_id, url_hash)` 就是自然键，前端少管一样东西。 |
| K2 | 收藏要不要引用条目行 | 不引用，表里没有 `item_id`。收藏时抄一份快照；渲染收藏页时按（刊物、周期键、来源、`url_hash`）现查条目还在不在，在就用它现在的译文与条目锚点。理由：重抓是整栏先删后插，条目 id 全换；引用了要么丢收藏，要么重抓后所有收藏都失去锚点与后补的译文，现查则自动对上新行。PRD 附录 A 初稿写了 `item_id（可空）`，随本文改成不引用（v0.4.1）。 |
| K3 | 取消后怎么恢复（R-10.7） | 取消是真删。删的同时回一张签名凭据（`MessageVerifier`，用途 `undo`，一天有效，只认签发给的那个用户），里面是这条收藏的全部字段；「恢复」凭它把同一条原样插回去，id 与收藏时间都不变。服务端不留「已取消」的行，7.8「收藏到用户取消为止」不用加例外。凭据参数 `undo` 进 `filter_parameters`，不写进请求日志。没有选软删除：要多一列、所有读路径都得带过滤、还要定时清理。 |
| K4 | 书签的请求怎么发 | `fetch` + JSON，与 `search/clicks`、测试抓取同一种写法，不走 Inertia 访问。点一下先改本地状态，失败回滚并提示；请求结束后用 `router.replaceProp('favorites', …)` 把最新列表写回 Inertia 当前页（只改历史里的 props，不发请求），离开再后退时页面与服务端一致。读者已经离开这一页就不写；换页的访问还在路上（Inertia 的 `start` 到 `finish`，轮询与部分重载这种 async 的访问不算）也不写，那时写回会顶掉那次访问；没写上的不补（第 13 节第一条）。页面带来新的 `favorites`（生成中的轮询、搜索页的筛选）就以它为准，请求还在路上的链接留着本地的状态。 |
| K5 | 会话过期时点书签 | `create` / `destroy` 对未登录请求回 401，不回 302（fetch 会跟着跳，拿回登录页的 HTML 当成功）。前端收到 401 用 `router.visit` 去 `/login?next=<当前地址>`。收藏页本身（GET）照常 302。 |
| K6 | 页面怎么知道哪些已收藏 | 每个条目与搜索结果的 props 多一个 `url_hash`；日刊、周刊、搜索、收藏四个页面多一个页面级的 `favorites: string[]`（这一页里当前读者收藏过的 `url_hash`）。日刊页生成中的轮询把 `favorites` 一起重载。 |
| K7 | 书签长什么样、放在哪 | Lucide 的 `bookmark`，未收藏描线、已收藏实心（CSS `fill`）；44 × 44 的独立目标。条目行里在行末另占一列，手机上与序号同一行、靠右；搜索结果与收藏页的行里在底行右端。图标右缘与正文右缘对齐。见界面稿。 |
| K8 | 收藏页的行 | 沿用搜索结果行的装置与样式类，标题不带命中下划线，译文用日刊页那一行的样式。取消后标题转次墨，底行右端换成「已取消收藏」与「恢复」，焦点跟到「恢复」；恢复后焦点回到书签。请求失败回滚时，读者还在这一行（焦点在行里，或随换掉的控件落回了 body）焦点才跟回去，已经去了别处就不拽回来。取消的请求还没回来就点了「恢复」，凭据到手后接着恢复，不丢这一下。这一页一行不剩（取消了唯一的一条再后退回来，或者服务端说本来就没有）时显示空态；别的页上还有收藏时不显示空态，只留分页。 |
| K9 | 与搜索共用的东西 | 所在期标签抽成 `PeriodKey.issue_label`，搜索与收藏共用；摘要片段用 `Search::Highlighter.excerpt`（同一套 160 字与不切词规则）；分页抽成 `Pager` 组件，搜索页改用它。 |
| K10 | 两个动作的状态码 | 收藏成功与重复收藏都是 201；条目不存在、已下架、凭据无效都是 404；取消成功 200 带凭据；取消一条不存在的收藏 204。前端只分 2xx、401、429、其他。 |
| K11 | 限流范围 | 每用户每分钟 60 次只管 `create` 与 `destroy`（合计）；收藏页本身不限。 |
| K12 | 下架联动（R-10.9） | 收藏页的查询排除「有任何一条被下架条目」的链接（`NOT IN`），收藏记录不动。条目页上被下架的条目本来就不显示。 |
| K13 | 注销（R-10.11） | `favorites.user_id` 外键级联删除，`User has_many :favorites, dependent: :delete_all`。注销的界面（F-22）不在本次范围，到时删用户即可。 |
| K14 | 首屏预算怎么守 | 新增 `script/first_screen_size`：读生产构建的清单，算日刊页首屏的 JS、CSS（gzip）与界面字体，超过 300 KB 以 1 退出；`bin/ci` 在前端构建之后加这一步。**这一条改了合并门禁**，单列出来请产品负责人确认：不想进门禁就只留脚本。 |
| K15 | 埋点、审计、错误上报 | 都不加（D32、R-10.8）。错误上报的上下文白名单不加键。 |

## 3. 数据模型

`favorites`（`Favorite`）：

| 列 | 类型 | 说明 |
|---|---|---|
| id | string(25) | UUIDv7 base36，同全站 |
| user_id | string(25) | 外键 `users(id)`，`on_delete: :cascade` |
| url_hash | string(64) | 归一化地址的 SHA-256（7.4）；CHECK 长度等于 64 |
| url | string(2048) | 快照：原文地址 |
| title | string(300) | 快照：标题 |
| title_zh | string(300) | 快照：收藏时已有的标题译文，可空 |
| summary | string(500) | 快照：摘要，可空 |
| summary_zh | string(500) | 快照：收藏时已有的简介译文，可空 |
| source_id | string(25) | 外键 `sources(id)`（源不提供删除，R-3.7）；来源名显示当前名称 |
| publication | string(10) | `daily` / `weekly`，CHECK |
| period_key | string(10) | 所在期 |
| section | string(100) | 周刊板块名，可空（所在期标签用） |
| anchor | string(120) | 周刊板块锚点（`Item#anchor`，截到 120），日刊为空 |
| created_at | datetime | 收藏时间；没有 `updated_at`，一行写完不再改 |

索引：`(user_id, url_hash)` 唯一；`(user_id, created_at)`。各文本列按长度加 CHECK 约束。

## 4. 模型接口

- `Favorite.keep(user, item)`：`find_or_create_by!(url_hash:)` 加快照。同一链接已收藏就返回原来那条（所在期与收藏时间不变），并发下靠唯一索引兜底。
- `Favorite.restore(user, token)`：校验凭据（签名、用途、有效期、用户），把原来那条按原 id 与原 `created_at` 插回去；这期间同一链接又被收藏过就返回现有那条；凭据无效返回 `nil`。
- `favorite.undo_token`：上面那张凭据。实现在 `Favorite::Undoing`。
- `Favorite.listed`：排除链接被下架的（K12）。`Favorite.newest_first`：`created_at DESC, id DESC`。
- `Favorite.live_items(favorites)`：一次查出这些收藏对应的、现在还可见的条目，按 `[刊物, 周期键, 来源 id, url_hash]` 建索引；`favorite.live_key` 是同一个键。
- `favorite.where_label`：`PeriodKey.issue_label(publication, period_key, section:)`。
- `User has_many :favorites, dependent: :delete_all`。

## 5. 路由与控制器

```ruby
resources :favorites, only: [ :index, :create, :destroy ], param: :url_hash, constraints: { url_hash: /\h{64}/ }
```

`FavoritesController`：

- `index`：`Current.user.favorites.listed` 倒序分页（每页 20，`page` 从 1 起，不是数字当第 1 页）；页码超过最后一页 302 到最后一页。props：`entries`（行）、`favorites`（这一页的 `url_hash`）、`page`、`pages`，加页脚要的三样。行的字段：`url_hash`、`publication`、`source_name`、`where { label, href }`、`url`、`title`、`title_zh`、`snippet`、`summary_zh`。所在期地址：日刊 `/daily/<键>?source=<源 id>`，条目还在就带 `#item-<id>`；周刊 `/weekly/<键>#<anchor>`。译文优先用现存条目的，没有再用快照。
- `create`：参数 `item_id`（可见条目）或 `undo`（凭据）。成功 `201 { url_hash }`，否则 404。
- `destroy`：按 `url_hash` 找当前用户的收藏，删掉并回 `200 { undo }`；没有就 204。
- `rate_limit to: 60, within: 1.minute, by: 用户 id`，只管后两个动作，超限 429。
- 覆盖 `request_authentication`：非 GET 请求未登录回 401（K5）。

## 6. 页面怎么知道收藏状态

- `Issue::Presenting#item_props` 多一个 `url_hash`；`SearchesController#entry_props` 同样。
- `ApplicationController#favorite_hashes(url_hashes)`：`Current.user.favorites.where(url_hash:).pluck(:url_hash)`，日刊、周刊、搜索三个控制器各调一次（日刊与周刊传这一期可见条目的子查询，搜索传这一页结果的 `url_hash`）。
- 每个页面多一条查询，不进循环。

## 7. 前端

- `types/lowpass.ts`：`Item` 与 `SearchResult` 加 `url_hash`；新增 `FavoriteEntry`。
- `lib/paths.ts`：`FAVORITES`、`favoritesHref(page)`、`favoriteHref(urlHash)`、`loginHref(next)`。
- `lib/favorites.tsx`：`FavoritesProvider`（入参是页面的 `favorites`）与 `useFavorites()`。Provider 持有这一页的收藏集合与这一次停留里的恢复凭据，暴露 `has`、`removed`、`toggle`、`restore`；请求、回滚、提示、写回 Inertia 都在这里。服务端给了内容不同的新列表（换期、轮询、历史恢复）就以它为准，请求还在路上的链接除外（K4）。没有提示时不画提示区。
- `components/FavoriteButton.tsx`：书签按钮。没有套 Provider 时不渲染，所以单独渲染条目行的旧测试不受影响。可读名称「收藏：{标题}」/「取消收藏：{标题}」。
- `components/Pager.tsx`：从搜索页抽出的分页。
- `components/ItemRow.tsx`、`SearchResultRow.tsx`：各加一颗书签。条目行里书签在 DOM 中排在正文后面，Tab 先到标题再到书签。
- `pages/Daily/Show.tsx`、`Weekly/Show.tsx`、`Search/Show.tsx`：props 加 `favorites`，套 `FavoritesProvider`。
- `pages/Favorites/Index.tsx`：收藏页。
- `components/Masthead.tsx`：头像菜单第二项「收藏」。
- `components/Icon.tsx`：加 `bookmark`。

## 8. 界面

界面稿：`docs/design/notes/2026-09-30-favorites-mock.html`（用真实的 `tokens.css` 与字体搭的静态页，稿子里新增的只有 `<style id="proposed">` 那一块，实现时原样搬进 `tokens.css` 末尾）。在装过依赖的仓库根目录跑 `python3 -m http.server 8767`，打开 `http://localhost:8767/docs/design/notes/2026-09-30-favorites-mock.html`；把窗口收窄到 375px 看手机版。

对照设计 skill 的自检：

1. 字体：「收藏」「已取消收藏」「恢复」「还没有收藏。」是文楷；来源名与英文标题是 Newsreader；分页的「1 / 3」是 Maple。
2. 颜色：书签只用墨与次墨，没有新颜色，绿色没有新角色。
3. 字号：13、15、20、56，都在九档里。
4. 没有圆角、阴影、卡片底色。书签是线性图标，实心态是同一个图形填墨，属于「强调靠墨」。
5. 文案全部来自 PRD 附录 B。收藏页不显示总数，不分组。
6. 状态：「已取消收藏」加一个动作「恢复」；空态「还没有收藏。」加一个动作「阅读最新日刊」。
7. 新装置只有书签按钮一个；其余（行、期头、分页、空态、菜单项）都是现成的。

## 9. 隐私、日志与清理

- 收藏只通过 `Current.user.favorites` 读写，没有任何跨用户的入口；后台不加任何收藏字段（有测试钉住用户列表的键）。
- 请求日志里 `undo` 参数被过滤；`item_id` 照常记录，请求日志不带用户 id。
- 取消即物理删除；用户删除时级联删除。没有需要定时清理的东西，`Scheduler` 不加步骤。
- N-4 的个人数据清单已在 PRD v0.4 加上收藏记录。

## 10. 测试

- `test/models/favorite_test.rb`：快照字段、周刊的板块与锚点、同一链接只有一条、每人一份、重抓后收藏仍在（AC-10.3）、重抓后对上新条目行、下架联动（AC-10.13）、倒序、凭据恢复保持 id 与时间、条目已被换掉也能恢复、别人的 / 改过的 / 过期的凭据无效、重复恢复。
- `test/models/user_test.rb`：用户删除时收藏一并删除。`period_key_test.rb`、`search/highlighter_test.rb`：两个共用方法。
- `test/controllers/favorites_controller_test.rb`：收藏页 props（空、日刊行、周刊行与锚点 AC-10.8、片段、后补的译文、重抓后的快照、别人的看不到 AC-10.6、下架、分页与越界、非法页码）；两个动作（收藏 AC-10.1、重复、不存在与已下架、取消加恢复 AC-10.4、重抓后恢复、无效凭据、别人的删不掉、凭据不进日志、限流 AC-10.11、收藏页不限流、未登录 AC-10.7）。
- 日刊、周刊、搜索三个控制器测试：`url_hash` 与 `favorites`，同一链接跨期（AC-10.2）。后台用户页不带收藏信息。
- Vitest：`FavoriteButton.test.tsx`（14 项：两态、乐观更新、请求形状与 CSRF、失败回滚 AC-10.9、限流、401、不重复发、离开后不写、新列表为准）；`FavoritesIndex.test.tsx`（13 项：行、译文与片段、周刊行、取消与恢复及焦点、失败、排队的恢复、204、空态 AC-10.10、分页、没有总数）；`Pager.test.tsx`；`ItemRow`、三个页面与 `Masthead`（AC-10.12）、`paths` 的补充。
- `test/system/favoriting_test.rb`（4 项，开着 CSRF 校验）：收藏 → 头像菜单 → 收藏页 → 取消 → 恢复 → 刷新仍在；取消后刷新消失且所在期里回到未收藏（AC-10.5）；收藏后离开再后退仍是已收藏；375px 下书签 44 见方且不横向溢出。
- 八个验收宽度（AC-10.14）：日刊、周刊、搜索、收藏四页在 320、375、390、481、600、768、1024、1440px 下逐一检查，做法写在实现计划的最后一个任务里。

## 11. 首屏预算与验证数字

按 `script/first_screen_size` 的口径（日刊页：入口与页面分片及其静态依赖的 JS、`application.css`，均按 gzip 后；文楷界面子集、Maple 子集、Newsreader 拉丁分片按原大小）：

| | 合计 | 说明 |
|---|---|---|
| 现状（main） | 295.14 KB | |
| 加上收藏 | 297.70 KB | JS 与 CSS 多 2.10 KB；界面字体子集多一个「藏」字，0.46 KB |

预算 300 KB，余 2.30 KB。余量很薄：之后再往首屏加东西之前，先看这个数字（K14）。

在临时拷贝的真实页面上量过：日刊、周刊、搜索、收藏四页在八个宽度下都不横向溢出，书签都是 44 × 44。

## 12. 迁移与运维

- 一个迁移：建 `favorites` 表。用 `bin/rails db:migrate:primary`（直接 `db:migrate` 会顺手重写 `db/queue_schema.rb`，是已知的无关改动）。
- 没有数据回填，没有环境变量，没有新的常驻进程；部署照常由 CI 触发。
- 界面文案多了一个不在字体子集里的字（「藏」）：重跑 `script/subset_fonts`，只提交三个文楷子集与 `fonts-subset.css`。

## 13. 边界与已知取舍

- 读者点了书签、请求还没回来就跳到别的页面：收藏照常保存，但那一页留在历史里的 props 没来得及更新；后退回去时那颗书签显示的是旧状态，再点一次即一致（收藏幂等）。
- 同一页上两条条目是同一个链接（日刊两个源收了同一篇）：点其中一颗，两颗一起变，因为认的是链接。
- 恢复凭据一天有效。页面开着超过一天再点「恢复」会失败并提示「收藏没有保存，请重试。」，那一行仍是「已取消收藏」。
- 收藏时的摘要、标题是快照，源站之后改了不跟；译文在条目还在时跟条目走。
- 来源名显示当前名称（源改名后收藏页跟着变）。
- 被下架的判断按链接：同一链接只要有一条条目被下架，收藏页就不显示这条收藏。
- 降级成整期一条的周刊节在周刊页上没有书签，但那一条在搜索结果里照样能收藏（它是一条普通条目，链接指向原文）。

## 14. 实现顺序（供计划拆任务）

1. 两个共用方法：`PeriodKey.issue_label`、`Search::Highlighter.excerpt`。
2. 表与模型：迁移、`Favorite`、`Favorite::Undoing`、用户关联、参数过滤。
3. 控制器与路由。
4. 日刊、周刊、搜索页带上收藏状态。
5. 前端基础：类型、地址、图标、`lib/favorites.tsx`、`FavoriteButton`、样式。
6. 书签接进条目行、搜索结果行与三个页面；抽出 `Pager`。
7. 收藏页与头像菜单入口。
8. 系统测试。
9. 字体子集、首屏预算脚本与 CI。
10. 文档同步与验收记录。
