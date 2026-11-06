# 搜索返回焦点 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 浏览器从日周刊后退回搜索结果时，焦点回到离开时的同一条“所在期”，阅读位置由 Inertia 原样恢复。

**Architecture:** 使用当前搜索历史 entry 的原生片段 `#search-result-${itemId}` 保存稳定条目身份。所在期 Link 的 onBefore 同步执行 `history.replaceState(history.state, '', urlWithHash)`；不透明 state 原样交回、不增加 entry、不触发滚动。Search 在 mount 纯读取严格片段，layout effect 恢复同 id 的链接焦点。收藏仍只做既有那一次客户端 props 写入，使用公开 `router.replace` 同时沿用真实当前 URL，避免擦除原生片段；没有新增异步历史写入、全局观察器或渲染修复 ref。

**Tech Stack:** Inertia 3.7.0 / React / TypeScript，Vitest 与 Rails 系统浏览器测试，无新依赖。

**Spec:** PRD `docs/superpowers/specs/2026-09-08-mvp-prd.md` §5.4 AC-4.4、§6.4 键盘可用；当前持续品质目标。原始现场复现与最小对照见本任务 visualizations 的 `search-history-focus-diagnosis.json`。

**Current status:** 最终实现经独立完整差异审阅，无 Critical / Important。完整 `bin/ci` 通过：前端 480、Rails 856 / 3763 assertions、系统 79 / 8070 assertions，首屏 264.62 KB。独立真实 Chrome 验收仍待桌面解锁；本分支暂不发布。

## Global Constraints

- 不改正文、布局、字体、颜色与搜索点击上报；不访问外部标题，不写真实 Item / Favorite。
- 不接管 scroll，不新增 history.state 字段；仅将浏览器返回的不透明 state 原值传给同 entry 的原生 replaceState。不新增持久服务或依赖；首次进入与普通新查询仍自动聚焦输入框。
- 现有 preserveState 筛选、日期框和来源按钮保留控件焦点；普通 rerender 不重复恢复旧结果。Search 草稿同步只依赖 navigationUrl 的 pathname + search，忽略 hash；仅目标 /search 的 start 宣告搜索加载，离开去刊期不产生额外加载布局。
- 不使用 router.remember / restore，不新增 Search mount 的异步历史写入，不观察 popstate / navigate，不改 pageTurn 或全局 navigationFocus。
- Favorites.settle 的 mounted / leaving 守卫与既有任务数量不变；settle 同步捕获收藏数组快照，再通过单次统一 router.replace 回调合并 props、沿用 pathname + search + hash，并显式 preserveState / preserveScroll。
- 工作树 reading-evidence-quality，独立分支 codex/search-history-focus，基线 c1f47954；PR #69 与主工作区不改。

## Review Focus

- 周刊多个结果可能共用板块 href；稳定 id 必须含条目本身的 25 位小写 base36 主键，读取严格匹配 /^search-result-[a-z0-9]{25}$/。
- 标记只允许当前 /search 地址，原样保留 query 与 opaque state；replaceState 失败必须容错，让原有所在期访问继续。
- mount initializer 是纯读取，StrictMode 可重复执行。存在合法 marker 才关闭 input autofocus；目标消失时只聚焦 h1 preventScroll，main 已有焦点时让路。
- 不增加 repair ref、父级 callback、历史监听或补写任务。收藏写回只在既有 settle 写入中同步真实 URL，合并 props，读取捕获快照而非延后读取 mutable ref。
- full-document Back / reload 的原生片段定位边界需要单独验证。标记前已经排入队列的收藏写入竞态属于既有异步窗口，本轮不声称修复。

### Task 1: 搜索结果的历史焦点恢复

**Files:**
- Create: `app/frontend/lib/searchFocus.ts` — 稳定 id、严格片段读取、同步同 entry 原生标记。
- Modify: `app/frontend/pages/Search/Show.tsx` — mount 纯捕获、autofocus 与 layout focus；draft 同步忽略 hash。
- Modify: `app/frontend/components/SearchResultRow.tsx` — 所在期 Link 稳定 id 与 onBefore 标记。
- Modify: `app/frontend/lib/favorites.tsx` — 既有 settle 单次 props 写回同步真实当前 URL 与快照。
- Test: `test/frontend/lib/searchFocus.test.ts`、`test/frontend/pages/SearchShow.test.tsx`。
- Test: `test/frontend/components/FavoriteButton.test.tsx`、`test/frontend/pages/FavoritesIndex.test.tsx` — 公开 replace、真实 URL、快照与原守卫语义。
- Modify: `test/frontend/support/inertia.tsx` — 实际使用的 Link onBefore / router.replace 最小替身；删除旧候选专用 remember / restore 支持。
- Test: `test/system/searching_test.rb`、`test/system/motion_test.rb`、`test/system/favoriting_test.rb` — 搜索返回、快速历史与收藏同一次写回边界。
- `app/frontend/entrypoints/application.tsx` 恢复基线，不保留旧观察器改动。

