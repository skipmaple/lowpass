---
name: Lowpass
description: 同一份中文友好的技术刊物，三套完整阅读主题；默认 A 层叠清晨。
colors:
  daybreak-paper: "#FCFAF2"
  daybreak-ink: "#203E30"
  daybreak-secondary: "#53675C"
  daybreak-rule: "#D5D9CC"
  daybreak-note: "#EEE8D6"
  daybreak-blue: "#005F65"
  daybreak-gold: "#C69F47"
  duet-paper: "#FCFCFA"
  duet-ink: "#161616"
  duet-secondary: "#565651"
  duet-rule: "#777772"
  duet-surface: "#F1F1ED"
  unfold-ground: "#111515"
  unfold-ink: "#ECEDE7"
  unfold-secondary: "#B2B9B5"
  unfold-rule: "#46504C"
  unfold-surface: "#23292A"
  unfold-accent: "#D0B775"
  unfold-accent-surface: "#C8AD62"
  daybreak-field-border: "#748D81"
  daybreak-readonly: "#F2F0E6"
  daybreak-secondary-hover: "#E1E4D8"
  daybreak-danger: "#9C3E2C"
  daybreak-danger-hover: "#7D3022"
  duet-primary-hover: "#383833"
  unfold-field: "#19201F"
  unfold-field-border: "#65736B"
  unfold-primary-hover: "#DDC98E"
  unfold-secondary-hover: "#303A38"
  unfold-danger: "#E6A18B"
  unfold-danger-hover: "#F1B9A7"
typography:
  daybreak-body:
    fontFamily: '"Lowpass Latin A", "Lowpass Chinese A", "PingFang SC", sans-serif'
    fontSize: "19px"
    lineHeight: 1.9
  duet-body:
    fontFamily: '"Lowpass Latin B", "Lowpass Chinese B", "Songti SC", serif'
    fontSize: "18px"
    lineHeight: 1.85
  unfold-body:
    fontFamily: '"Lowpass Latin C", "Lowpass Chinese C", "PingFang SC", sans-serif'
    fontSize: "19px"
    lineHeight: 1.95
  daybreak-display:
    fontFamily: '"Lowpass Latin A", sans-serif'
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "-0.04em"
  duet-display:
    fontFamily: '"Lowpass Latin B", serif'
    lineHeight: 1
    letterSpacing: "-0.04em"
  unfold-display:
    fontFamily: '"Lowpass Latin C", sans-serif'
    lineHeight: 1
    letterSpacing: "-0.04em"
  code:
    fontFamily: '"Lowpass Mono", monospace'
    fontWeight: 400
rounded:
  structural: "0px"
  daybreak-input: "8px"
  daybreak-button: "8px"
  daybreak-panel: "12px"
  daybreak-dialog: "14px"
  duet-input: "2px"
  duet-button: "4px"
  duet-panel: "4px"
  duet-dialog: "6px"
  unfold-input: "6px"
  unfold-button: "8px"
  unfold-panel: "10px"
  unfold-dialog: "12px"
spacing:
  frame: "1440px"
  gutter: "clamp(20px, 3.34vw, 48px)"
  mobile-gutter: "20px"
  editorial-inset: "24px"
  control-target: "44px"
components:
  daybreak-reason:
    backgroundColor: "{colors.daybreak-note}"
    textColor: "{colors.daybreak-ink}"
    rounded: "{rounded.structural}"
    padding: "24px 28px"
  duet-source-active:
    backgroundColor: "{colors.duet-ink}"
    textColor: "{colors.duet-paper}"
    rounded: "{rounded.structural}"
  unfold-reason:
    backgroundColor: "{colors.unfold-ground}"
    textColor: "{colors.unfold-ink}"
    rounded: "{rounded.structural}"
    padding: "24px 36px"
---

# Design System: Lowpass

## Overview

**Creative North Star: "层叠清晨 · 双声部 · 展开阅读"**

同一份按期、按来源整理的技术内容，提供三个有各自构图和字形的阅读世界。A 用明亮色面组织章节；B 让内容与判断沿中轴对读；C 让中文停留在安静的深色阅读面上。主题表达服务于理解、收藏和日后找回，不增加阅读任务、兴趣删选或装饰性信息。

