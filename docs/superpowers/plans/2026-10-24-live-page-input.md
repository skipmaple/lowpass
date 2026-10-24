# M2 Native Input During Page Turns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现已批准的完整 M2 旧方案：NEW 在最终坐标淡入、OLD 按原方向退出，播放期间第一次可信输入即同步收尾并由原生默认动作处理。

**Architecture:** 保留 Inertia 的原生 View Transition 入口，以服务端 Page 对象和独立 token 关联每次过渡。共享 Layout 与 Login 的同步 React 提交探针在 NEW 捕获前移除所有命名捕获；OLD 由 native overlay 绘制，真实正文以同一 native timeline/startTime 淡入，输入仅负责同步结束视觉反馈。

**Tech Stack:** Rails 8 / Inertia core + React adapter **3.7.0**（当前 lockfile）、React 19、TypeScript、CSS/WAAPI、Vitest/Testing Library、Selenium/Chrome。

**Spec:** `/Users/drewlee/.codex/worktrees/live-page-input/lowpass/docs/superpowers/specs/2026-10-24-live-page-input-design.md`（整份已读；保留原文件不改）。文件的“待批准”是历史状态；用户随后“按你的建议来实施”已批准完整本地实现与验收，不再追加计划确认。

## Global Constraints

- 本计划只授权本地实现、离线回归、自然播放与真实输入验收；不授权 M2 合并、部署、生产写入、收费模型调用。禁止复用 `transition-input-quality` dirty/rejected 实现。
- 阅读基线为 `origin/main=d233d57990829f4420fd9a26adbef18b88602390`，不是 primary 的旧 ac1。执行时从 root 确认已合并 #90 的最新 main 开始，只带本计划改动，保留 #90 的纯 wrap 修复。
- OLD 捕获 root **视口**、masthead、issue-date；NEW 三者均为 `none`，不存在捕获控件的 NEW 祖先；原生伪元素不参与命中。
- NEW 正文只做 opacity，坐标固定；OLD 方向退出 **24px**。普通跨页 **240ms / --ease-out**，前后一期 **360ms / --ease-move**，日期与本次总时长相同；有新报头则隐藏 OLD masthead，无新报头则同次淡出。
- 仅现有合格服务端整页 GET 启用；保留状态、async、prefetch、partial、表单、同路径访问保持原入口范围；客户端 router.push/replace 不擅自新增入口。服务端 replace 必须完整覆盖。
- NEW phase 必须在匹配 Page 的 `useLayoutEffect` 内同步改变；不以 URL、对象变化、navigate 或 `updateCallbackDone.then` 作为提交身份替代。首次挂载、跨祖先重挂、StrictMode 都要成立。
- native ready 后以实际 OLD root Animation 的 **同一 timeline/startTime** 启动 NEW 淡入；不另设 timer/rAF 起点。日期定位必须在首个实际播放画面前完成；若 API/时序不能可靠满足，保留失败证据并停止候选，交 root 修订。
- 播放期间 `.sheet-body` 临时具有现有纸色与两层纹理，相位按外层 paper 与正文边框 rect 差对齐；正常态、打印、尺寸/排版、数据、已发布刊期、图片 URL/加载不变，不新增图片探测/处理。
- ready→finished 的可信 pointerdown / keydown / wheel 立即收尾；不 preventDefault / stopPropagation / 合成输入 / click / focus / pointer capture / 接管滚动。现有 popstate 等待后重放属于既有历史保护，不是重放用户输入，不删除。
- reduced motion 或无原生 API 直接终态；不引入动画库、克隆双 DOM、全局 Inertia resolver 改造或其他动效变化；首屏预算仍为 300 KB，完整 `bin/ci` 门禁保留。
- 所有自然画面必须原始 240/360ms、1×、不暂停；所有输入通过浏览器真实输入通道且记录 `isTrusted`。桌面与触摸模拟分别报告，模拟器不称物理手机，源码与 CI 不能替代画面验收。

## Review Focus

