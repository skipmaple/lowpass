# 收藏（P4）验收记录

依据：PRD 5.10 的 AC-10.1 至 AC-10.14、10.1 的 P4 行、10.2 的 P4 退出清单；设计 `docs/superpowers/specs/2026-09-30-favorites-design.md`；界面稿 `docs/design/notes/2026-09-30-favorites-mock.html`。

## 逐条验收

| 验收标准 | 由什么验 |
|---|---|
| AC-10.1 点一下即收藏，不刷新、不出提示，收藏页第一条是它 | 系统测试「收藏一条，从头像菜单进收藏页，取消后恢复」；`favorites_controller_test.rb`「POST 收藏一条条目（AC-10.1）」；`FavoriteButton.test.tsx`「点一下收藏：立刻换成已收藏，POST 条目 id，结束后把列表写回当前页」 |
| AC-10.2 同一链接在另一期、在搜索里都显示已收藏，收藏页只有一条 | `favorite_test.rb`「同一链接只有一条，所在期是第一次收藏的那一期」；`daily_issues_controller_test.rb`「同一链接在另一期也算已收藏，别人的收藏不算」；`searches_controller_test.rb`「结果带 url_hash，favorites 列出这一页里收藏过的链接」 |
| AC-10.3 重抓后收藏仍在，标题、来源、所在期、原文都在 | `favorite_test.rb`「重抓换掉条目行，收藏还在」；`favorites_controller_test.rb`「条目被重抓换掉后，收藏行用快照」 |
| AC-10.4 取消后原地留「已取消收藏」与「恢复」，恢复并刷新后仍在原位 | 系统测试「收藏一条，从头像菜单进收藏页，取消后恢复」；`favorites_controller_test.rb`「DELETE 取消并给回恢复凭据，POST 凭据原样恢复」；`FavoritesIndex.test.tsx`「取消后那一行原地留下「已取消收藏」与「恢复」，恢复凭取消时拿到的凭据」 |
| AC-10.5 取消后刷新不再出现，所在期里是未收藏 | 系统测试「取消后刷新，那一行不再出现，所在期里的书签回到未收藏」 |
| AC-10.6 别人看不到，后台没有任何收藏信息 | `favorites_controller_test.rb`「别人的收藏看不到（AC-10.6）」；`admin/users_controller_test.rb`「用户列表不带收藏信息」 |
| AC-10.7 未登录访问收藏页跳登录并带 next | `favorites_controller_test.rb`「未登录：收藏页跳登录并带 next（AC-10.7），书签的动作回 401」 |
| AC-10.8 周刊收藏的所在期落到板块锚点 | `favorites_controller_test.rb`「周刊收藏的所在期落到板块锚点（AC-10.8）」 |
| AC-10.9 保存失败回滚并提示 | `FavoriteButton.test.tsx`「收藏没保存上：回到未收藏，提示附录 B 那一句」「断网（fetch 直接 reject）同样回滚并提示」「取消没保存上：回到已收藏，提示「取消收藏没有保存，请重试。」」 |
| AC-10.10 空态 | `favorites_controller_test.rb`「没有收藏：空列表，带去最新日刊要的键（AC-10.10）」「没有收藏时页码越界跳回第 1 页」；`FavoritesIndex.test.tsx`「没有收藏：「还没有收藏。」与去最新日刊的链接」 |
| AC-10.11 限流 | `favorites_controller_test.rb`「一分钟 60 次以上回 429（AC-10.11）」；`FavoriteButton.test.tsx`「限流 429：回滚并提示限流那一句」 |
| AC-10.12 头像菜单有「收藏」，报头其余不变 | `Masthead.test.tsx`；系统测试「收藏一条，从头像菜单进收藏页，取消后恢复」 |
| AC-10.13 下架联动 | `favorite_test.rb`「listed 不含链接被下架的收藏，恢复上架后回来」；`favorites_controller_test.rb`「被下架的条目不出现，恢复上架后回来（AC-10.13）」 |
| AC-10.14 八个宽度、44 × 44、键盘与读屏 | 系统测试「手机宽度下书签是 44 见方，页面不横向溢出」；下面的「八个宽度」；`FavoritesIndex.test.tsx` 的焦点与可读名称断言 |