本文件提取自 2026-11-05 的生产前端工作树，记录已经接入代码的视觉系统。默认 A；B/C 均为完整保留主题。不是线上部署记录，也不代表已完成实体手机、跨操作系统或全部浏览器验收。`PRODUCT.md` 和第二轮 spec 中“仅预览／待实现”的状态是方向阶段的历史快照；本文件只更新视觉实现事实，不改写其中的产品和内容管道要求。

**Key Characteristics:**

- 三套主题共享内容、路由和业务状态，分别定义字体、配色和版式。
- 有共同对齐基线的刊头、日期、导航与正文；文字的内边距和色面的外边界分别管理。
- 中文优先帮助理解，原文保留可核对入口，摘要与推荐理由分层。
- 表单、账户和管理页面延展主题，但以任务完成和真实状态为先。

实现依据：[主题令牌与外壳](app/frontend/styles/themes.css)、[阅读布局](app/frontend/styles/themes-reading.css)、[收藏与搜索布局](app/frontend/styles/themes-library.css)、[账户与辅助页面](app/frontend/styles/themes-admin.css)、[管理工作区](app/frontend/styles/themes-admin-workspace.css)、[操作控件与状态](app/frontend/styles/themes-controls.css)、[主题状态](app/frontend/lib/theme.ts)、[字体构建](script/build_theme_fonts)、[字体加载](app/frontend/lib/contentFonts.ts)、[打印](app/frontend/styles/print.css)。方向依据：[第二轮 spec](docs/superpowers/specs/2026-11-04-frontend-redesign-round2.md) 及其后用户逐项确认的预览；第一轮已否决草图不作为实现模板。

**历史规则覆盖。** 用户已明确选择三主题替换旧视觉世界。`.claude/skills/lowpass-design-taste/` 中旧纸纹、WenKai 和旧刊头外观规则不再支配这些页面；旧 skill 保留作历史材料，不在本轮修改。安全、数据不可变性、权限、内容契约和 CI 门禁继续有效。源码中遗留的“纸报／文楷／Maple”注释不能凌驾于当前主题令牌。

## Colors

前置 tokens 使用主题前缀，避免把三个世界压成一套通用色板。组件通过 `--paper / --ink / --ink2 / --rule / --surface / --accent` 等语义变量读取当前主题；A 的专属色面通过 `--theme-blue / --theme-green / --theme-gold` 使用。

| 主题 | 主色与用途 | 中性色与层次 |
| --- | --- | --- |
| A 层叠清晨 | 青蓝用于刊头、章节；松绿用于正文和来源导航；赭金用于日期、当前来源与结构收尾 | `daybreak-paper` 是明确锁定的底色；`daybreak-note` 区分理由，不能把赭金用作浅底正文 |
| B 双声部 | 黑白对读，当前来源反白；主导航使用文字下短线 | 黑墨和浅白提供对比；次级文字、细线和轻表面区分元信息，不借用 A 的色带或 C 的金色 |
| C 展开阅读 | 黄铜用于可定位的锚点、当前状态和理由标签；实色强调面使用单独的 accent-surface | 背景、阅读面和正文保持深浅层次；长段落采用浅色文字，不整段染金 |

**The Separate Worlds Rule.** 改进共同功能时共用语义和状态，不把 A 色面、B 中轴、C 深色平面混成同一个组件外观。

状态不能只靠颜色：来源失败有明确文字和警示图标；收藏同时改变文字与轮廓／实心；当前导航具备语义属性。高对比模式沿用可见边框与焦点。

`.impeccable/design.json` 中的八阶色带仅用于设计面板展示色彩关系，是从上述色值计算的预览，不是新增的生产调色盘；运行时仍只使用源码中已有的语义颜色。

## Typography

| 主题 | 中文字体 | 英文字体 | 已交付角色 |
| --- | --- | --- | --- |
| A | 寒蝉圆黑体 Chill Round Gothic | Bricolage Grotesque | 中文 Regular 400 / Bold 700；英文正文 400、显示字 800 |
| B | 寒蝉锦书宋 Chill Jinshu Song | Newsreader | 中文 Text Regular 400 / Bold 700；英文正文 400、显示字 700 |
| C | 未来荧黑 Glow Sans SC Normal | IBM Plex Sans | 中文 Regular 400 / Bold 700；英文正文 400、标题 600、日期角色 300 |

