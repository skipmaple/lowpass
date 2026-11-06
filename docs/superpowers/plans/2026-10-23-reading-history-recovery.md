# 阅读历史恢复调查与修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 找出并修复从搜索返回日刊后阅读位置丢失的真实原因，保留 D35 同一位置对应同一跨来源进度。

**Architecture:** 先给真实 Rails / Inertia / Chrome 路径添加仅限诊断的事件记录，保留原等待与断言。确定数据流后才新增有区分力的回归与最小产品修复；不把 PR80 重试成功或 PR76 传输清理当作产品修复。

**Tech Stack:** Rails8、React19、Inertia3.7、TypeScript、Chrome / Selenium、Minitest / Vitest。

**Spec:** docs/superpowers/specs/2026-09-08-mvp-prd.md §6.4 / D35；PR80 首轮系统失败的原日志与有效截图。

## Global Constraints

- 从 main c1f47954 独立分支；不包含尚未合并 PR69–80。
- 不弱化五秒等待、两像素位置、来源进度或前进后退验收。
- 不接管读者滚动，不用延时猜测恢复时机，保留不透明框架 history state。
- 不调用模型、生产写操作或真实 OAuth；测试 mock 与本地 fixture 仅限现有授权。
- ROOT 独占默认测试数据库；诊断不得与其他 Rails 任务并行。

## Review Focus

- Back 落在地址更新与异步 DOM 交换之间；页面与 URL 应一致，阅读位置不能被旧访问覆盖。
- 连续 Back / Forward 与第二次跨路径访问；旧过渡收尾不能污染新访问。
- 读者新滚动或焦点选择优先；不能用循环恢复与读者争抢位置。
- 既存 hash / source 回退、减少动态效果、无 ViewTransition 支持时保持既有行为。
- 异常和取消路径应清理监听 / 标记，不能把合成事件等同于真实用户或掩盖首轮失败。

## Task 1: 收集真实事件顺序

- [x] 保存当前源码、原测试和运行环境 pins。
- [x] 原 MotionTest 自然诊断 GREEN1/13；保留真实 ordered trace，不把该次未重现解释成修复。
- [x] 显式受控浏览器调度证明旧100ms记录可将日刊1255写成0，随后core读取0；再用全部RAF同延迟的消费回归排除选择性core gate对实现的偏置。
- [x] 保留原始失败、自然GREEN及受控失败；PR80首轮具体事件顺序仍未证明。

## Task 2: 回归与最小修复（以 Task1 的证据为前提）

- [x] 真实 consumer RED1run10assert1failure，eventTop1255、beforeReleaseTop0、4帧排队、最终Y0；原断言未改。
- [x] 先写helper契约及空接口，unit RED12failed/15passed后实现；root提出原生hash/page.url差异后补unit RED1failed/30passed，再修复route匹配。
- [x] 实现historyScroll：pageTurn重放前捕获；startup安装；matching阅读navigate之后一个可取消RAF纠正位置，保留不透明当前state；新访问/原生pop/输入使旧epoch失效。
- [x] 静态设计评审覆盖nativehash、首页、visit身份、buffer重放与用户输入；独立实现评审P2原生往返反例经4条RED修复，V2复核通过。
- [x] 最终37项聚焦契约/491前端；旧产品两模式RED2/20、候选GREEN2/22；完整CI491/856/79、265.18KB通过。
- [ ] 原生生产构建页面验收、PR Draft 与远端门禁；不部署。

实施边界：frontend/typecheck/build由worker执行；所有Rails、DB、真实consumer GREEN、原Motion回归及完整CI由ROOT独占执行。取消应用纠正不承诺取消Inertia自己的迟到restore RAF；不能把helper输入失效单测写成整个框架已经处理所有迟到输入。
