# 异步正文字体声明去重

原先 `fonts-content.css` 在 97 个文楷分片声明之后，再导入整份 `fonts-subset.css`，借后声明优先保住界面子集。application 本身已包含同一组声明，异步表因而重复携带文楷 UI / extra / admin、Maple 和内联 Bodoni 字体声明。

现在将动态 stylesheet 紧接真实布局的 `data-content-fonts` preload 插入，排在 application stylesheet 前。application 中的界面子集继续后声明，异步表只保留正文分片。字体文件、字符范围和四字体角色均不变。

这是对设计说明 `2026-10-14-award-quality-design.md` D3 中“末尾再声明一遍界面子集”这一实现手段的替换。声明优先级的目标保留，不能把删除 import 单独当作正确性证明。真实布局顺序和实际浏览器选字需要一并验证。

## 构建与回归

以 main 的 `c1f47954` 为基线，使用相同锁文件、Node 24.14.0、Ruby 3.4.8、Vite 8.2.4 和 Zlib 1.2.12，各构建一次 production 包；每个唯一资源分别以 `BEST_COMPRESSION` gzip 后加总。

| 范围 | 基线（B） | 候选（B） | 变化（B） |
| --- | ---: | ---: | ---: |
| 全部 CSS | 51,742 | 47,911 | -3,831 |
| application CSS | 16,809 | 16,809 | 0 |
| 日刊 JS | 132,666 | 132,682 | +16 |
| 全页面唯一 JS | 168,566 | 168,614 | +48 |
| 日刊首屏预算 | 270,911 | 270,927 | +16 |

application CSS 逐字节相同，五个应用字体二进制及三项首屏字体相同。根代理另行复核 76 项唯一 JS/CSS 产物的 SHA、原字节和 Ruby gzip 字节。该收益属于全部 CSS；首屏没有减少。

新 DOM 顺序单测在旧实现为 1 failed / 3 passed，修正后为 4 passed。无 preload、href 原文和幂等检查保留；Rails integration 另检查真实布局中 preload 在 application 前。

完整 `bin/ci` 一次退出 0（67.17 秒）：455 项前端、856 项 Rails（3766 assertions）、77 项系统测试（8044 assertions）；首屏 264.58 KB / 300 KB。现有两项 Vitest moderate 告警保留，high 门禁通过。CI 重建的 production manifest 与浏览器使用的构建一致。

## 浏览器对照

- 使用两份真实 Rails helper / layout 输出、实际 production module 和同一份冻结的 27 条日刊数据。loopback 静态服务返回 UTF-8 HTML，不连接数据库、后台任务或外部内容。
- Chrome 155 的基线 / 候选 × 375px / 1440px × 正常 / 减少动态效果，共八次独立冷加载。前两秒只收 PerformanceObserver 记录，不读取测量用几何、计算样式或字体就绪状态；Playwright 的结束条件轮询只读计时属性。
- 八次均正确解码 UTF-8，DOM 中全部 props、日期、首条译文与理由精确一致；观察窗口内 CLS 均为 0，未捕捉到超过 50ms 的长任务。每格只测一次，不据此推断 LCP 加速或全部生产页面无位移。
- 四对稳定页面的标题字族、几何、21 个字体请求 URL 集合一致，首视口 PNG 逐字节相同。截图与几何在观察窗口及字体就绪之后采集。
- Chrome 155 与 WebKit 26.4 各测试正文表后到、应用表后到两种响应顺序，基线 / 候选共八个有效 fixture context、32 个逐字阶段。保留真实 parser 创建的应用 stylesheet 和应用 module，依次显示 UI「前」、extra「与」、admin「万」、正文「海」，每阶段只新增预期字体分片；四字体角色的样式、资源与像素一致。七组实际字体二进制的 cmap 覆盖探针字符，不用相同的 family 名替代资源证据。
- 上述刻意延迟的 Chrome fixture 初始 CLS 分别约为 0.001041 / 0.001338，基线与候选相同。WebKit 未返回 layout-shift 条目，本轮未独立确认该 API 支持，不据此宣称 CLS 为 0。它们用于字体优先级对照，不属于正常网络冷载八格，不能合并成“全部样本零位移”。
- Firefox 148 未能在本机正常启动：客户端匹配后仍报 macOS sandbox EPERM / SWGL 错误。本轮未绕过沙箱，也不将其计作验收通过；WebKit 使用与本机浏览器匹配的 Playwright 1.59 客户端，额外工具仅装在证据目录。

首轮静态服务没有附带字符集，浏览器按 GBK 解码，造成中文乱码。源 JSON 和 HTML 的 UTF-8 字节正确；修正响应头前后 HTML 字节完全相同。该轮八格已保留并撤出有效日刊布局验收，上述冷加载结果全部来自修正后的独立八格。此前使用同类服务的性能观测也不能推广为正确中文布局的性能证据。逐字 fixture 自带 UTF-8 声明、探针文字正确，因此可独立保留。

## 验收边界

历史 PR #58 按其原工具链重建的全部 CSS 增量仍为 5,655 B，超过原 D4 的 4 KiB。当前候选减少 3,831 B 不能倒改该历史结论。字体迁移与其余 CSS 的反事实归因也不能替代产品验收。

本轮仅修改字体声明位置和相关说明、回归测试；完整 CI 使用既有测试库 fixture / seed 流程。未部署、未调用模型、未修改已发布刊期或历史理由。用户 Chrome、生产及完整获奖品质验收仍待完成。