1. beforeUpdate 与 track 之间存在异步组件解析/history；重叠响应、flash 克隆或旧 promise 完成不能把错误 Page 放行或清除新 token。（Task 1/4）
2. 跨 DailyLayout/WeeklyLayout/Login 重挂及 StrictMode 的重复 effect/cleanup，首次匹配提交必须及时去名，cleanup 不得删除全局过渡。（Task 1）
3. opacity 混合组使真实周刊白底图发白，或临时纸纹在 3px/4px 周期内错位；前中后画面须保持纸面相位。（Task 2/5）
4. 新日期宽度与旧日期不同、页脚翻页、无新日期或登录重定向；旧日期按新位置淡出且不拉伸/飞掠，旧报头不遮登录。（Task 2/5）
5. 首次 pointerdown 收尾后仍须保留光标落点、拖出取消、正文拖选、触摸 pan→cancel、修饰键链接及滚轮默认动作；“能打开菜单”不足以验收。（Task 3/5）

---

## 当前代码事实与文件职责

- `app/frontend/lib/pageTurn.ts`：现有 track 只维护 token/data-vt/data-turn、finished 清理与 updateCallbackDone 历史等待；新增精确提交、播放与输入收尾仍归此模块，避免引入通用动画框架。
- `app/frontend/styles/motion.css`：只改 M2 与对应 reduced-motion 规则；现有 M2 同时捕获 NEW root，系统测试仍要求 `lp-turn-in-left`，这条旧契约要改为“NEW 普通 DOM 无 transform”。
- `app/frontend/components/Layout.tsx`、`app/frontend/pages/Login/Show.tsx`：各接入一次同步提交 hook，持有正文元素 ref；不调整全局 resolver。当前 16 个 page：15 个经 Layout（含 6 个 Admin 页面），Login 唯一例外。
- `test/frontend/lib/pageTurn.test.ts`、新 `test/frontend/lib/pageTurnCommit.test.tsx`、新 `test/frontend/lib/pageTurnInertia.test.tsx`：分别验证状态机、真实布局探针、锁定 adapter 的 Page identity/flushSync。
- `test/frontend/support/inertia.tsx`：替身必须返回稳定 Page 对象，支持指定 Page 与 beforeUpdate，不能每次 `usePage()` 新建对象掩盖身份错误；既有 setPageProps 调用保持兼容。
- 新 `test/system/page_turn_test.rb`：M2 真应用回归；`test/system/motion_test.rb` 只替换旧 NEW 横移断言，其余 M1/M3/M5/M8 原覆盖保留。纸面几何可共用既有 helper，不把测试录制器放产品代码。
- `docs/superpowers/specs/2026-10-14-award-quality-design.md` 的 M2、`docs/superpowers/specs/2026-09-08-mvp-prd.md` 的 D34、`.claude/skills/lowpass-design-taste/SKILL.md` 的翻页说明：记录获准可见契约；新 `docs/design/notes/2026-10-24-m2-native-input.md` 记录决定、实现边界及最终证据索引，不改历史旧提案。

## Task 1: 精确提交身份与 OLD-only 生命周期

**Files:** 修改 `app/frontend/lib/pageTurn.ts`、`app/frontend/components/Layout.tsx`、`app/frontend/pages/Login/Show.tsx`、`app/frontend/styles/motion.css`、`test/frontend/support/inertia.tsx`、`test/frontend/lib/pageTurn.test.ts`；新增 `test/frontend/lib/pageTurnCommit.test.tsx`、`test/frontend/lib/pageTurnInertia.test.tsx`。

**Interfaces:** 保留 `pageTurn(direction: TurnDirection)`、`crossfadeFor(href: string, options: VisitOptions)`、`useArrowTurns`。新增导出 `usePageTurnCommit(page: Page, surface: RefObject<HTMLElement | null>): void`；内部 `commitPageTurn(page: Page, surface: HTMLElement): void` 只接受 active.targetPage === page。内部 `track(transition: ViewTransition, direction: TurnDirection | null): void` 给本次 target/token 固定关联；`completePageTurn(token: object, reason: 'finished' | 'input' | 'replaced' | 'unmatched' | 'rejected'): void` 幂等，只清本 token 拥有的状态。

**工程决定：** `data-vt="old"|"new"` 表示捕获阶段，`data-turn` 保留方向。监听 beforeUpdate 只记对象、不改 CSS；track 消费待提交目标，清空已消费记录。记录不得跨无过渡访问/客户端访问/取消遗留；交错响应的身份失败一律终态，禁止回退 URL 关联。pending 记录与 active token 分开。`updateCallbackDone` 仍用于 swapping 历史保护，并可在 callback 完成后发现“始终没匹配”而结束，绝不用于正常 NEW phase。

