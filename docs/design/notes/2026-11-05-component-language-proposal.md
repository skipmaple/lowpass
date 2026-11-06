# A / B / C 操作组件差异化复核与修改提案

日期：2026-11-05。状态：**已获用户批准并实施；原审核发现保留如下。**

实施与验收见 [组件验收记录](2026-11-05-component-language-acceptance.md)。以下“本次”与“待批准”描述对应批准前的审核快照，不代表当前实现状态。

本次只新增审核报告、独立组件方案页及截图证据，没有修改应用源码、已确认预览、PRODUCT.md 或 DESIGN.md，没有业务写操作或 git 提交。工作树中已有的应用改动属于此前工作，不是本轮实施。

## 判断

用户指出的问题成立。刊头、字体、阅读布局已有主题差异，进入输入、筛选和浮层后，却又回到同一套“透明矩形、墨色全框、反白选中”的旧控件规则。圆角统一为零只是最明显的症状。

这是我此前验收遗漏的组件系统问题，不能靠逐个页面补 border-radius 解决。应把**刊物结构**与**可操作控件**分开：前者保留已确认的版式，后者建立各主题的形态、表面、层级和状态。

根因有三处：

- [DESIGN.md:53](/Users/drewlee/work/personal/lowpass/DESIGN.md:53) 与 [DESIGN.md:153](/Users/drewlee/work/personal/lowpass/DESIGN.md:153) 把控件形态统一约束为直角细线；这条规则需要随本次批准更新，不能用来否定用户的新要求。
- [application.css:15](/Users/drewlee/work/personal/lowpass/app/frontend/entrypoints/application.css:15) 把所有圆角工具令牌设为 0、阴影设为 none；组件内还存在显式 0 值和不读取圆角变量的样式。只改一个 `--radius` 不会修好全部控件。
- [tokens.css:84](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:84)、[motion.css:30](/Users/drewlee/work/personal/lowpass/app/frontend/styles/motion.css:30) 等旧规则仍决定输入、按钮、选择器及动效，主题样式主要改了外层布局和配色。

## 检查范围与证据边界

