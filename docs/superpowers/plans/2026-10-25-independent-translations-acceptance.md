# D39 本地验收记录

2026-10-25；用户批准完整设计并进入本地实现（call_15102d88e40046d1b3aa7ea174b94db4）。本记录是本地候选证据，不是发布或模型语义验收。

工作区：`/Users/drewlee/.codex/worktrees/independent-translation-design/lowpass`，基线 `734c78cb7162d2a1943df5e90b6774edf3fd2508`。独立PostgreSQL18测试容器，不启动或修改用户原数据库；模型端点仅WebMock桩，真实密钥为空，无worker、无真实模型请求。CI安全审计会读取公开依赖漏洞信息。

## IT 对应证据

| 要求 | 实际回归入口与边界 |
|---|---|
| IT-01 | `translations/generator_test`：已有译文跳过；原`reasons/generator_test`：同次合规译文保存。独立补全不覆盖 |
| IT-02 | `generate_reasons_job_test`：理由三次invalid后独立译文成功；失败响应译文不保存。`translations/generator_test`：超时后成功 |
| IT-03 | 同一job集成：合法拒写后独立译文，ReasonAbstention保持；`item/translating_test`保留字段/时间 |
| IT-04 | generator的GitHub用例保留已有理由与项目名，仅译简介；同操作最多3次 |
| IT-05–06 | generator：unchanged一次终态、普通重放零新增请求、显式重评失败保留标记、成功删标记、已有译文不覆盖 |
| IT-07 | generator/job/counts：空画像仍译；未配置无调用；后台操作独立ready |
| IT-08–09 | generator、model_requests、原provider/reasons测试：预算/限流/拒绝/超时/invalid真实计账与停止；零上限语义保持 |
| IT-10 | model_requests：独立PG连接争门与异常释放；独立连接写账后门内读取新预算；两目的均经过该门。generator：重放3次与成功保存异常不重调。此为数据库互斥及消费测试，不是供应商exactly-once证明 |
| IT-11 | generator：无旧理由/旧拒写也复用；纯名称保留复用；跨源/改原文/不合规旧译文不复用 |
| IT-12 | generator：请求中改原文/隐藏/改源类型/删除/重抓换id，旧输出丢弃、账本保留；原Item/Issue内容快照保持 |
| IT-13 | triggers/job：当日发布、重抓实际新id、历史日期、跨午夜、旧消息默认空范围、7天到期/Busy重排；既有tick/迁移无新触发路径。没有用真实历史数据试跑 |
| IT-14 | preview/controller：绑定用户/期/选项/目标、篡改和过期拒绝、重复POST同键冻结范围、成员403/周刊与空刊404；system开启CSRF后真实提交 |
| IT-15 | parser/preservation/item测试：300/500边界、额外键/数组/围栏/无汉字/半截JSON拒绝；DB直接约束；失败保持旧值 |
| IT-16 | system无reason独立显示译文；ItemRow与Favorites前端沿用原位置；收藏控制器按title/summary分别匹配、快照不变；搜索读取当前Item的既有路径保持 |
| IT-17 | counts/status：总次数/费用含两目的且分项；单条理由控制器只取reason账本；理由计数/告警回归 |
| IT-18 | translation_preservation/translation_call_metadata/model_call测试直接写DB约束；新迁移只新增表与元数据，不回填译文；删除级联 |
| IT-19 | `fixtures/files/translations/accepted_samples.json`冻结10条编辑参考，含用户4个箭头标题及否定/计划/问句/引用/混排/纯名称；`accepted_samples_test`验证Prompt字段、解析与保存。参考为人工合成回应，绝不代表模型翻译质量已通过 |
| IT-20 | 完整bin/ci已通过：632前端、992 Rails/4575断言、133系统/9922断言，首屏267.54KiB≤300KiB；浏览器1400与精确375px验证对话框、键盘循环/取消返回、提交禁用、CSRF、排队提示。不是Windows或真实手机验收 |

## 已完成的定向验证

- Task1：17 tests / 89 assertions。
- Task2：101 tests / 564 assertions，包含原理由兼容。
- Task3：73 tests / 361 assertions。
- Task4：113 tests / 451 assertions。
- Task5：前端5文件124项；Rails/系统合计39 tests / 203 assertions；类型检查与定向Rubocop通过。精确375px通过CDP设置并检查innerWidth与无溢出，不能把Chrome窗口尺寸当成实际viewport。

本地浏览器首次失败的原因是ViteRuby对localhost3037误判有开发服务，模块代理返回502。设置CI=1，使用库自带CI路径读取已构建测试产物后通过；没有修改用户代理设置，也不据此解释生产iPhone问题。

## 仍需另行证明

当前生产原有缺译文不会因本地候选自动消失。真实有限模型语义、指定历史期补全、合并与自动部署需要相应授权和当时的最新验证。供应商未知usage、请求后落账前崩溃及最后一笔跨月上限等边界不能由本地账本保证。

iPhone生产黑屏、真实Windows Chrome、M2首次呈现帧/自然pending历史取消及原237.879ms等待证据等全局缺口仍未关闭。本轮功能完成不能替代完整八项获奖品质目标，也不将原冻结60项验收缩成此功能。

## 完整 CI（独立审查前）

命令：`CI=1 DATABASE_URL=<隔离库> env -u RAILS_ENV -u RACK_ENV bin/ci`，2026-10-25本地运行，3m59.98s全绿。632前端/992 Rails/133系统，安全检查、依赖审计、seeds及267.54KiB首屏门禁均通过。日志为 `independent-translations-implementation-20261025/offline-evidence/task6-ci-corrected.log`；该目录位于本会话既有visualizations证据根。旧失败日志同时保留，不覆盖为成功。独立整支审查尚待完成，候选未发布。