- [ ] **1. 写失败测试**：在 `pageTurn.test.ts` 覆盖 beforeUpdate 不切 phase、同 URL 不同对象不匹配、相同对象在首次 commit 同步切 NEW、重复 commit 不重启动画。断言形状：
  ```ts
  expect(root.dataset.vt).toBe('old') // beforeUpdate/错误对象后
  expect(root.dataset.vt).toBe('new') // 相同目标对象的同步 layout effect 后
  expect(transition.skipTransition).toHaveBeenCalledTimes(1) // unmatched 收尾
  ```
  在 `pageTurnCommit.test.tsx` 渲染真实 Layout/Login，稳定 Page 替身驱动 rerender、卸载重挂及 `<StrictMode>`；assert 匹配挂载立刻进入 new，effect cleanup 后仍保留当前 token。
- [ ] **2. 证明红灯**：`npm test -- test/frontend/lib/pageTurn.test.ts test/frontend/lib/pageTurnCommit.test.tsx`。保存新增导出缺失/phase 未变的实际失败；原 history/eligibility 回归须继续跑，不能只让导入失败冒充全部行为证明。
- [ ] **3. 实现最小生命周期与探针**：Layout 复用一次 usePage 结果并传 `.sheet-body` ref；Login 传 `.login-ground` ref。hook 使用 useLayoutEffect，cleanup 不销毁全局 token。OLD 的 html 显式命名 root；NEW 将 html、masthead、issue-date 名称同步设 none。仅 OLD phase 为 masthead/date 命名。
- [ ] **4. 加锁定 adapter 的集成断言**：`pageTurnInertia.test.tsx` 单独 `vi.unmock('@inertiajs/react')`，用真实 `App/usePage`，包装 router.init 捕获其实际 swapComponent，传同一 Page，断言 layout effect 读到对象 `toBe(targetPage)`，且 effect 先于 swap promise 完成；含不同祖先/首次挂载。源码契约审计同时核对 core response 的 beforeUpdate→page.set→swap 未克隆目标（history 的副本不是 React Page）。这项测试单独跑，不污染全局替身。
- [ ] **5. 绿灯与局部提交**：运行上述三文件及 `npm run check`，保存命令/结果；`git diff --check`，本地提交 `fix: switch page turns at matching React commits`。若单测替身行为变化影响既有测试，修替身契约而不是放宽身份断言。

## Task 2: 统一 native 时钟、纸纹与日期位置

**Files:** 修改 `app/frontend/lib/pageTurn.ts`、`app/frontend/styles/motion.css`、`test/frontend/lib/pageTurn.test.ts`、`test/system/motion_test.rb`；新增 `test/system/page_turn_test.rb`。

**Interfaces:** Task 1 active 记录增加 `surface: HTMLElement | null`、`incoming: Animation | null` 与 token 所有的临时样式恢复信息。内部 `startPageTurnPlayback(token: object): void` 在 native ready reaction 调用；`preparePaper(surface: HTMLElement): () => void` 在 commit 后、淡入前放好临时纸面并返回精确恢复函数；`positionOldDate(date: DOMRect | null): void` 仅设置本次伪元素定位变量。

**工程决定：** 从 `document.getAnimations()` 精确选择 effect.pseudoElement 为 `::view-transition-old(root)` 的本次 native 动画（不取第一条普通动画）。NEW 用 `new Animation(new KeyframeEffect(surface, [{ opacity: 0 }, { opacity: 1 }], timing), native.timeline)`，设置 `startTime = native.startTime`；timing 同该次 240/360ms 和缓动。native 起点/时间轴不可读或不匹配即拒绝候选，不凭 performance.now 自造起点。临时背景读取外层 `.paper` 的现有 computed background color/image/size/repeat；以边框 rect 的 `paper.left - surface.left` / `paper.top - surface.top` 配合显式 border-box origin 固定相位，保存恢复原 inline 值。Login 已是 paper，不重复叠一份纹理。

- [ ] **1. 写失败测试**：单测以明确 native Animation fixture 验证：`incoming.timeline === native.timeline`、`incoming.startTime === native.startTime`、两档 duration/easing 相同、keyframes 无 transform；ready 已经过部分时间时不得重新从零播放。断言清理后原有 inline 背景/opacity 恢复、第二 token 不受旧清理影响。
  系统测试先把原 `motion_test.rb` 的 `::view-transition-new(root)/lp-turn-in-left` 断言改为 NEW 三名 none、仅 OLD root 有方向退出；375/1440 的正文 rect 起中终相同，普通240/翻期360、方向 ±24px、日期同 duration。新增纸纹 4×3px 相位断言、白黑 SVG multiply、不同日期宽度和无新日期/无新报头。