表中字体在构建产物中使用前置 tokens 的 `Lowpass Chinese A/B/C` 和 `Lowpass Latin A/B/C` 家族名；代码、命令使用 IBM Plex Mono 的 `Lowpass Mono`。系统字体只作回退。C 的正文保持正常宽度，窄字形只用于实际交付的日期字形角色；不能用横向缩放伪造字体。

日刊桌面主标题通常为 36px，正文与理由按主题保持前置 tokens 中的阅读节奏；手机主要标题约 26–30px，摘要约 17px，理由约 16px。理由标签为正文级大小，不能退化成难辨的小金字。来源、时间、域名与控制文字退到次级层，字号由其用途决定。长仓库名、URL、混合中文与英文必须允许换行。

字体由本地 WOFF2 提供，基础壳字符与内容字符分开；内容样式只加载当前主题，中文根据 `unicode-range` 请求分片。切换后浏览器可缓存已访问主题，不能宣称浏览器永远只下载一套。动态内容字库不是样刊字符子集；维护构建脚本和字体许可，不能以固定样刊截图代替完整字符覆盖检查。首屏预算继续由项目脚本和 CI 验证，本文件不代替性能验收结果。

## Layout

共用页面框最大宽度、左右边距和编辑内缩见前置 tokens。桌面内容不无限拉宽；色面可以延伸到外框，文字与控件仍沿明确基线。B 的共同中缝由 `--voice-seam` 计算，主文／序列／理由共享列定义；不能分别估计一个百分比导致来源块与中轴断开。

| 主题 | 日刊 | 收藏与搜索 | 管理 |
| --- | --- | --- | --- |
| A | 青蓝刊头、金色日期、松绿连续来源导航；左序号与正文；米色理由区 | 来源与日期在窄左列，名称、用途及操作在主列；模块标题保留色面 | 紧凑绿导航与蓝色操作标题，列表沿统一边界 |
| B | 黑底刊名与右侧日期；连续细线；桌面左文右理由、框中序号压在轴上 | 名称／用途和详情对读，序号保持同一中轴；没有详情时改用可用宽度 | 黑白刊头、短下划线导航、精确表格和清楚的状态图标 |
| C | 左侧刊期与来源索引，右侧单一深色阅读面；理由是其中独立一层，原文线索可展开 | 左侧模块名与右侧资料列表；详情低调展开 | 桌面窄侧栏导航、直接可扫读的内容，手机收为横向导航 |

主要转换点来自实际布局需求：1100px 调整刊头与内缩；1024px 调整后台；960px 将 B 对读和 C 阅读／收藏侧栏改为窄屏顺序；700px 切换紧凑刊头、20px 边距和正文密度；360px 再收紧导航。不是要求每个页面都在每个断点变形。来源数量可配置，空间不足时保留水平滚动或换行，不能裁去真实来源。

手机 B 将序号轴放在左边，保留框线，随后依次读同一条内容、判断和操作。手机 C 的日期由分行改成带斜杠的同行表示，来源索引改横排。A 的来源名可以合理折行。日期斜杠受字号和基线约束；日期展示使用 `/`，不修改查询参数、日期键或上海时区语义。

周刊采用单列长文宽度，完整保留提供的正文段落、配图本色和原文入口；当前正文按文本段落渲染，不承诺将代码或引用文本另行解析为富文本结构。不能把日刊的“值得关注”搬到没有该业务字段的周刊。打印将三主题转换为白底黑字、去掉色块装饰和交互控制，展开为可分页阅读结构；长条目允许跨页，不靠巨大不可拆盒子导致空页。打印规则不等于实体打印机验收。

## Elevation & Depth