**Interfaces:**
- `searchResultId(itemId: string): string` — `search-result-${itemId}`。
- `searchResultTarget(): string | null` — 仅当前 /search 且严格稳定片段时返回 link id；纯读取，不消费。
- `markSearchResult(itemId: string): void` — 仅当前 /search 与合法 id 同步替换本 entry 片段，opaque state 原样交回；失败容错。

- [x] **Step 1: 按新架构迁移失败回归。**
  - module：稳定 id 严格格式、非 Search 不标记、query 与 opaque state 保留、同 entry / 无滚动、失败容错。
  - page：共 href 原条目精确恢复、目标缺失 h1、普通新查询 autofocus、StrictMode / main 焦点让路、hash-only props URL 更新不覆盖草稿。
  - favorites：既有 mounted / leaving 守卫、合并 props 的单次 replace、当前含 hash 的 URL 与同步数组快照。
  - system：原始13条键盘路径、Back / Forward / 下一 Tab 与 <2px scroll；快速 MotionTest 原生历史；收藏 props 写回不擦片段。原实现焦点红测已保留，但旧记忆 API 用例不是新架构验收。
- [x] **Step 2: 原型因果系统通过后收敛最小实现。**
  - 根代理受控 200ms 加密场景已通过（1 run / 13 assertions），随后迁移旧测试；当前生产代码冻结供独立验收。
  - 不使用异步 remember clear、internal history 字段、历史 observer、repair ref 或额外定时器。
- [ ] **Step 3: 定向验证与独立审阅。**
  - targeted Vitest、TypeScript、现有风格检查、searching / reading / motion / favoriting 系统测试、diffcheck，记录红绿证据。
  - 原始13条路径另在真人 Chrome 375 / 1440 重验；三类本地引擎核验页内目标及新查询 / 筛选，不操作外部链接或真实收藏。
  - 独立审查 native fragment、单次 Favorites 写入、全页返回、StrictMode、取消与快速 Back；修复实际发现。
- [ ] **Step 4: 全门禁与独立 PR。**
  - 根代理完整 bin/ci，检查首屏 <=300 KB 与主工作区不变。
  - 提交新分支并创建 / 附加独立 PR，保留可审阅证据；未经该 PR 发布授权不合并。

## Ruling — 否决异步 remember clear，改用有界原生片段（2026-10-22）

根代理全 CI 的 MotionTest 深链第二次 Back 失败，截图与实际地址仍停在 Search。受控证据 `/tmp/lowpass-search-history-queue-200-rejected-remember.json` 表明：Search mount 的 remember(null) 在 417ms 启动额外 200ms 加密；原生 Back 在 424ms 已切到 Daily，431ms Daily navigate 完成；旧写入在 620ms 才完成并以 `/search` replaceState 覆盖当前 entry，随后历史回到错误 Search。旧候选局部绿测没有覆盖这个因果窗口，因此不构成交付通过。

Ruling: 拒绝旧 remember / restore + popstate / navigate 方案；不通过放宽等待或绕过 MotionTest 修补。采用本计划顶部的原生片段方案，并将 Favorites 既有单次 replaceProp 改为等价的公开 replace、同步实际 URL。否决候选已由根代理保存到 `/tmp/lowpass-search-focus-rejected-remember-20261022`。代价：搜索返回地址新增稳定片段，full-document Back 的浏览器行为与原有已排队收藏窗口仍需明确验收；不新增 state 字段或异步写入。该架构变更由根代理明确裁定，实施者不自行扩大范围。

## 已完成的原始诊断（2026-10-22）


- 当前 main 基线，375px 搜索 AI 第13条“所在期”focus A top428，scroll3266.5；Back 保持3266.5但 focus search-query top-3138.5。
- 临时关闭 Search autofocus 与 global 对 Search 的聚焦后，同路径 Back 仍保留 scroll3266.5，但 focus BODY；React 重挂后的链接没有原生恢复。
- 两个临时文件按原字节恢复，git status 确认干净；该原型不进入产品。保存身份是运行时证据要求，不是只凭猜测增加的机制。
- 安装版 React adapter 使用 flushSync，在 swap 的 layout effect 之后才发 navigate；恢复无需与全局 RAF 竞争。
- Ruling: 本轮是持续品质目标内已复现的键盘缺陷修复，沿用当前 GPT 实施与独立审阅方式；局部修复可逆，生产发布单独确认。


## Ruling — 修复离开搜索时既有加载提示导致的 30px 漂移（2026-10-22）

根代理对真实长结果数据施加 250ms 周刊响应延迟，并在初始阶段仅抑制新原生标记，复现了既有 Search 自动聚焦版本仍从 scroll 3267 漂移到 3297，随后 100ms 滚动 debounce 将 3297 写入旧搜索快照，Back 也恢复到 3297。证据 `/tmp/lowpass-search-native-fragment-delayed-baseline.log` 与 `search-native-fragment-baseline-scroll.json`。系统 fixture 的延迟用例未稳定复现这 30px，本轮不把它声称为红测证据。