- [ ] **2. 证明红灯**：`npm test -- test/frontend/lib/pageTurn.test.ts`；先 `env RAILS_ENV=test bin/vite build --mode test`，再 `bin/rails test test/system/page_turn_test.rb test/system/motion_test.rb`。保存旧 NEW 捕获/横移或缺临时纸面等可观察失败，不修改时长使失败消失。
- [ ] **3. 实现 M2 样式与播放**：OLD root 定义显式无方向 fade-away；有方向保留左右退出。NEW opacity 初始0须在 commit 就就位；ready 同步接同一时间轴。OLD root/date 的 image-pair 混合模式设置须避免默认双快照交叉叠加；所有 VT 层 pointer-events none。新报头存在时立即隐藏 OLD masthead，否则随本次时长淡出。ready 内在 Inertia Scroll.reset 已完成后读新日期视口 rect，移动 OLD date group 到新 left/top；旧截图自有宽高保留，不把新 date 宽高赋给 OLD，不做 group 位移补间。没有新 date 不重定位。
- [ ] **4. 绿灯并保留时序证据**：运行同命令，保存 native timeline/startTime、实际 ready/第一帧时间、滚动 reset 与日期 rect。Task 5 的自然首帧仍是最终判定，computed style 通过不能替代。无可用 native 时钟或首帧已有飞掠则停止并报告。
- [ ] **5. 局部提交**：`git diff --check` 后本地提交 `fix: align incoming paper with native page turn timing`；只包含本任务与对应文档获准契约，其他动效不改。

## Task 3: 可信输入同步收尾并保持默认行为

**Files:** 修改 `app/frontend/lib/pageTurn.ts`、`test/frontend/lib/pageTurn.test.ts`、`test/system/page_turn_test.rb`。

**Interfaces:** 内部 `listenForPageTurnInput(token: object): () => void` 在 ready 播放区间注册 document capture 的 pointerdown/keydown/wheel（passive）；只在 `event.isTrusted` 时调用 Task 1 的 `completePageTurn(token, 'input')`。收尾同步将 NEW 显示终态、撤销 fade 动画和临时纸面，调用 native skipTransition 并移除监听。正常 finished/skip/reject/替换也复用清理。

- [ ] **1. 写失败测试**：合成 pointerdown/keydown/wheel 与 focus 不使过渡提前结束；监听回调对可信事件对象的单位测试只证明分支，不冒充真实输入。断言 `preventDefault`、`stopPropagation`、`setPointerCapture`、控件 `click/focus` 未调用；输入结束旧 token 不可删除新 token。系统测试使用 Selenium Actions/CDP Input 发送真实 down/up/键盘/wheel，记录事件 `isTrusted/target/defaultPrevented` 与 activeElement、selection、click 次数、scrollY。
- [ ] **2. 红灯证据**：`bin/rails test test/system/page_turn_test.rb` 固定 natural playback 内的搜索点击/账户/拖出取消用例，至少保留旧版本实际 target=HTML 或默认行为不成立的一条完整事件链；没命中播放区间属于无效样本，不能当通过。
- [ ] **3. 实现输入收尾**：只注册三类事件；不注册程序 focus 作为人为输入。监听收到真实事件时同步完成视觉状态，不改变 target 几何。保留 ArrowTurns 自身已有导航语义（它原本处理方向键），不得把其中 preventDefault 误删或用于 M2 收尾。
- [ ] **4. 绿灯**：`npm test -- test/frontend/lib/pageTurn.test.ts`、`bin/rails test test/system/page_turn_test.rb`。验证账户打开/焦点/Escape、搜索指定字符间隙点击后输入、按住按钮拖出释放0次激活、正文选择、原文/修饰键链接、收藏反馈、自然滚轮。真实触摸机制单列 tap、输入聚焦/输入、pan→pointercancel 且0次激活，不能用鼠标事件改 pointerType 代替。
- [ ] **5. 局部提交**：本地提交 `fix: finish page feedback on trusted native input`，同时保存失败与通过原始记录；不为偶发失败追加重试或丢弃坏样本。

## Task 4: 重叠、replace、取消与阅读历史

**Files:** 修改 `app/frontend/lib/pageTurn.ts`、`test/frontend/lib/pageTurn.test.ts`、`test/system/page_turn_test.rb` 及上列 M2/D34/设计技能说明；新增 `docs/design/notes/2026-10-24-m2-native-input.md`；只复验现有 `historyScroll.ts` 及其测试。