结构由平面、细线、字重和留白建立。A 的米色理由区、C 的深浅阅读层是内容关系，不是悬浮卡片；B 用分栏线组织。菜单、确认和临时反馈读取独立的 panel 角色：A 用暖浅面与 `0 8px 24px rgb(32 62 48 / .14)` 轻阴影，B 用细墨边且不加阴影，C 用比底色更亮的暗面与 `0 12px 28px rgb(0 0 0 / .32)` 阴影。它们只用于浮层和临时反馈，不将正文卡片化；不使用玻璃模糊或光晕。

A 来源带用于向外延展的同色 `box-shadow` 是平面出血技术，不是阴影层级。C 左上折角由硬边界绘制，属于既定轮廓，不是渐变装饰。

## Shapes

刊物结构与操作控件采用不同的形态角色。刊头、来源带、中轴和序号框保持直线；操作控件按以下规则读取 `--control-radius / --button-radius / --panel-radius / --dialog-radius`。这覆盖此前一律直角的规则，并经用户批准；不以旧默认值否定三主题差异。

| 角色 | A 层叠清晨 | B 双声部 | C 展开阅读 |
| --- | --- | --- | --- |
| 输入 / 按钮 | 8px / 8px | 2px / 4px | 6px / 8px |
| 菜单 / 对话框 | 12px / 14px | 4px / 6px | 10px / 12px |
| 静态标签 | 4px | 2px | 4px |

A 用柔和边界与暖浅次面；B 保留搜索基线、细框与短下划线；C 用内收暗输入面和黄铜重点。B 的搜索输入保留基线表达，不能机械套用普通字段全框；前后期导航仍无底色且箭头贴边。C 折角只属于阅读平面。状态不用自造旗形、轨道或菱形。

图标使用 Lucide 的 24px 坐标系、1.75 描边，常用视觉尺寸 14–18px，收藏为 18px；图形尺寸和触控面积分别处理。装饰图标对辅助技术隐藏，独立表意的图标有可读名称。禁止重新引入不必要的 SVG 弹簧或路径变形运行时。

## Components

### 刊头、日期与导航

日刊、收藏、搜索在同一主题内共享品牌骨架，模块身份只在有用位置出现。主导航的选中态与来源导航承担不同层级：B 主导航为贴字短线，来源为反白面，两条区域无无意空缝。日期只在刊期身份处表达，前后期控件无背景、箭头靠两端；不可用项按真实前后期禁用，不伪造样刊翻期。

来源导航是连续一期内的定位，不是隐藏其他榜单的筛选器。空来源与抓取失败分开说明；缺理由保留条目并说明未补齐。管理员看到的失败、修订、抓取记录和可用操作来自真实 props，不能复制设计样例的状态。管理工作区样式随管理路由加载；账户与错误页的共享样式仍在入口，不因一次后台访问才出现。

### 内容、理由与原文

名称、中文说明、正文依据、原文入口具有不同职责。A 用米色理由面、B 用右侧对读、C 用同一深色语言中的独立区隔；不能为缺失理由造内容。原文标题与摘要可通过标准 disclosure 访问，切主题不重建整条内容。摘要回答内容是什么，理由解释具体价值或局限；换视觉不等于已完成模型内容质量建设。

### 收藏与搜索

导航和路由分别为“收藏”和“搜索”，不使用“书库”合并两者。全站搜索保持已有范围和筛选；收藏页有自己的关键词搜索、来源过滤、结果计数和重置，分页继续携带条件。条目使用真实名称、用途、来源、刊期和原文链接，空字段不补成示例内容。

收藏按钮有至少 44px 的操作高度，轮廓／实心与文字同步。确认带条目名称，使用 `role="status"` 播报，放在当前按钮附近；普通确认约 5 秒，撤销确认约 2 秒，下一次操作替换前次反馈。键盘焦点停在“撤销”时不会将按钮移除；请求失败由真实状态处理。收藏页取消后在原位提供恢复，避免突然删行导致焦点和阅读位置丢失。

### 主题选择与连续性

全站紧凑外观入口、账户设置和登录页使用同一个有标签的原生 radio 选择器。`lowpass-theme` 存当前浏览器偏好，默认及无效值回退 A；不随系统暗色自动切换，不新增账户跨设备同步。首屏在 React 初始化前应用偏好，避免先画错主题。

