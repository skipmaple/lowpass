# 三主题前端接入与验收

2026-11-05。本次把第二轮确认的 A 层叠清晨、B 双声部、C 展开阅读接入 Rails / Inertia / React 前端，默认 A。保留三套各自的字体、配色、刊头和正文结构，使用同一份路由、数据和交互状态。未提交、推送或部署。

## 实现范围

- 日刊、周刊、归档、收藏、搜索、账户设置、登录／错误页面与应用自有后台。
- 全站外观入口与设置页选择器共用 `lowpass-theme`；首屏预先应用主题，切换保留查询、未提交输入、展开状态和收藏。长文优先锁定当前文章，并在字体完成后校准位置；读者继续滚动时取消迟到的校准。
- 收藏和搜索是独立路由。收藏关键词与来源条件在数据库查询阶段处理，然后分页；不局限于当前页，不越过本人和下架内容边界。
- 日刊中文标题／摘要优先，缺字段保留原始内容；摘要、理由和原文分层。空来源、抓取失败、缺理由均读取真实数据，不复制样刊状态。
- 收藏反馈点名、支持撤销、保留焦点和无障碍播报；撤销确认约两秒消失，后续操作清除前条提示。请求失败仍回滚并给出实际错误。
- 日期展示采用 `/`；图标统一 Lucide 几何和描边。B 主导航与来源导航相接；三套处理窄屏、打印与减少动态效果。

设计规则见 [DESIGN.md](../../../DESIGN.md)。字体来源、OFL 许可、固定校验值和构建方法见 [字体构建说明](../../../vendor/fonts/themes/README.md)。1,100 个字体产物覆盖上游中文字符集，按所选主题和 Unicode 分片请求；不是只覆盖样刊字符的字体。

## 浏览器验收

本地独立 PostgreSQL 18 实例，端口 55432；应用运行在 `http://127.0.0.1:3000`。日刊使用已确认内容的隔离 QA 数据，周刊使用仓库中的真实来源样本；刊期与条目组合不代表当天线上榜单。没有触发模型调用或线上抓取。

| 范围 | 视口／场景 | 结果 |
| --- | --- | --- |
| 三主题日刊、收藏、搜索、周刊、后台、设置 | Chrome 1440 / 390 | 页面、真实操作与对齐通过 |
| 三主题日刊、搜索、周刊、后台 | Chrome 320 / 768 | 边界与布局通过 |
| B 带真实头像账户 | 320 / 390，字体就绪后 | 宽度分别 320 / 390，无横向溢出 |
| 长周刊第 21 条切 A→B | 1440 / 390 | 原阅读锚点偏移 +0.69 / -0.30px |
| 搜索、收藏检索、无结果、取消／恢复、请求失败 | 真实本地路由 | 条件、计数、回滚、焦点通过 |
| 切换主题 | 输入草稿、原文展开、已收藏状态 | 保留；刷新记住主题；Escape 返回入口焦点 |
| 三主题打印媒体 | Chrome 模拟 print | 白底黑字、来源保留、操作隐藏 |
| 收藏撤销反馈 | 390，真实请求 | 点名播报、两秒收起、按钮焦点与原收藏状态恢复通过 |

独立复查抓出的实际问题已修复：320px 导航叠压与外观弹层裁切、真实头像越界、B 无详情结果空白右栏、C 打印深底黑字、A 打印色面残留、长周刊切主题位置漂移。

截图：[A 桌面](../../../.impeccable/verification/production-2026-11-05/lowpass-final-daybreak-desktop.png)、[B 桌面](../../../.impeccable/verification/production-2026-11-05/lowpass-final-duet-desktop.png)、[C 桌面](../../../.impeccable/verification/production-2026-11-05/lowpass-final-unfold-desktop.png)、[窄屏对照](../../../.impeccable/verification/production-2026-11-05/recheck-narrow-grid.jpg)、[B 头像窄屏复测](../../../.impeccable/verification/production-2026-11-05/system-duet-overflow-320.png)、[打印对照](../../../.impeccable/verification/production-2026-11-05/recheck-print-grid.jpg)。

## 自动检查与资源

- TypeScript、449 项前端测试通过。
- Rails：785 tests / 3416 assertions；系统测试：60 tests / 457 assertions，均无失败。
- RuboCop、Vite 生产／测试构建、Brakeman、依赖审计与 diff 检查通过。
- npm 的 Vite / Vitest / undici 和 Ruby 的 crass / net-ssh 使用兼容补丁清除已有告警。修复依据：[Vite](https://github.com/vitejs/vite/security/advisories/GHSA-rq7h-c2jc-7f22)、[Vitest](https://github.com/advisories/GHSA-xp26-3454-mjgp)、[undici](https://github.com/nodejs/undici/security/advisories/GHSA-2m5v-pch6-74hx)、[crass](https://github.com/rgrove/crass/security/advisories/GHSA-pq4g-8rxf-4g29)、[net-ssh](https://github.com/net-ssh/net-ssh/security/advisories/GHSA-qpg5-fx6p-8cq3)。
- Gitleaks 历史扫描通过。新增的唯一豁免是已删除的 `config/weekly_image_positions/2026-W43-416.json`：24 条命中均为生成代码确认的 `key_sha256` 内容摘要。未关闭扫描规则，未修改历史。

| 主题 | 首屏门禁资源，KiB | 当前 QA 日刊首次字体请求，KiB |
| --- | ---: | ---: |
| A | 282.98 | 777.19 |
| B | 282.92 | 753.93 |
| C | 293.69 | 635.73 |

首屏门禁统计 JS、共享 CSS、当前主题内容字体声明 CSS 和壳字体，上限 300 KiB。按既有预算口径，正文 Unicode 字形分片不计入该门禁；右列明确另列实际请求字体文件的总大小，包含壳字体，不应把门禁数值当作完整页面传输量。内容越多、涉及字符越广，请求的分片越多；浏览器可缓存，失败回退不阻断阅读。

本机系统测试需使用 `CI=1 PGPORT=55432 mise exec -- bin/rails test:system`，以正式 CI 模式使用已构建的 `vite-test` 资源。本机非 CI 的 Vite 端口探测曾误认为未运行的开发服务器可用，产生 502；这是已定位的本地运行边界，没有通过跳过系统测试处理。

未验收实体手机、Windows 字形、物理打印／PDF 分页、真实第三方 OAuth 网络往返和第三方任务队列引擎内部样式。周刊当前按文本段落和图片渲染，本轮没有新增富文本代码／引用解析，也没有改变模型内容质量管道。
