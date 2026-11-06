# Lowpass 三主题前端技术选型调研

日期：2026-11-04。状态：技术推荐，尚未安装到产品、实现或上线。

## 1. 结论与选型依据

推荐 **Base UI + CSS 设计令牌 / Tailwind CSS + Motion + 自托管字体（Fontsource / 官方上游）+ Lucide React**。A、B、C 共用交互行为和内容模型，分别实现三种完整的版式与视觉语言；默认 A。

本次按用户最新要求，**从产品目标和已确认的三主题设计出发，不把现有前端代码、已安装依赖、复用比例或迁移成本作为选型依据**。先比较适配程度，再讨论性能成本。此前检查过的现有实现不参与下表排序。

评估顺序：能否完整表达三种设计 → 阅读与操作是否连续 → 手机和电脑是否同样自然 → 无障碍与性能 → API 稳定性与维护成本。项目声明的 300 KiB 首屏预算作为工程约束保留，不能靠不统计新字体绕过。

用户已确认的事实：保留三个主题、默认 A；保留来源榜单与顺序、按天阅读、原文与译文、收藏与搜索；推荐理由应由正文内容支持。下文的具体 package、字体字重、间距、时长和切换实现均为本轮工程推荐，不冒充已经确认或交付的功能。

| 能力 | 主选 | 使用边界 |
| --- | --- | --- |
| 基础交互组件 | **`@base-ui/react` 1.9.0** | Popover、Radio、Dialog、Drawer、Collapsible、Menu、Field、Toast 等按需取用；页面构图自行设计 |
| 排版、留白、层次、响应式 | **原生 CSS Grid / Flex / 容器查询 + Tailwind CSS 4** | CSS 变量定义语义令牌；组件决定布局；不另引入 JS 栅格系统 |
| 动效 | **CSS transitions + `motion` 14.9.1** | CSS 负责基础反馈；Motion 负责局部展开、退出与编排。采用 `LazyMotion` + `m` + `domAnimation` |
| 字体 | **A：寒蝉圆黑体 + Bricolage Grotesque；B：寒蝉锦书宋 + Newsreader；C：未来荧黑 + IBM Plex Sans** | 三套独立中英字体组合；代码/仓库标识共用 IBM Plex Mono；按主题、角色和字符范围自托管加载，系统字体仅作回退 |
| 图标 | **`lucide-react` 1.68.0** | 直接使用按名导入的 SVG 组件；通过描边与尺寸适应主题 |
| 色彩计算 | **`colorjs.io` 0.7.1，仅开发工具** | 计算对比度、生成与检查色阶；产出静态 CSS，不把计算库带给读者 |
| 主题状态 | **小型、独立的 ThemeProvider + 首次绘制前的主题初始化** | 三主题白名单、默认 A、偏好保存、内容锚点恢复；布局变化属于产品自身能力 |
| 验收工具 | **Playwright + `@axe-core/playwright`** | 三主题视觉回归、键盘/焦点、响应式与无障碍扫描；只作为开发依赖 |