**Interfaces:** 消费 Task 1–3 的同一 active/token/cleanup；`historyScroll.ts` 的 `captureHistoryScroll` 与现有 swapping/replaying 机制不变。无新的对外接口或客户端访问 VT 入口。

- [ ] **1. 写失败矩阵**：两个 native transition 连续启动，旧 ready/finished/reject 晚到；beforeUpdate A/B 与延迟组件/history 交错；未匹配 target 后 update 完成；flash 克隆同 URL；服务端 GET `replace:true` 不触发 navigate 但仍 commit/play；redirect 到 Login；skip/rejected ready/update/finished 无 unhandled rejection、残余标记或 opacity0。StrictMode 同 token 重复提交不重新归零。
  ```ts
  expect(root.dataset.turn).toBe('forward') // A 收尾后 B 仍活动
  expect(newSurface.style.opacity).not.toBe('0') // unmatched/reject 后可读
  expect(seenPopstateStates).toEqual([originalState]) // 换页完再交给 Inertia
  ```
  新旧完成顺序与日期/背景恢复同测；收藏 client router.replace 只更新 props、无新增 VT，保留现有收藏回归。
- [ ] **2. 证明红灯**：先跑定向 `pageTurn.test.ts` 与 `page_turn_test.rb`；每个新增故障至少指向实际失败断言，不用先全实现再补测试。
- [ ] **3. 实现最小竞争处理**：前次 surface/timing/样式只由其 token 清理；新 track 先安全终结旧反馈，再登记新 token。未匹配在 update 完成时终态结束，拒绝 Promise 均被处理且不遮挡内容。beforeUpdate pending 过期不能被下一次访问复用；若交错源链无法保证关联而错配到了其他目标，拒绝方案并报告，不弱化成 URL 匹配。
- [ ] **4. 绿灯与真实历史验证**：运行 `npm test -- test/frontend/lib/pageTurn.test.ts test/frontend/lib/historyScroll.test.ts` 及 `bin/rails test test/system/page_turn_test.rb test/system/motion_test.rb`；从正文非零位置→搜索→Back/Forward，含 swap 前原生 Back、连续 Back/Forward、用户新输入取消历史纠正，URL/刊期一致、恢复位置误差沿用原测试 <2px。
- [ ] **5. 局部提交**：本地提交 `test: cover interrupted and replacement page turns`。同步更新 M2/D34/设计技能的已批准契约与证据说明，保留 #90 diff，禁止拿旧 dirty 分支补补丁。

## Task 5: 自然播放和真实输入验收，独立审查后本地交付

**Files:** 产品只用前四任务结果；私密证据放本目录 `baseline/`、`candidate/`、`acceptance.json`、`acceptance.md`；本计划写作者不创建这些结果。本地执行者可写独立采集脚本，脚本不进入产品入口。

**Interfaces:** 每个记录至少含 caseId、commit、浏览器/驱动版本、viewport/DPR、headless/headed、focus 状态、reducedMotion、路由/方向、ready/finished/input 时间、native/incoming timeline/startTime、frame 时间及文件、isTrusted/实际 target/defaultPrevented、预期/实际默认结果、pass/fail/invalid。无输入自然播放与有输入提前结束分开；前者不能因监听操作提前结束而冒充完整时长。

