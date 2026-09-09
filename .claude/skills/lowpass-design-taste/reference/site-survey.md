# niccolomiranda.com 调研记录（2026-09-09）

lowpass 视觉方向的唯一参考站。以下是用浏览器逐路由抓取的事实：计算样式、字体、颜色、边线、纹理、版式手法与文案口吻。截图见同目录 `ref-*.jpg`（首页、/work、项目页、/about、首页手机）。

## 站点与技术

- 标题 "Miranda — Paper Portfolio"；自述 "creating iconic digital experiences through motion, typography and creative coding"。
- Webflow 站点；GSAP 3.7、Locomotive Scroll 4.1（平滑滚动）、butter-slider（横向拖动）。
- 路由：`/`（Index）、`/work`（横向书脊画廊）、`/work/<slug>`（18 个项目页：wow-concept、the-roger-hub、avroko、cobo、thinkers、argor-heraeus、om-swami、the-books-of-ye、prada、the-hiring-chain、aquerone、sal-parasuco、edoardo-smerilli、chiara-luzzana、loftgarten、deplace-maison 等）、`/about`、`/legal`。汉堡菜单是整屏遮罩，三个词 Index / Work / About 用 Canopee 270px。

## 颜色（计算值）

| 角色 | 值 | 出现 |
|---|---|---|
| 墨 | `#1D1D1B` rgb(29,29,27) | html/body 背景就是墨色；所有文字、1px 边线、反白块的底 |
| 纸（深） | `#CDC6BE` rgb(205,198,190) | 反白块里的字、书脊上的 "New"、巨型反白标题 |
| 纸（浅，纹理图） | 约 `#E2DEDB` / `#D3CBC2` | 版面纸面是一张重复平铺的纸纹 JPG（pt-texture-2.jpg），不是纯色 |
| 强调橙 | `#C03F13` rgb(192,63,19) | 只用在 "NEW" 小标签的底色和邮票上的太阳纹；整站唯一彩色 |
| 半透墨线 | rgba(29,29,27,0.5) / 0.3 | 次级分隔线、椭圆按钮描边 |
| 灰 | `#69645F` | 极少，注脚 |

结论：两色系统加一个点缀色。纸不是纯色而是纹理；墨是接近黑的暖黑；橙只给"新"。

## 字体（计算值）

| 家族 | 字重 | 用途 | 尺寸与细节 |
|---|---|---|---|
| Canopee | 400 | 报头 MIRANDA、章节大标题（THE PIXEL PERFECT ARTISAN、HURRAH!、FEATURED WORK）、小标（TIP!、New、Email Me）、页脚社交链接 | 全大写；巨大：72 到 558px；字距 -5% 左右；行高 0.65 到 0.8 |
| Domaine Display | 500 | 书脊项目名、导航；并在 Canopee 标题里替换个别字母（"o""c""g"）做字形交替 | 大写；书脊 31.68px 字距 -6%；标题 64 到 446px |
| Editorial New | 300（正文）/ 500（少量强调） | 全部正文、导语、巨型陈述句、卡片文字、页脚 | 正文 17.28px / 行高 21.6px（1.25）字距 -1%；导语 24 到 37px；陈述句 79 到 105px 细体 |
| Germgoth | 400 | 获奖计数的大数字 | 158px |

规律：显示字体一律大写、负字距、超大；正文一律细体、紧行高、轻微负字距；字号随视口宽度按 vw 缩放（390px 宽时 body 8.4px，文字整体等比缩小而非重排）。

## 版式手法（可迁移的"装置"）

1. **报头式首屏**：整宽反白黑块里放巨字报头；上方一行三段：左小字地点（Amsterdam, NL）、中"The Paper Portfolio"、右汉堡。
2. **1px 墨线分栏**：栏与栏之间、区块之间全用 1px 墨线（出现 67 次），次级用 50% 墨线；没有阴影、没有圆角卡片。
3. **反白块**：把一个词或一行做成黑底纸字，既做标题（WEBSITE、STORY），也做行内强调（"PRADA""AKQA"），也做标签（ECOMMERCE、FASHION），也做按钮（EMAIL ME）。
4. **首字下沉**：段首字母放进 1px 方框（或黑底）里，Canopee。
5. **竖排文字**：`writing-mode: vertical-lr` 做书脊项目名、侧栏地点、年份、"New"。
6. **横向书脊画廊**（/work）：每个项目一条竖排书脊，点开后展开成标签、标题、简介、图；cursor grab，横向拖动。
7. **虚线框**：工作故事、经历卡用 1px 虚线框；实线框留给图片（1px 或 2.5px 黑边）。
8. **椭圆/胶囊按钮**：1px 半透墨线描边，全大写显示字体（ALL WORK、LIVE SITE），hover 字距变化。
9. **邮票与徽记**：右上角贴一枚邮票（橙色太阳纹、签名、日期），页脚一枚戳。
10. **撕纸边**：项目页首图与纸面之间是撕纸边缘。
11. **图片处理**：照片用 multiply 混合压进纸纹；手绘数字肖像（星星眼）；缩略图外加 1px 框，图下配小标题与两行说明。
12. **跑马灯页脚**："Let's create something together **EMAIL ME**" 无限横向滚动。
13. **计数板**：四个奖项计数，大数字（Germgoth）配小写说明，1px 线分隔。
14. **文案口吻**：短、第一人称、带感叹号（ALL WORK! / HURRAH! / TIP! Drag sideways to navigate）；小提示以 "TIP!" 起头。

## 动效（计算值）

- hover：letter-spacing 0.3s ease-in-out（字距拉开）。
- 描边圆圈：stroke-dashoffset 0.6s cubic-bezier(.785,.135,.15,.86)。
- 位移：transform 0.4s cubic-bezier(.65,0,.35,1)。
- 页面：Locomotive 平滑滚动、GSAP 入场、横向拖动画廊。

## 手机（390px）

单栏；所有装置保留并随 vw 等比缩小：反白报头、竖排改横排、首字下沉、虚线证言卡、跑马灯。整页 4400px 高，靠滚动消化，不删内容。

## 与 lowpass 的差别（提醒）

参考站是作品集，靠巨字与肖像制造戏剧性；lowpass 是每天要读的资讯刊物。lowpass 取其**材料与装置**（纸、墨、1px 线、反白块、竖排、邮戳、书脊式切换、撕纸/排线插图），不取其**尺度与自我表达**（558px 标题、肖像、感叹号文案）。
