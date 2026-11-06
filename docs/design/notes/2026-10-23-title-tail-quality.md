# 带兴趣标签的英文标题末词孤行

T2 的原始真实内容抽查在 320px 发现两例：`Tailwind Labs is joining Shopify` 末行只有 `Shopify`，`Hunting the Wild Vibrotruck` 末行只有 `Vibrotruck`。父 `.item-heading` 的 `text-wrap: balance` 确实生效，但它同时平衡标题和兴趣标签，不能保证标题自身最后一行有两个词。

只在 ItemRow 的日刊带标签、`latinLang(title) === 'en'`、至少两个空白分隔 token 的标题内，声明式包住末两个 token。用原字符串的切片保留所有字符与空白，不换 NBSP、不按特定标题或 id 例外。尾片段使用有界 inline-block 和 `overflow-wrap: anywhere`：通常共同换行，极长组合仍可内部折行。`text-decoration: inherit` 保留父链接的下划线、悬停加深及打印隐藏，不硬写 underline。父 balance、原标题/链接、标题右侧 10px 间距和标签行内规则不变。CJK、单 token、无标签、周刊以及 Search / Favorites 不改结构。

系统回归加载真实 Rails 页面、React ItemRow 与已加载的 Newsreader。未改生产源码时，两例均以预期的实际末词孤行失败；实现后，两例的标题末行均至少两个词，标签仍紧随或整签换至下一行行首。另测 263 字符的超长尾词原文完整、内部折行而不横向溢出。最初候选的 inline-block 阻断了父链接的文字装饰，真实页面的 normal / 原生 hover / print 回归与截图暴露了这处退化；补显式继承后四个目标系统测试共 38 个断言通过。ItemRow 前端 43 个测试通过，覆盖原文空白、链接可读名与 URL、标签不进标题、换文/重复渲染及不变输入分支。

外部证据目录：`typography-final-lines/fix/`。`red.log` 为两个真实失败；`green-with-decoration.log` 为最终四个目标系统测试；`decoration-red.log` 与 `decoration-{red,green}-{normal,hover,print}.png` 保留真实页面三态的失败和修正。`frontend.log` 为 ItemRow 回归；`frontend-attempt-1.log` 保留首次测试可读名预期的 tab/空格差异，修正的是测试预期，生产原文未归一化。首次 decoration 目标命令误选空行导致零测试，保留于 `decoration-line-selector-attempt.log`，不计作 RED；随后按实际测试声明行重跑得到真实失败。

最终完整 CI 通过：456 个前端测试，856 个 Rails 测试 / 3763 个断言，81 个系统测试 / 8082 个断言；首屏 264.69 KB，低于 300 KB，耗时 58.55 秒。首次候选完整 CI 也通过，原日志保留为 `ci-before-decoration.log`；这不掩盖其后来实际发现的下划线退化。最终日志为 `ci.log`。

root 冻结真实 Rails layout/helper 与最终 production build，独立 Chrome 155 在 320/768/1440 重新量同一批 27 条真实内容：97 字段×3，共 291 份原文及字体角色均保持，未再发现标题末行孤词或中文段末行单汉字。72 个实际标签的位置与链接 normal/hover/print 反馈通过。root 另看过两条修复的手机常态/悬停截图与平板、桌面初屏；独立代码审查没有剩余阻塞项。证据在外部 `typography-final-lines/candidate-matrix/`。

触控沿用已批准的 `2026-10-22-title-touch-quality.md:69–70,80`：标签、序号与独立操作保有非链接保护层，不承诺每列或字形中心对称 ±21px 全部可点。最初严格取样仍保留 173/177，四个下沿点均被标签接住；旧版四题相同行/字形点 4/4 同样复现。最终 27 标题各有保护区外的 44×44 内接区域，1936 个像素中心/块，共 52,272 点 `elementFromPoint` 检查通过。这是 DOM 命中几何，不能冒充物理触屏或可信原生点击；没有为本次断行修复撤掉保护层或改写原失败记录。

配对 A4 打印均为 7 页，每页提取全文相同、27 标题完整，37 个链接目的 URI 的集合一致。root 用 Poppler 渲染并查看候选全部 7 页，没有观察到裁切、重叠或异常分页；部分域名/标签像素位置有差异，不宣称截图相同。原子行内内容增加了 PDF 链接矩形，annotation 数量从 43 到 71，目的地址未增加或丢失。

完整 CI 后只补这份说明和计划的接受记录，运行时代码与测试均保持已验版本。此结论限定这批内容与本地独立浏览器，不等同于全站 T2、owner Chrome、物理手机或获奖品质通过。尾两词本身太长时允许内部折行，不能保证任意内容、宽度、字体环境都不剩孤词。本轮不发布、不改已发布内容或模型。