- [ ] **1. 固定案例并留 baseline**：执行前保存最新 main SHA、与 d233/#90 差异、Chrome 版本与窗口环境；相同 fixture、图像缓存及视口的 baseline 与候选对照。系统测试只用仓库 fixture/本地离线响应；另对真应用既有真实周刊图片检查完整自然画面，不改 URL，不新增图片探测，不改生产数据。截图可读性/窗口焦点先确认，实际窗口失败即保留失败。
- [ ] **2. 一次运行完整门禁**：`bin/ci` 所有步骤退出0后继续真实浏览器；记录首屏 <=300KB 和系统测试结果。新修改或真实失败需要回到对应任务再验证；CI 通过不代表 M2 验收已通过。
- [ ] **3. 自然画面采集**：375×812、1440×900，各测普通/减少动态效果；原始 240/360ms 1×录屏或浏览器 screencast 帧带单调时间戳，同时无侵入记录 rAF/native 时钟。禁止 pause/currentTime/playbackRate/延长 duration。前、至少一个中间帧、后帧必须真实存在且对应同一次访问；采集速度不足即 invalid，不能拼接成功样本或隐藏失败。覆盖长→短、短→长、页脚翻期、前/后两方向、不同日期宽度、无日期、Login redirect。检查 OLD 旧视口内容（非长文档空纸）、新正文固定、旧日期位置/大小、报头静止、无闪白/空纸退场/横向溢出/终态残留/弹层遮挡。
- [ ] **4. 纸面专门验收**：白/黑合成 SVG 与既有真实周刊图分别记录；确认临时 opacity 组中白色部分仍为纸色、黑色仍墨色，与外部纸面4×3px纹理相位一致。滚动非整周期位置也采样，不能只看浏览器测得 background-image。图片加载完成前后均保持原有加载规则。
- [ ] **5. 原生输入采集**：用 Selenium W3C Actions/CDP Input 在新页 ready→finished 内发原生输入，事件日志证明实际时间落在区间；不 `.click()`/dispatchEvent，不用会等动画结束的高层自动等待点击作为播放期间证明。覆盖 Task 3 完整桌面/触摸矩阵及新页多个位置的快速点击，验证目标语义，不以“有按钮打开”判通过。未落区间记 invalid 并修采集方案；行为失败原样保留，修复后形成新版本证据，不追加 retry 擦除失败。capture/update 暂停阶段单列观察，不宣称期间可操作。
- [ ] **6. 浏览器与审查**：仓库当前正式矩阵是 Selenium headless Chrome（`test/application_system_test_case.rb`），另做桌面实际 Chrome 窗口验收并记录版本/焦点；无 API 路径和 reduced-motion 必测。触摸为 CDP/驱动真实输入机制的模拟器结果，物理手机明确未覆盖；若执行环境有既定其他浏览器矩阵，照原矩阵执行而不擅自豁免。独立 reviewer 对照完整旧spec、最终 diff、失败记录及自然帧逐项接受；任何核心契约失败即拒绝发布，保留本地结果。
- [ ] **7. 本地交付**：`git diff --check`、status、提交范围、全部实际命令结果、每个案例结论和证据链接交 root。结论只写本地接受/拒绝与未覆盖边界；没有自动 M2 PR、merge 或 deploy。本计划及旧spec无需用户再确认。

## 已读证据与需 root 裁定的冲突

具体读取：旧spec整份；AGENTS.md、STYLE.md、设计技能整份及 lowpass-tokens；writing-plans整份；`origin/main` 的 pageTurn.ts、Layout.tsx、Login/Show.tsx、motion.css、application.tsx、pageTurn.test.ts、support/inertia.tsx、motion_test.rb、historyScroll.ts、favorites.tsx相关段、tokens.css纸面段、package.json、package-lock.json的Inertia项、vitest.config.mts、test/application_system_test_case.rb、config/ci.rb；16页面layout声明/包装链；MVP PRD D34、award-quality-design M2、development 测试矩阵段。实际安装的 core/react package.json 均3.7.0，读取 core dist 的 response.setPage/currentPage.set/swap 和 react dist 的 App/flushSync/PageContext；不是根据旧包版本猜测。

工程决定已在任务内定明，不需 root 再选命名、文件分层、测试矩阵或提交方法。当前无待用户裁定的产品冲突。以下是实现硬门，失败时需 root 裁定是否修订设计，不能由实现者悄悄降级：

1. 现有 application 注释声称持久 Layout 不重挂，但当前不同祖先类型会重挂；按旧spec采用双探针覆盖，此冲突已解决，不改 resolver。
2. native Animation timeline/startTime 与首帧日期定位只有源码仍不足证明。若实际 Chrome 不提供可靠时钟/首帧更新，候选停止；不能假装“两个接近时钟”满足规范。
3. beforeUpdate→track 的异步交错若无法固定正确 Page、导致正常 replace/重叠被系统性跳过，需修订关联入口；不能以“安全skip”把目标浏览器/replace/移动端静默豁免。仅异常未匹配按终态收尾。
4. 当前 motion 系统测试仍要求 NEW 横移，与已批准旧spec冲突；按获准可见契约替换该断言，保留 OLD24px与其余覆盖。#90 wrap 与本任务独立，执行时保留其最终结果。

自检：完整旧spec的捕获、身份、首帧、纸面、日期、输入、竞争/历史、自然播放及授权边界均映射到以上任务。未运行任何测试、未修改产品、未创建 worktree/PR；本文件是一份实施计划，不是实现通过证据。