Base UI 是无样式、可按用量打包的基础组件，提供键盘、焦点和指针行为；字体、间距、颜色与页面构图仍由 Lowpass 自己定义。[组件说明](https://base-ui.com/react/overview/quick-start)、[无障碍边界](https://base-ui.com/react/overview/accessibility)

## 2. 三个主题分别怎样落地

| 维度 | A：层叠清晨 / daybreak | B：双声部 / duet | C：展开阅读 / unfold |
| --- | --- | --- | --- |
| 核心构图 | 明亮阅读面、几何刊头、色面章节横带 | 黑白双列、中央序列、逐条内容与价值对读 | 哑光深色、细长日期、偏置阅读面、展开线索 |
| 布局技术 | Grid 构建刊头与章节；正文连续流 | 每条 article 内部 Grid；桌面左右对位，手机逐条上下排列 | Grid 构建来源侧栏与主文；Collapsible 承载原文线索 |
| 英文体系 | Bricolage Grotesque：宽厚刊名、有表情的字形；正文采用较小光学尺寸 | Newsreader：屏幕连续阅读的衬线体；与中文宋体形成同一编辑语气 | IBM Plex Sans：正文 Normal，刊期使用真实宽度轴收窄；保留清晰的技术信息层次 |
| 中文体系 | 寒蝉圆黑体：标题 700、正文 400；温和而不过度可爱 | 寒蝉锦书宋：标题 Bold 700、正文 Text Regular 400；宋体细节支撑逐条对读 | 未来荧黑 SC Normal：标题 Bold 700、正文 Regular 400；收敛字面配合深色阅读面 |
| 留白特征 | 章节间距最大，条目内部紧密 | 列间留白明确，条目垂直节奏规整 | 侧栏与阅读面之间留出空间，展开区层级分明 |
| 色彩任务 | 青蓝、松绿提供识别；赭金作为色面 | 墨黑与白建立强对比；细灰线只做辅助结构 | 石墨背景、米白正文；黄铜作为链接和当前锚点 |
| 动效性格 | 章节边界进入视野时轻微、一次性的位移反馈 | 明确而短促的选中、下划线和焦点反馈 | 展开与收起有连续过程，可立即反向操作 |
| 手机上 | 色面横带保持；导航自然溢出；刊头缩小 | 同一条内容、理由、操作顺序排列；不横向滚动读正文 | 侧栏收为来源导航；线索在原条目下展开 |
| 主要组件 | Popover、RadioGroup、Menu、Toast | RadioGroup、Popover、Field、Dialog | Collapsible、Popover；移动端设置使用 Drawer |

三套主题都使用同一组收藏、搜索、主题选择和错误反馈组件。C 的条目展开是 **文档内的 disclosure**，不把每篇内容放进模态抽屉。Drawer 用于手机上的外观设置、过滤条件等短操作。

## 3. 基础组件库比较

| 候选 | 独立优势 | 对 Lowpass 的代价 | 结论 |
| --- | --- | --- | --- |
| **Base UI 1.9.0** | 无样式；Popover、Drawer、Collapsible、Field 等在一个组件体系内；可取消的 CSS 过渡；覆盖手机虚拟键盘与焦点细节 | 相同类别的基础控件组合较重；需要设计自己的完整视觉层 | **主选**。适合三种视觉语言、手机与电脑、阅读与后台操作共同建设 |
| **Radix UI 1.8.1** | 无样式、组合粒度细；键盘与焦点基础完善；本轮基础控件组合体积最低 | 原生组件目录没有与 Base UI 同级的 Drawer；若需要手势抽屉，需补实现或引入另一方案 | **备选**。若手机操作最终只用普通 Dialog，可成为更轻的选择 |
| **React Aria Components 1.22.1** | 无样式；触摸、键盘、辅助技术与国际化能力完整；相同类别组合的体积接近 Radix | 国际化复杂输入、集合组件等能力在当前产品中的收益有限；仍需完整视觉设计 | **备选**。复杂日期输入、国际化或集合交互增多时更有优势 |
| **shadcn/ui** | 提供可修改的组件源代码，适合快速搭建基础包装 | 直接照搬默认样式会弱化三主题的区别；复制代码后仍需自行维护 | **作为参考和代码分发方式**，不作为视觉定稿；不批量导入整套页面 Blocks |

主选 Base UI 的理由是整站所需行为的覆盖和一致性，不是体积最小。三者都能完成基本功能，没有证据表明某一家天然能让 Lowpass 的页面更漂亮；视觉效果要由排版与组件设计完成。

Base UI 当前稳定版本为 1.9.0，2026-10-09 发布；Drawer 已在 1.3.0 转为稳定，其后持续处理手势、虚拟键盘和焦点问题。本轮不采用 preview API。[发布记录](https://base-ui.com/react/overview/releases)、[Drawer](https://base-ui.com/react/components/drawer)、[表单](https://base-ui.com/react/handbook/forms)

另外两个候选的能力依据：[Radix Primitives](https://www.radix-ui.com/primitives/docs/overview/introduction)、[React Aria](https://react-aria.adobe.com/)。shadcn/ui 的定位是开放组件源代码及其分发方式。[官方介绍](https://ui.shadcn.com/docs)

不选 MUI、Ant Design 或 Mantine 作为整站的视觉基础：本次核心是三套强烈不同的刊物布局，预设的表面、密度、阴影和页面结构不是我们希望优先继承的部分。这是项目适配判断，不是认定这些库无法定制。

## 4. 排版、留白与视觉层次

这里主选 CSS，不另安装“自动排版”或“自动留白”运行库。布局需要忠实表达内容关系；自动均分高度、拼贴瀑布流和逐词拆分都不适合来源有序的阅读。

建议先固定以下令牌，再用真实内容调整数值：

| 层级 | 初始建议 | 目的 |
| --- | --- | --- |
| 正文 | 手机 17–18 px；桌面 18–19 px；行高 1.75–1.9 | 中文与英文仓库名混排时仍能连续阅读 |
| 条目标题 | 手机 22–26 px；桌面 26–32 px；行高 1.3–1.45 | 长标题自然换行，不靠截断保持整齐 |
| 理由 | 15–17 px，独立标签与间距 | 让“是什么”和“为什么值得看”可以分别扫读 |
| 元信息 | 12–14 px，保证对比度 | 排名、来源、时间与讨论数低于正文，但仍可读 |
| 阅读行长 | 桌面约 28–38 `ic`；手机随可用宽度，通常约 18–22 个汉字 | 用中文字符宽度控制阅读行长 |
| 间距标尺 | 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96 px，再映射语义变量 | 明确条目内部、条目之间、来源之间三种距离 |

`ic` 以当前字体中汉字“水”的字宽为依据；`ch` 依据数字字符宽度，不能把英文常见的 `65ch` 直接当作 65 个汉字。[CSS 长度单位](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/length)

- 字号用 `clamp()` 做有限范围的流式变化；正文不随整个视口无限放大。
- 中文设置合适的 `line-break`；正常文本保留自然断词，只有长仓库路径、URL 等使用 `overflow-wrap: anywhere`。
- 标题可以渐进增强使用 `text-wrap: balance`，正文按浏览器支持使用 `pretty`；不依赖它们保证布局成立。
- B 的每条内容保持单独 article，内部共用网格列；理由缺失时收起该区域，不做空面板，也不把左右两列拆成两份独立列表。
- 共享按钮等组件按容器宽度变化，站点导航按视口变化。Tailwind 4 已包含容器查询能力，无需额外 container-query 插件。[响应式文档](https://tailwindcss.com/docs/responsive-design)

`@tailwindcss/typography` 0.5.20 **不列入首批依赖**。它适合排版外部生成的 HTML 长文；Lowpass 的条目标题、摘要、理由及操作需要精确区分。将来周刊接入更丰富的 HTML 时，可仅在正文容器使用，重新定义中文行距、颜色和宽度，操作区用 `not-prose` 隔离。[Typography 官方说明](https://github.com/tailwindlabs/tailwindcss-typography)

## 5. 中英文字体重新选型

本节按用户补充意见重写：中文、英文都可按 A/B/C 分别配置，优先符合主题气质。**系统字体不再承担设计主选；英文也不再统一套用同一款窄体。** 三套字体现已应用到既有 A/B/C 的日刊、收藏搜索、后台九个预览页，保留原有布局；提供 1440 px 桌面与 390 px 手机整页对照。仅更新设计预览，尚未修改生产页面。整页对照：`.impeccable/mocks/round2/typography.html`；交互预览：`.impeccable/mocks/round2/index.html`。

### 产品背景如何影响字体

Lowpass 的价值是把技术信息变成可以理解、收藏和再利用的一期阅读。因此字体要同时完成三件事：让中文解释值得细读；让英文仓库名、框架和 API 不显得像异物；让来源、理由与操作保持清晰。设计感来自文字的语气、比例和节奏，不靠把整篇正文换成装饰字或等宽字。

A 的亲近感、B 的编辑感、C 的技术阅读感分别采用不同字体；不因任何字体已出现在旧代码中而加分或减分。下述匹配判断是设计推荐，文件版本、字重与字体轴则来自实测。

### 三套完整搭配

| 角色 | A 层叠清晨 | B 双声部 | C 展开阅读 |
| --- | --- | --- | --- |
| 中文主字体 | **寒蝉圆黑体 Chill Round Gothic** | **寒蝉锦书宋 Chill Jinshu Song** | **未来荧黑 Glow Sans SC Normal** |
| 英文主字体 | **Bricolage Grotesque** | **Newsreader** | **IBM Plex Sans** |
| 刊名 / 大字 | Bricolage 800，常规宽度，较大的光学尺寸 | Newsreader 700–800，适合显示字号的光学尺寸 | Plex Sans 300，宽度轴约 75%；只将细字用于大字号 |
| 中文条目标题 | 圆黑 Bold 700，约 26–30 px | 锦书宋 Bold 700，约 26–30 px | 荧黑 Bold 700，约 26–30 px |
| 中英正文 | 圆黑 Regular 400 + Bricolage 400，英文光学尺寸约 18 | 锦书宋 **Text Regular 400** + Newsreader 400，英文光学尺寸约 18 | 荧黑 **Regular 400** + Plex Sans 400，正文保持正常宽度 |
| 正文节奏 | 17–18 px，行高约 1.8–1.85 | 18 px 起，行高约 1.85；较小的宋体标签需单独检查 | 18 px 起，行高约 1.9；深底不自动把所有正文加粗 |
| 仓库标识 / 命令 / 代码 | 三主题共用 **IBM Plex Mono 400**，仅用于这类确有辨识需求的内容；普通英文段落仍用本主题主字体 | 同左 | 同左 |
| 配对理由 | 圆角汉字降低硬朗感；Bricolage 的宽厚轮廓保留 A 的几何刊头和轻快性格 | 中文宋体与英文阅读衬线共同表达“正文与解释经过编辑”；黑白双列仍是构图主体 | 收敛的中文结构与 Plex 的理性字形相配，适合技术名词和深色阅读；不靠终端式等宽正文制造科技感 |

**A 的选择**：寒蝉圆黑体是对思源黑体进行圆角处理的字族；保留汉字结构，标题处能看到明显的温和感。Bricolage 具有字重、宽度与光学尺寸轴，小光学尺寸会收敛其显示字的表情，适合与较平静的正文搭配。圆角只体现在字形，不要求把整站控件全部做成胶囊。[寒蝉圆黑体作者仓库](https://github.com/Warren2060/ChillRoundGothic)、[Bricolage 作者说明](https://github.com/ateliertriay/bricolage)

**B 的选择**：寒蝉锦书宋调整了思源宋体的圆角、字重比例与排版细节；正文明确选 Text Regular，标题选独立 Bold。Newsreader 的作者把它定位为内容丰富场景中的连续屏幕阅读字体。这一组的价值在于段落与对读，不是给 B 加纸纹或复古装饰。B 的英文刊名由原窄黑体改为有分量的阅读衬线，这是本轮字体细化建议，保留黑白和逐条对读结构。[寒蝉锦书宋作者仓库](https://github.com/Warren2060/ChillJinshuSong)、[Newsreader 作者说明](https://github.com/productiontype/Newsreader)

**C 的选择**：未来荧黑的中文字面与中宫较收敛，具有粗度、宽度系列；本轮只选简体中文 **SC Normal**，不把正文压窄。Plex Sans 在字形与宽度上的变化用于建立安静的技术信息层次，窄宽度只给刊期等大字。实际样张中，荧黑 Book 500 搭配 Plex 500 的深底段落显得过重，已改为两者 Regular 400；不是机械执行“深色主题加一档字重”。[未来荧黑作者说明](https://github.com/welai/glow-sans)、[IBM Plex 官方仓库](https://github.com/IBM/plex)

### 英文字体的交付方式

| 主题 | package / 上游 | 本轮核对版本 | 字体文件中的轴 |
| --- | --- | --- | --- |
| A | `@fontsource-variable/bricolage-grotesque` | 5.3.0 | `wght` 200–800，`wdth` 75–100，`opsz` 12–96 |
| B | `@fontsource-variable/newsreader` | 5.3.0 | `wght` 200–800，`opsz` 6–72 |
| C | `@fontsource-variable/ibm-plex-sans` | 5.3.0 | `wght` 100–700，`wdth` 75–100 |
| 代码标识 | `@fontsource/ibm-plex-mono` | 5.3.0 | 选 400 静态字重 |

本轮实际读取 `*-latin-standard-normal.woff2` 中的轴，而不是只看“variable”包名。仅导入 `wght` 文件不代表同时保留了 `opsz` 或 `wdth`；Plex Sans 也不能把不存在的光学轴写入设计规范。选用真实的宽度轴，避免 `transform: scaleX()` 把文字几何压扁。

### 中文上游、许可与版本

中文字体从作者仓库取得，再以 **FontTools + Brotli** 生成自己的 WOFF2 / unicode-range 资源；不假定每款中文字体都有作者维护的 npm 包，也不依赖不明来源的字体 CDN。

| 字体 | 本轮实际读取的字体版本 | 需要说明的边界 |
| --- | --- | --- |
| 寒蝉圆黑体 | 字体头 `Version 3.750`，Regular 400 / Bold 700 | 作者源文件与提交 SHA 已记录；本轮样本字符全部覆盖，不代表验证了完整字库 |
| 寒蝉锦书宋 | **Pro 目录中的 v1.700**，Text Regular 400 / Bold 700 | Releases 的最新标签为 `GBv2.0`，与仓库内 Pro v1.7 不是同一份交付物；本轮不把 1.7 样张冒称为 2.0 验证 |
| 未来荧黑 | 官方 release `v0.93`，SC Normal Regular 400 / Bold 700 | 上游仓库已归档；字体仍可用于固定版本交付，但后续缺字或字形修复需要自己评估，正式纳入前扩大真实内容抽查 |

三套中文字体、三套英文主字体和 Plex Mono 本轮核对的字体许可均为 **SIL OFL 1.1**。特别注意：未来荧黑仓库的程序代码显示 MIT，**字体文件采用 OFL**，不能直接复制 GitHub 顶层许可证标签作为字体许可。自托管保留版权与许可；子集或实例化属于修改时处理保留名称要求。样张的中文子集已使用独立的 proof 家族名，并附作者许可。

### 混排与阅读规则

- 字体栈先放本主题英文，再放本主题中文；中文全角标点由中文字体承担。通过字符范围和实际字形检查，避免引号、破折号等标点意外换成不协调的字形。
- 简体中文使用对应 SC / Pro 简体资源，不能只因字形漂亮就套用日文或繁体版本。
- 英文与中文按实际视觉大小调校；不把相同 CSS 字号当作已经匹配。正文不通过逐词 span 或拆字动画破坏复制、搜索和辅助技术阅读。
- 标题不做假粗体；正文不做假斜体。用 `font-synthesis: none` 暴露未提供字重的问题，并在最终资源清单中补齐实际使用的字重。
- 仓库路径、命令、版本号测试 `0/O`、`1/l/I` 和斜杠；代码使用 Plex Mono，普通英文与数字不一概改成等宽体。数字列另检查字体实际支持的 tabular figures。
- 浏览器存储、网络或字体加载失败时才回退到合适的系统 sans / serif；系统字体不再决定主题的常态外观。

### 加载成本：先做字体工程，不能以系统字体代替选型

上一版用 Noto 样本的下载估算，过早把系统字体提升为主选，这项结论现已撤回。大体积说明需要分片、选字重和缓存，并不等于中文必须放弃设计。300 KiB 门禁仍保留；本轮不宣称新方案已通过整站预算。

全轴 latin 文件实测：Bricolage **128.5 KiB**、Newsreader **128.9 KiB**、Plex Sans **64.0 KiB**。为判断可行的交付形式，另以 FontTools 冻结实际角色所需的轴，保留该 latin 文件的完整字符集，得到以下独立实例：

| 角色实验 | 实例参数 | WOFF2 |
| --- | --- | ---: |
| A 英文正文 | Bricolage：400 / 宽度 100 / 光学尺寸 18 | 22.0 KiB |
| A 英文显示字 | Bricolage：800 / 宽度 100 / 光学尺寸 72 | 21.8 KiB |
| B 英文正文 | Newsreader：400 / 光学尺寸 18 | 21.1 KiB |
| B 英文显示字 | Newsreader：700 / 光学尺寸 48 | 23.7 KiB |
| C 英文正文 | Plex Sans：400 / 宽度 100 | 21.3 KiB |
| C 英文标题 | Plex Sans：600 / 宽度 100 | 23.0 KiB |
| C 刊期大字 | Plex Sans：300 / 宽度 75 | 23.0 KiB |

这些是交付方案实验，不是最终页面字重清单；生产实现必须保证它所用的每个角色都能找到真实字重。可变版与按角色实例化版应根据总下载量选择，不能认为可变字体一定更小。

中文验证样张使用 205 个非 Latin-1 测试字符，六个中文字重均未发现缺字。它的子集只覆盖这张样本，**不能作为新闻内容字库，也不能拿样本几十 KiB 的结果宣称整站达标**。未来荧黑同样字符的子集比另外两款大，后续需重点检查首屏字重范围与字体开销。

生产交付建议：静态 UI 常用字子集 + 内容字库 unicode-range 分片；只加载所选主题，按角色避免无用字重。按字体文件内容哈希缓存，保留完整缺字回退。浏览器可能为已经排版的屏外内容请求字体，因此必须统计实际请求，不能把“在屏幕下面”误认为“尚未加载”。FontTools 提供按文字/字符范围子集化及 WOFF2 输出；需要保留字体的布局特性和标点行为。[FontTools 官方文档](https://fonttools.readthedocs.io/en/latest/subset/index.html)

### 比较过但未主选的方向

| 候选 | 本次判断 |
| --- | --- |
| Noto Sans SC / 思源黑体原版 | 字库与基础排版适合作为基准和缺字回退；三主题希望获得更鲜明的字形语气 |
| 霞鹜文楷 / 朱雀仿宋 | 手写感或书卷气较突出，容易把这次技术刊物引向个人手记或古典文本；朱雀的预览版本状态也需单独处理。作为备选，不因旧站用过某款就沿用 |
| 霞鹜新致宋 / 新晰黑 | 有辨识度，但 IPA 衍生字体的嵌入要求比本轮 OFL 方案多；本轮优先可明确自托管、子集化的组合 |
| 得意黑等强显示字体 | 可用于个别大字实验，不承担大量技术标题、正文和后台控件 |
| Barlow Condensed 全主题通用 | 会把三套英文语气拉得过近；本轮拆成三个独立英文主家族 |

候选与许可证边界依据：[朱雀仿宋上游](https://github.com/TrionesType/zhuque)、[霞鹜 IPA 系列嵌入须知](https://github.com/lxgw/lxgw/blob/main/documents/xizhi_embedding_instructions.md)。上表的风格判断属于本次设计评估。

### 本轮可检查的成果

字体对照：[本地样张](http://127.0.0.1:51935/type-study/index.html)。这是等内容的字体研究页，不是用独立 demo 替代真实产品建设。原 A/B/C 方向草图未被覆盖。

已在 Chromium 渲染 1440 px 桌面及 390 px 手机样张，检查真实字体加载、样本字符覆盖、混排、长标题和横向溢出。B 的手机英文刊名缩至 62 px；C 的正文从 500 调为 400。Windows、iPhone 真机、长篇周刊和全量动态字库仍需在实施时验证。

证据位于 `.impeccable/research/2026-11-04-type-study/`：上游版本与提交、下载哈希、字体头与轴、样本子集报告、英文实例化体积及构建脚本。样张与作者许可位于 `.impeccable/mocks/type-study/`，截图位于 `.impeccable/review/type-study/`。

## 6. 色彩与层级：保留配色，重新分配角色

主选 CSS 自定义属性，色阶可用 OKLCH 调整，再用 `colorjs.io` 离线检查输出；不在用户浏览器里实时计算配色。至少定义 `canvas`、`surface`、`text`、`text-muted`、`border`、`accent`、`focus`、`danger`，避免同一个“金色”同时承担装饰面和小字。[Color.js 对比度能力](https://colorjs.io/docs/contrast.html)

本轮使用草图里的实色做 WCAG 对比度计算：

| 组合 | 对比度 | 使用判断 |
| --- | ---: | --- |
| A 青蓝 `#075B63` / 奶油 `#FCFAF2` | 7.48:1 | 可以承担文字与主要操作 |
| A 松绿 `#203F31` / 奶油 | 11.06:1 | 正文或较重标题清晰 |
| A 赭金 `#C99D47` / 奶油 | **2.39:1** | 只作色面或非必要装饰；不作正文、小字或唯一的焦点指示 |
| A 松绿 / 赭金 | 4.62:1 | 可作为色面上的文字；透明度和小字渲染另验 |
| B 墨黑 `#151515` / 白 `#FDFDFB` | 17.93:1 | 明确主文层级 |
| B 灰线 `#E8E8E5` / 白 | 1.21:1 | 装饰分隔可用；不可独自表示控件边界和焦点 |
| C 米白 `#E8E7E1` / 深底 `#121415` | 14.91:1 | 正文可读 |
| C 黄铜 `#CEB573` / 石墨面 `#24292C` | 7.34:1 | 可用于链接、锚点与状态文字 |
| C 石墨面 / 深底 | 1.26:1 | 靠间距、标题与必要边界共同表达结构 |

普通文本以 4.5:1、大字以 3:1 为最低对比度标准；实际成品还需检查透明叠加、悬停、禁用状态和焦点，不能仅凭几组颜色通过就宣称整站合规。[WCAG 文本对比度](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)

## 7. 动效与微交互

选 Motion 的原因是 React 状态驱动的展开/退出编排；基础 hover、focus、按压和颜色反馈仍由 CSS 完成。Base UI 暴露进入、退出状态，并支持 CSS 和 Motion；可中断的 transition 适合用户快速开关，避免排队播放。[Base UI 动画机制](https://base-ui.com/react/handbook/animation)

| 动作 | 推荐方式 | 初始调校范围 |
| --- | --- | --- |
| A 来源章节进入视野 | IntersectionObserver + CSS；章节标题、线和首条保持为稳定单元 | 约 220–280 ms，位移 6–10 px；正文始终可读 |
| B 条目聚焦、收藏反馈 | CSS 下划线/颜色；局部图标状态变化 | 约 120–160 ms，不让整行漂移 |
| C 原文线索展开 | Base UI Collapsible；需要协调退出时使用 Motion | 约 200–280 ms，布局只影响当前区域，可中途反向 |
| 主题选择 | Radio 的选中反馈；必要时短颜色过渡 | 正文直接进入目标版式；不把整页文本飞散或隐藏等待 |
| 手机外观/筛选 | Base UI Drawer，自定义 A/B/C 外观 | 触摸、键盘和关闭按钮都可操作；手势不是唯一入口 |
| 收藏请求 | 立即反馈意图，成功保持状态，失败回退并说明 | 防重复提交；取消与恢复有清楚结果，不用装饰动画掩盖失败 |

Motion 只用 `LazyMotion` + `m` + `domAnimation`，默认不选 `domMax` 的拖拽、布局动画能力。本轮隔离测试该组合约 32.0 KiB gzip；`motion` + `AnimatePresence` 约 46.2 KiB。`motion/react-mini` 约 3.3 KiB，适合明确的 WAAPI 动画，但不能等价替代完整的 React 布局、退出和手势能力。[Motion 体积与功能分包](https://motion.dev/docs/react-reduce-bundle-size)

普通弹层优先 CSS；仅需要编排的区域才加载 Motion。动态 import 如果挂载后立即请求，仍应计入首次加载网络账，不能称为零成本。

`prefers-reduced-motion` 下取消位移、弹性、视差和非必要过渡；界面直接进入最终状态。图标采用 Lucide React，自定义尺寸和描边；收藏形态变化足够简单，不为每个图标安装全套 morph 引擎。[Lucide React](https://lucide.dev/guide/react)

暂不选：

- **GSAP / ScrollTrigger**：当前没有复杂时间线、钉住页面或长滚动叙事需求；它的能力没有对应收益。GSAP 使用自己的 Standard No Charge License，不将其误列为 MIT。[许可](https://gsap.com/community/standard-license/)
- **Lenis**：本轮保留浏览器原生滚动。它提供平滑滚动、锚点等配置，但引入新的滚动协调层会增加阅读锚点、触摸和历史恢复的验证工作；这是本项目的取舍，不是声称它不能处理这些场景。[官方说明](https://github.com/darkroomengineering/lenis)
- **AutoAnimate**：自动对增删移动的子元素补动画，控制粒度不符合内容到达、缺理由回退和用户主动展开需要区分的要求。[触发机制](https://auto-animate.formkit.com/)
- **通用炫技组件合集、逐字入场、鼠标追光、3D 卡片**：没有帮助理解来源与内容的作用，不作为“有设计感”的默认来源。

## 8. 三主题架构与响应式

使用一套语义内容组件、一套业务状态和三份主题样式/必要的布局变体。主题挂在 `html[data-theme="daybreak|duet|unfold"]`，确保 portal 中的弹层也能读取同一组令牌。浅色主题设置 `color-scheme: light`，C 设置 `dark`，让原生输入控件跟随。

ThemeProvider 只负责合法值、默认 A、同浏览器偏好保存及订阅。首次绘制前完成主题读取，存储不可用或非法值都回到 A；是否有 SSR 都应验证首屏不闪白。不能等 React effect 执行后才第一次选择主题。

`next-themes` 0.4.6 支持任意主题名、data 属性和关闭系统偏好，且体积仅约 1.5 KiB；它并非只能用于 Next.js。但它不解决三种版式的阅读定位，也需要额外处理非法偏好与应用的首次绘制时机，所以本轮选择小型独立控制器。若后续应用框架与其首屏脚本机制自然匹配，可直接替换这一层。[配置说明](https://github.com/pacocoursey/next-themes)

切换不通过重载页面或给整棵树设置 `key={theme}` 实现。记录当前条目稳定标识与条目内相对位置，重排后恢复该内容锚点；保留搜索、收藏、展开状态与未提交表单。视觉主题不产生新的推荐或过滤结果。

响应式按内容断点设计：

- B 在双列最小可读宽度不足时整条改为纵向；DOM 顺序始终是标题、简述、理由、操作。Grid/subgrid 只是对齐手段，不用 CSS `order` 颠倒读屏顺序。
- C 来源侧栏在窄屏收起，展开内容回到文档流；不让手机出现两个嵌套的正文滚动区。
- 来源数量可配置，导航可自然溢出，但正文页没有横向溢出；仓库名与长链接可断行。
- 触控操作区以 44×44 px 作为本产品舒适度目标；WCAG 2.2 AA 的目标尺寸条款是 24×24 px 且有例外，不能把 44 px 错写成该条款的硬要求。[目标尺寸说明](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)
- 使用动态视口与安全区处理手机抽屉；虚拟键盘打开时，当前字段和提交操作仍可见。
- 打印时使用适合纸张的统一浅色排版，展开必要的阅读信息，隐藏交互按钮；C 无需打印黑底。

Tailwind 4 的基础浏览器目标为 Chrome 111、Safari 16.4、Firefox 128；更晚支持的 CSS 特性应提供正常布局回退。浏览器能力和尺寸测试都不能被单次 Chrome 桌面截图代替。[兼容性说明](https://tailwindcss.com/docs/compatibility)

## 9. 隔离测量证据与性能边界

在临时目录安装固定版本，使用 esbuild 0.28.2 进行 ESM production 构建、minify、target es2022；React / ReactDOM external，gzip level 9。导出指定组件集合以保留代码。**这是库入口的增量量级比较，不是 Lowpass 成品构建，也不是交互性能实测。各库 API 覆盖不完全相同，不能据此精确排名运行时效率，不能将这些 gzip 数值简单相加作为首屏结果。**

| 导入集合 | gzip |
| --- | ---: |
| Radix：Dialog、Popover、RadioGroup、Collapsible | 32.2 KiB |
| React Aria：上述相应功能及所需的 Modal、Trigger、Button 等导出 | 37.0 KiB |
| Base UI：Dialog、Popover、RadioGroup + Radio、Collapsible | 51.3 KiB |
| Base UI：上述集合再加 Drawer | 65.9 KiB |
| Motion：LazyMotion、domAnimation、AnimatePresence、m.div / m.section | 32.0 KiB |
| Motion：完整 motion + AnimatePresence | 46.2 KiB |
| Motion：LazyMotion、domMax、AnimatePresence、m.div / m.section | 46.3 KiB |
| Motion mini：useAnimate | 3.3 KiB |
| Lucide React：18 个具名图标 | 3.3 KiB |
| next-themes：ThemeProvider、useTheme | 1.5 KiB |

选 Base UI 意味着主动接受比 Radix 更大的部分基础代码，以换取统一的手机 Drawer 和表单/弹层体系；Drawer 不必进入每个阅读页面的关键加载路径。整站集成后如果预算超标，应先处理真正加载的组件、重复依赖和字体，再根据证据决定是否替换基础库。

首屏预算必须分别在 A/B/C、冷缓存、已保存主题直接进入时检查：JS/CSS 按压缩后体积，WOFF2 按实际下载体积。另报告首屏之后自动触发的字体和动效请求，不能把资源延迟几百毫秒就排除在性能讨论外。三主题各自通过才算通过。

证据保存于 `.impeccable/research/2026-11-04-theme-packages/`：

- `registry.json`：官方 npm registry 查询结果，含版本、发布时间、许可、peer dependencies 和仓库链接。
- `bundle-report.json` / `benchmark.mjs`：体积结果、色彩计算、构建参数与导入集合。
- `font-report.json` / `measure-fonts.py`：字体原始字节数及 C 草图文本的 unicode-range 估算。
- `package.json` / `package-lock.json`：仅供隔离实验复现；不是应用依赖变更。

复现时在该证据目录的临时副本执行 `npm ci --ignore-scripts --no-audit --no-fund`、`node benchmark.mjs`；字体脚本接收 `unfold.html` 的实际路径作为参数。本轮未进行整站构建、性能跑分或跨浏览器功能验收。

## 10. 版本、许可与维护判断

以下为 2026-11-04 查询快照，实施时需再次核对；列出版本不代表已经安装到产品或完成兼容验证。中文字体使用第 5 节记录的作者上游与字体文件版本。

| 包 | 本轮候选版本 | 许可 | 定位 |
| --- | --- | --- | --- |
| @base-ui/react | 1.9.0 | MIT | 主选；稳定 API，避免 preview 组件 |
| motion | 14.9.1 | MIT | 主选；仅使用需要的免费核心能力 |
| @fontsource-variable/bricolage-grotesque | 5.3.0 | OFL-1.1 | A 英文主字体 |
| @fontsource-variable/newsreader | 5.3.0 | OFL-1.1 | B 英文主字体 |
| @fontsource-variable/ibm-plex-sans | 5.3.0 | OFL-1.1 | C 英文主字体 |
| @fontsource/ibm-plex-mono | 5.3.0 | OFL-1.1 | 三主题代码与仓库标识 |
| lucide-react | 1.68.0 | ISC | 主选 SVG 图标 |
| colorjs.io | 0.7.1 | MIT | 开发阶段色彩计算 |
| @playwright/test | 1.64.1 | Apache-2.0 | 开发阶段浏览器验证 |
| @axe-core/playwright | 4.14.0 | MPL-2.0 | 开发阶段无障碍扫描 |
| radix-ui | 1.8.1 | MIT | 基础组件备选 |
| react-aria-components | 1.22.1 | Apache-2.0 | 基础组件备选 |
| @fontsource-variable/noto-sans-sc | 5.3.1 | OFL-1.1 | 字库基准与缺字回退候选，非主题主字体 |
| @tailwindcss/typography | 0.5.20 | MIT | 富正文条件备选 |
| next-themes | 0.4.6 | MIT | 主题状态条件备选 |

版本、peer 范围和许可来自 npm 官方 registry 的 package 元数据；不是全面的供应链审计。维护判断以稳定版本、明确文档和近期发布为依据，不用下载量或 GitHub 星数替代质量判断。例如 [Base UI 元数据](https://registry.npmjs.org/@base-ui/react/1.9.0)、[Motion 元数据](https://registry.npmjs.org/motion/14.9.1)。

不预装 Sonner、CVA、TanStack Table、React Hook Form / Zod 等整套组合：Base UI Toast 覆盖基础提示；主题由 CSS 变量处理；表格先按真实排序、选择和虚拟化需求决定；表单的服务器校验与前端状态层在实施设计时明确。需要具体能力时再引入，而不是把流行技术栈打包当成设计方案。

## 11. 下一步实施应证明什么

第一批落地选择一个真实条目、来源边界、主题选择器和 C 的展开区，接真实内容结构，在同一实现中切换 A/B/C。它应能证明布局、字体、交互与预算同时成立，再扩展到周刊、收藏搜索、账户与后台。

验证矩阵包括 360 / 390 / 768 / 1024 / 1440 px；长标题、纯英文仓库名、中英混排、500 字摘要、缺译文/理由、多个来源、空与失败状态；200% 文本缩放、键盘、焦点返回、减少动态、强制颜色和打印。手机还需真机检查虚拟键盘与触摸，Playwright WebKit 不能等同于 iPhone Safari 真机。

使用 Playwright 与 axe 做可自动发现的问题检查，补充人工键盘和读屏抽查；自动扫描不构成无障碍完整认证。[官方测试边界](https://playwright.dev/docs/accessibility-testing)

本轮完成的是选型、官方资料核对、隔离体积/字体/色彩测量，以及三套中英字体的桌面与手机样张验证。没有修改生产代码或应用依赖，也没有把正文理解、翻译、推荐依据的内容管道当作 UI 库能够解决的问题。