Ruling: Search 的 start 仅在公开 `visit.url.pathname === '/search'` 时 setLoading(true)，finish 保持原来清 false；修复离开刊期访问时误报“正在搜索…”及其额外布局，不改 CSS / 排版。前端用例在旧无条件 start 下先红（预期1条结果、实际正在搜索），最小分支后绿。代价：其他目标的访问不会再在 Search 局部宣告搜索加载，属于所需语义。

## 当前前端实施与证据（2026-10-22）

- 原生身份严格使用真实格式的 25 位小写 base36 fixture；opaque state 同一参数、query 保留、history length、无 scrollTo / hashchange、非 Search / 非法片段与 replaceState 容错均有 helper 回归。
- Search 验证同 href 的两条原结果精确 focus、缺失 h1 preventScroll、普通新查询 input autofocus、StrictMode、main 已有 focus 与 rerender 让路、hash-only Favorites URL 同步不覆盖草稿、修饰键 / 非左键不标记。
- FavoritesButton / FavoritesIndex 原有请求、undo、rollback、离开 / 进行中访问与 async 访问守卫用例全部保留，迁移为公开 router.replace。公共断言执行功能 props 回调，确认无关 query / 嵌套字段保留；新例在后续取消后重放第一次 callback，确认沿用 settle 数组快照，并核对当前含片段 URL。
- 根代理旧 Favorites 代码回放真实系统红测：`/tmp/lowpass-search-native-fragment-favorites-system-red.log`，1 run / 5 assertions / 1 failure，预期 search-result 片段而实际为空；原型新代码已由根代理恢复，实施者不改动此验证。
- 当前定向：4 files / 99 tests，完整前端：47 files / 480 tests，三份 tsconfig 与 diffcheck 通过。日志 `/tmp/lowpass-search-history-focus-native-{frontend-green,frontend-suite,check,diffcheck}.log`；加载提示红绿 `/tmp/lowpass-search-history-focus-loading-{red,green}.log`。
- 本迁移阶段实施者仅运行前端与类型检查，不触碰根代理拥有的 system 文件、测试数据库或浏览器，不 commit / push。生产代码在 loading 最小修改落地后保持冻结。


## 根代理最终工程验收（2026-10-22）

- 原型受控 200ms 加密回归：1 run / 13 assertions 通过；Search 不再产生 encrypt-start，结束在正确 Daily。旧失败证据与新通过证据分别保留，不覆盖：`/tmp/lowpass-search-history-queue-200-rejected-remember.{log,json}`、`/tmp/lowpass-search-native-fragment-queue-200.{log,json}`。
- 收藏旧代码系统回放真实失败于片段被抹除；恢复最终代码后，完整 SearchingTest 6 runs / 46 assertions 通过（含慢响应、未提交草稿、收藏与再次往返）。
- 根代理完整 `bin/ci` 在 1m4.04s 通过；480 个前端测试、856 个 Rails 测试 / 3763 assertions、79 个系统测试 / 8070 assertions，首屏 264.62 KB（预算 300 KB）。日志 `/tmp/lowpass-search-native-fragment-full-ci.log`。
- 最终独立审查确认收藏请求 / undo / rollback / mounted / leaving / async 守卫测试均保留；功能 props 回调实际执行并验证无关字段与快照，不以 API 调用次数代替行为结论。application / pageTurn / navigationFocus / MotionTest 未改。
- 未操作生产收藏、原文出口、模型请求、历史内容或模型配置；生产只读理由抽查另有私有报告，不进入本 PR。真人 Chrome 的新分支复验仍待桌面解锁，不把隔离的无头引擎测试冒称真人浏览器验收。

- 隔离无头本地验收：Chrome 155.0.8059.85、Firefox 157.0、WebKit 26.4，各 375 / 1440px；每组验证第13条 Enter→Back 精确焦点与 <2px scroll、连续 Forward / Back、含片段刷新、新查询 / 筛选清除片段，无横向溢出。周刊响应额外延迟250ms，外站请求阻断；只创建普通本地 QA 会话及搜索日志，不写真实 Item / Favorite。
- WebKit 默认 Tab 在此宿主配置下跳出文档；用原生 Option+Tab 验证紧邻原文链接，不增加产品按键拦截，也不将该结果冒称普通 Tab 通过。Chrome / Firefox 的普通 Tab 验证通过。证据：本任务 visualizations 的 `search-native-fragment-engines.json` 及六张引擎截图；对应日志 `/tmp/lowpass-search-native-fragment-{engines,webkit}-green.log`。
- Firefox 仅应用数据目录隔离沿用既有 CFFIXED_USER_HOME 测试兼容措施；没有改 HOME 或用户浏览器设置，临时目录已清理。WebKit 使用与2272二进制配套的Playwright 1.59.1协议驱动；浏览器引擎为26.4，不代表实体 iOS Safari 设备验收。