- 真实本地应用：登录、搜索、账户设置、后台新增来源，A/B/C 均看了 1440 和 390 CSS px；补查现有收藏与后台设置截图和源码。
- 实际操作：输入焦点、键盘 Tab、悬停、展开筛选、外观菜单、账户菜单、打开注销确认框。未确认注销，未提交表单、收藏或调用模型。
- 成功、失败、保存中等写请求结果本轮没有实际触发，其样式问题标为源码确认或实施后的待验项，不冒充已复现故障。
- 浏览器为隔离 Chrome 上下文；390 是浏览器窄屏验证，不是实体手机验收。
- 独立方案：[交互对照页](http://127.0.0.1:51935/component-review/index.html)。默认、悬停、焦点、选中、禁用、错误、就地确认有示例；不代表所有真实状态已实现。
- [桌面对照截图](/Users/drewlee/work/personal/lowpass/.impeccable/verification/component-language-2026-11-05/proposal-1440.png)、[390 对照截图](/Users/drewlee/work/personal/lowpass/.impeccable/verification/component-language-2026-11-05/proposal-390.png)。均无横向越界和浏览器脚本错误，输入高 48px。

## 12 组问题与建议

| 编号 | 现状与影响 | 建议修改方向 | 证据等级 |
| --- | --- | --- | --- |
| 01 形态体系 | 输入、按钮、select、菜单、dialog 统一直角；操作面和刊物结构未分工 | 建立输入、按钮、标签、浮层、对话框的独立角色；按 A/B/C 定值。保留刊头、来源色带、中轴、序号框的结构性直线 | 源码及浏览器确认 |
| 02 输入表面与边界 | 透明底＋全框跨主题复用；C 来源表单普通边框和焦点接近白色，框线争抢内容 | A 温润边界，B 细墨线，C 内收暗面＋较低亮度普通边；焦点另设明确层级。登录、日期、时间、数值、select、textarea 一起覆盖 | 源码及浏览器确认 |
| 03 按钮主次 | 通用主操作、次操作与登录按钮没有完整统一的角色规则；部分主题覆盖又把主次涂成同样外观 | 每套分别定义主、次、文字、危险动作；同一操作组有明确主次。C 不再用多个白色实块抢焦点；B hover 不能因 ink=accent 而无变化 | 主要形态已看；A 后台覆盖风险需实施时复现验收 |
| 04 搜索、筛选、标签 | 搜索和收藏查询同一条大下划线；单选分段、多选来源、只读状态标签又近似同一种方框 | A 柔和分组面，B 基线与细分隔，C 暗面与金色当前位置。多选有勾选线索；只读标签去掉可点击暗示。搜索与收藏继续是两个模块 | 源码及浏览器确认 |
| 05 焦点、错误、只读、等待 | field 已有 aria-invalid，却没有错误字段本体样式；readonly 没有独立规则；禁用与等待的视觉规范不完整；局部旧焦点覆盖主题焦点 | 焦点沿控件轮廓清楚显示；错误同时有字段边界、图标和文字；只读可复制；等待保留尺寸并有状态说明，不能只像不可用 | 默认/焦点实际看过；错误/等待等来自源码，真实结果待验 |
| 06 菜单与浮层 | 账户与外观菜单共用硬矩形；C 面板与背景同暗。另外两个菜单会同时打开并遮挡 | 按主题设计浮层表面和边缘；统一互斥、点外关闭、Escape、焦点返回。**菜单遮挡是实际功能缺陷，优先修** | 三主题均复现 |
| 07 外观选择与头像 | 主题选项主要是字母与色块，难预见阅读构图；顶栏方头像与账户页圆头像缺少一致规则 | 头像本体与按钮外壳分开规范；外观候选保留各自字体和小型构图预览，宿主面板服从当前主题。保持 radio 语义与顺序 | 源码及浏览器确认 |
| 08 Dialog 与遮罩 | 三套共用硬纸框、同样顶线、同样遮罩；C 靠亮边区分暗面 | A 柔和浮面，B 微圆精确框，C 比页面更亮的暗面；遮罩按明暗关系校准。确认对象与危险操作清楚，焦点圈和 Escape 保留 | 已打开真实确认框；未执行危险操作 |
| 09 Toast、收藏确认、静态状态 | 同一纸框和墨色；Toast kind 主要换图标；只读标签与可点控件容易混淆 | 短确认、可撤销确认、持续错误分别定义表现。A 浅暖面，B 编辑注记式细线，C 稍亮暗面；保留名称、撤销、播报、失败时限规则 | 源码确认；真实提交后状态待验 |
| 10 导航、分页与展开 | 来源导航虽然已有三主题，但旧 hover 选择器期待 inactive 属性，组件未输出；分页和周刊锚点仍继承旧 ctrl | 修 hover 状态接线，按各套已有导航语言延展。前后期继续无底色、箭头贴各自边缘；B 导航与来源栏接缝继续相连。展开区域起止更清楚 | hover 错接为源码确认；导航已有差异应保留 |
| 11 动效 | 大量 ctrl 都是同一墨块从底部漫上；菜单、dialog、收藏都沿用同一套动作 | A 柔和表面过渡，B 直接线条/反白反馈，C 小幅明度变化。取消不合场景的“填满”动画；不增加首屏等待、弹跳或装饰性运动 | 源码与部分真实 hover 确认 |
| 12 图标与密度 | 所有图标沿用同一网格与线宽；这本身不是缺陷，但未形成与三种字体相邻时的光学校准证据 | 保留同一图标语义与库，按控件/文字实测大小、基线和视觉重量；必要时微调。触控目标统一至少44px，不为差异化把 B 做小、C 做淡 | 当前尺寸/线宽已查；不宣称所有图标都有问题 |

### 一处已复现的 P1：两个菜单遮挡

在账户设置页打开外观 → 点击页面标题，外观仍开 → 打开账户，两个面板同时处于 open，外观面板遮住账户菜单。

[实际截图](/Users/drewlee/work/personal/lowpass/.impeccable/verification/component-language-2026-11-05/daybreak-1440-both-menus.png) · [三主题复现记录](/Users/drewlee/work/personal/lowpass/.impeccable/verification/component-language-2026-11-05/overlay-behavior.json)

另两张实际页面证据：[C 手机搜索的白框与反白筛选](/Users/drewlee/work/personal/lowpass/.impeccable/verification/component-language-2026-11-05/unfold-390-search-focus.png)、[C 真实确认框](/Users/drewlee/work/personal/lowpass/.impeccable/verification/component-language-2026-11-05/unfold-1440-dialog.png)。这些是当前应用，不是方案示意。

## 建议批准的三套方向

| 属性 | A 层叠清晨 | B 双声部 | C 展开阅读 |
| --- | --- | --- | --- |
| 操作气质 | 温润、亲和、清楚 | 精确、克制、编辑秩序 | 安静、专注、深浅分明 |
| 输入 / 按钮圆角 | 8px / 8px | 2px / 4px | 6px / 8px |
| 菜单 / dialog 圆角 | 12px / 12–14px | 4px / 4–6px | 10px / 12px |
| 主次按钮 | 松绿主面、暖浅次面、文字轻操作 | 黑色主面、细框次按钮、下划线轻操作 | 黄铜主操作、深色次面、文字轻操作 |
| 输入与焦点 | 温和边界，蓝绿焦点 | 细墨线，焦点加强边线 | 内收暗面，普通边弱于文字，金色焦点 |
| 筛选选中 | 浅色分组内的明确选中面 | 共同基线与局部墨色标记 | 稍亮暗面与金色标记 |
| 浮层层次 | 暖色浅浮面、克制软阴影 | 精确边界，主要靠规则与留白 | 独立暗面、低亮边、适度遮罩 |
| 反馈节奏起点 | 220ms 色彩/表面变化 | 140ms 直接状态变化 | 180ms 明度/边界变化 |

数值是这版可视提案的起点，不要求三套每个值都不同。A 与 C 按钮同为8px仍可有不同触感；B 功能控件有2–4px微圆角，也不影响刊头、中轴与序号框保持直线。

方案页引入了**待批准的语义色**，例如 C 输入面 `#19201F`、主按钮 hover `#DDC98E`，A 错误色 `#9C3E2C`、C 错误色 `#E6A18B`；它们不是此前已批准颜色。B 错误示例保留黑白，用更明确边界、图标和文字表达。实施时仍需逐个状态验证对比度，不能把旧主题的对比度结果沿用过来。

独立方案页只展示控件形态，没有替换登录布局，也没有把实际外观选择器改成三个文字按钮；真实选择器的 radio、候选小样和切换状态仍须保留。确认框、只读与提交等待状态在本页没有完整示意，方向见表，批准后在真实组件验收。

## 26 项源码核查索引

以下为可定位的实现覆盖范围；“共用”不自动等于错误，判断见上述12组。

| 项 | 位置 | 核查结论 |
| --- | --- | --- |
| 01 全局圆角/阴影 | [application.css:15](/Users/drewlee/work/personal/lowpass/app/frontend/entrypoints/application.css:15) | 所有 radius 为0、shadow为none，需角色化 |
| 02 通用 Field | [tokens.css:84](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:84) | 透明墨框、相同焦点 |
| 03 登录字段 | [themes-login.css:35](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes-login.css:35) | 主要只改高度、字号和边色 |
| 04 日期/数值/select | [tokens.css:370](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:370)、[themes-library.css:48](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes-library.css:48) | 与字段一起纳入皮肤，保留原生选择能力 |
| 05 搜索/收藏查询 | [themes-library.css:4](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes-library.css:4)、[themes-library.css:42](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes-library.css:42) | 相同底线输入规则 |
| 06 主次文字按钮 | [tokens.css:139](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:139)、[tokens.css:340](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:340) | 主次角色需完整主题状态 |
| 07 ctrl hover | [motion.css:30](/Users/drewlee/work/personal/lowpass/app/frontend/styles/motion.css:30) | 旧填满伪元素仍影响通用按钮 |
| 08 Seg / SegButtons | [tokens.css:354](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:354)、[Seg.tsx:14](/Users/drewlee/work/personal/lowpass/app/frontend/components/Seg.tsx:14) | 统一全框反白，另有内联文字色 |
| 09 来源多选 | [SearchFilters.tsx:49](/Users/drewlee/work/personal/lowpass/app/frontend/components/SearchFilters.tsx:49) | 与单选、只读标签区分不足 |
| 10 只读 Chip | [Chip.tsx:9](/Users/drewlee/work/personal/lowpass/app/frontend/components/Chip.tsx:9)、[tokens.css:173](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:173) | 内联实心样式；outline仍继承部分可点表现 |
| 11 Pager | [Pager.tsx:9](/Users/drewlee/work/personal/lowpass/app/frontend/components/Pager.tsx:9) | 两个旧ctrl，方向和顺序保持 |
| 12 周刊锚点 | [tokens.css:253](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:253) | 同一描边块，可沿主题导航延展 |
| 13 账户/头像 | [themes.css:51](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes.css:51)、[tokens.css:437](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:437) | 顶栏与设置页头像轮廓规则不一致 |
| 14 账户菜单 | [tokens.css:72](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:72) | 同纸面细框，浮层行为需与外观协调 |
| 15 外观/ThemePicker | [themes.css:78](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes.css:78) | 宿主菜单同构，候选已有字体/色块差异 |
| 16 Dialog | [tokens.css:473](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:473) | 同纸框、顶线、遮罩 |
| 17 Toast/收藏反馈 | [tokens.css:486](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:486)、[Toast.tsx:33](/Users/drewlee/work/personal/lowpass/app/frontend/components/Toast.tsx:33) | kind主要决定图标，容器缺少状态皮肤 |
| 18 错误/只读 | [Field.tsx:44](/Users/drewlee/work/personal/lowpass/app/frontend/components/Field.tsx:44) | 有错误语义但无完整视觉状态 |
| 19 焦点 | [themes.css:39](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes.css:39)、[tokens.css:88](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:88) | 全局accent被局部ink规则覆盖；焦点并非不存在 |
| 20 禁用/等待 | [tokens.css:626](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:626)、[themes-login.css:49](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes-login.css:49) | 分散规则，需完整矩阵 |
| 21 后台页头按钮 | [themes-admin.css:62](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes-admin.css:62) | A主次被同一选择器着色；禁用覆盖属待验风险 |
| 22 SourceTabs | [motion.css:47](/Users/drewlee/work/personal/lowpass/app/frontend/styles/motion.css:47)、[SourceTabs.tsx:126](/Users/drewlee/work/personal/lowpass/app/frontend/components/SourceTabs.tsx:126) | inactive选择器与实际属性不匹配 |
| 23 收藏按钮 | [themes.css:105](/Users/drewlee/work/personal/lowpass/app/frontend/styles/themes.css:105)、[motion.css:68](/Users/drewlee/work/personal/lowpass/app/frontend/styles/motion.css:68) | 图标语义正确，共用盖章动作需重新判断 |
| 24 图标 | [Icon.tsx:32](/Users/drewlee/work/personal/lowpass/app/frontend/components/Icon.tsx:32) | 24网格、1.75线宽，需光学核对而非强制三分 |
| 25 动效与展开 | [motion.css:5](/Users/drewlee/work/personal/lowpass/app/frontend/styles/motion.css:5)、[motion.css:138](/Users/drewlee/work/personal/lowpass/app/frontend/styles/motion.css:138) | 大量旧动作共用；优先减少不必要动作 |
| 26 原生选择器 | [tokens.css:641](/Users/drewlee/work/personal/lowpass/app/frontend/styles/tokens.css:641) | 保留checkbox/radio/select语义与系统面板，校准accent即可 |

## 批准后的实施边界与验收

建议批准三个部分：

1. **控件外观**：按本表的 A 温润 / B 精确 / C 安静方向，为输入、按钮、筛选、菜单、dialog、反馈建立角色令牌；同步修订旧 DESIGN 直角规则。
2. **状态完整性**：菜单互斥与关闭行为、hover接线、错误/只读/等待/禁用样式和级联冲突。真实行为保持一致，不按主题创造不同操作逻辑。
3. **光学与动效**：在真实组件默认状态稳定后，校准图标基线、相邻文字重量和少量过渡；不新增首屏动画或替换图标库。

保留：A底色#FCFAF2、三套字体、刊头与阅读布局、B中轴及无缝导航连接、C阅读折角、独立收藏/搜索、斜线日期、前后期无底色与箭头贴边。继续共用数据与功能、44px触控目标、键盘、可见焦点、原生表单、reduced motion与打印。

实施后用真实登录、日刊、周刊、收藏、搜索、账户、后台表单逐页验收，A/B/C在1440与390检查，补320与中间断点；覆盖默认、hover、键盘focus、选中、禁用、pending、invalid、readonly，以及长中文和空结果。切换主题时输入、筛选、收藏、展开和阅读位置不丢失。运行与改动相关的前端/系统测试及构建、首屏预算检查，再交付真实页面截图。

**后续决定：用户已明确要求“按照你的建议修改，然后验收”。本提案的控件外观、状态完整性、光学与动效三个部分均进入实施，见验收记录。**