切换修改根节点主题和所需字体，保留同一组 React 表单与内容节点；搜索条件、输入、收藏、展开状态和路由不因主题而重新初始化。滚动位置优先取当前可见且带 id 的文章／章节作为锚点，布局变化后及字体加载后校正视口偏移，而非只恢复旧像素值。该策略是实现机制，不是对所有高度变化、无锚点页面或浏览器自动滚动的无条件保证。关闭外观入口后焦点回到可预测位置。外观菜单与账户菜单共用互斥状态；点外或焦点离开时关闭，Escape 关闭并返回触发器。账户菜单由方向键、Home/End 遍历，Tab 自然离开；外观选项使用原生 radio。候选小样展示各主题字形和构图，宿主浮层服从当前主题。

### 表单、状态与反馈

输入、日期、数值、select 和 textarea 共用语义角色，保留原生选择、验证和键盘能力。输入文字至少16px、主要操作目标不低于44px。A 字段边界为温和绿灰、B 为细墨灰、C 为低亮绿灰；普通边界与输入底色的对比分别约3.42、4.38、3.33。聚焦用2px主题轮廓；错误同时有加粗边界、图标和文字，A 用深赤色、B 保持黑白、C 用浅暖红。只读用低强调表面与虚线，仍可选取复制。

主按钮、次按钮、文字按钮、危险按钮分别读取角色；A 有色后台页头单独定义反向角色，避免主次操作同色。不可用控件不制造可点击反馈；正在提交用 `aria-busy`、等待文案及稳定尺寸区别于不可用。变化文案通过 PendingLabel 预留最大宽度；隐藏占位不参与无障碍名称。对话框的“不能确认”与“执行中”分开，未选来源仅禁用确认，仍能取消。危险确认显式标记 tone。来源多选有保留位置的勾选图标；只读 Chip 不继承可点击外观。Toast 和收藏反馈保留原有播报、撤销与时限，错误不只换一个图标。

管理输入保持明确标签、错误、说明、禁用、等待和成功状态。表格在窄屏使用同一份数据的紧凑记录布局，次要字段可展开；保留实际确认、记录入口和未保存草稿。警示用可读的检查／时钟／三角提示配文字，不用仅靠色块或装饰符号来表示健康度。第三方任务队列引擎内部页面不在本系统已覆盖范围内。

### 动效、焦点与减少动态效果

操作过渡使用 A 220ms、B 140ms、C 180ms：A 表面柔和变化和浮层4px轻入场，B 直接线条/反白反馈，C 明度/边界变化。取消旧的通用按钮底部填满动作；收藏共用轮廓/实心含义，只在A保留1px轻按反馈。阅读翻页保留已有时序，展开箭头约160–180ms。动效只解释状态、开合与导航结果，正文首屏不因装饰动画延迟出现；主题切换不执行整页淡出。全局焦点为 2px 描边，组件可用内偏移避开裁切。`prefers-reduced-motion: reduce` 使滚动与过渡近乎即时；内容和操作仍完整存在。

## Do's and Don'ts

### Do:

- **Do** 保留 A 为默认，并保持三套独立的字体、配色、构图。
- **Do** 将色面边界、文字内缩、图标可见边缘和触控边界分别检查，然后沿同一布局基线协调。
- **Do** 用真实长标题、仓库名、缺字段、空来源、失败、未保存表单检查桌面和手机。
- **Do** 保留键盘、可见焦点、减少动态效果与打印；检查加载字体后和切换主题后的布局。
- **Do** 用当前生产组件与令牌扩展页面，保持收藏、搜索、权限和路由的真实行为。

### Don'ts:

- **Don't** 把三套主题简化为换色，也不要把它们混成一个折中页面。
- **Don't** 恢复旧纸纹、WenKai 视觉或已否决的第一轮设计。
- **Don't** 给空来源、缺理由或缺译文编造内容，不把未收录误写成抓取失败。
- **Don't** 通过切换主题清空输入、重建页面、丢失展开状态或重复提交请求。
- **Don't** 为解决局部对齐而堆叠互相冲突的固定偏移；修正共用网格并复核相邻区域。
- **Don't** 把本地浏览器验证写成已上线、实体手机验收或内容生成质量已达标。