10.2 的 P4 退出清单：修订后收藏仍在、两个用户互不可见、下架联动三项都有自动化测试（见上表 AC-10.3、10.6、10.13）。

## 测试与门禁

`bin/ci` 全部通过。各步的数字：

| 项 | 改动前 | 改动后 |
|---|---|---|
| Rails 测试（`bin/rails test`） | 714 | 758 |
| 前端单元测试（`npm test`） | 356 | 392 |
| 系统测试（`bin/rails test:system`） | 17 | 21 |
| rubocop、brakeman、类型检查 | 无告警 | 无告警 |

## 首屏

`npm run build && script/first_screen_size`：改动前 295.14 KB，改动后 297.68 KB，预算 300 KB。多出来的是书签与它的状态管理（JS 与 CSS 2.10 KB）和界面字体子集里的一个「藏」字（0.44 KB，`app/frontend/fonts/lxgw-wenkai-screen-ui.woff2` 从 46600 字节变成 47048 字节）。这个预算量的是日刊页（`script/first_screen_size`）；周刊、搜索与收藏页的文案用到界面字体子集之外的字时，另外按需下载 `ui-extra` 那一片界面字体子集，不在这个量里（改动前也一样）。

## 八个宽度

日刊、周刊、搜索、收藏四个页面，320、375、390、481、600、768、1024、1440px 八个宽度，共 32 组：页面都不横向溢出，书签的触控目标都是 44 × 44。做法见实现计划 Task 10 的第 3 步。

- 量的是开发库里的页面：日刊是 `/` 跳到的最新一期（2026-09-17，只有 Hacker News 一栏，10 条），周刊是 2026-W38（34 条），搜索词是 `rust`（1 条结果），收藏页有 3 条。32 组里每一组的 `scrollWidth` 都等于页面宽度。
- 那一期日刊只有一个来源，所以另外把 2026-09-10 那一期的三个来源栏（Hacker News 10 条、GitHub Trending 10 条、Hackaday 7 条）也各按八个宽度量了一遍，共 24 组，同样不溢出、同样是 44 × 44。
- 键盘（无头 Chrome，桌面宽度）：从日刊页条目的标题按 Tab，焦点依次是标题、评论链接（该条有评论地址时）、书签；书签上是 2px 实线墨色焦点框，与 `--ink` 同色；空格与回车都能切换收藏状态，焦点留在书签上；收藏页取消一条后焦点落在「恢复」上，点「恢复」后那一条回到已收藏。书签的可读名称是「收藏：标题」或「取消收藏：标题」。

## 与实现计划的出入

- `db/schema.rb` 里 `favorites_publication` 约束按文件既有的写法记录（`'daily'::character varying::text` 那种），其余表的约束没有改动。
- 收藏页：空列表也算一页，越界的页码（包括大到超出 bigint 的）一律跳回最后一页；计划里的代码在没有收藏时会把它带进 OFFSET。多一条控制器测试，Rails 测试因此是 758 项。
- 系统测试的手机宽度用 CDP 把视口定成真的 375px（无头 Chrome 的窗口收不到 500px 以下）；`with_forgery_protection` 与 `wait_until` 收进 `ApplicationSystemTestCase`，搜索的系统测试改用同一份。
- 首屏预算除了 `bin/ci`，GitHub Actions 的 `test` job 也跑同一步（`.github/workflows/ci.yml`）。

## 复盘

上线满 4 周那天按 PRD 9.3 的三档决定后续（D32）。上线日期：（合并部署后由产品负责人补上）。
