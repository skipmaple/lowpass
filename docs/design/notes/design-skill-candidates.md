# 温暖向设计 skill 候选（2026-09-08）

背景：斯堪的纳维亚方案（纯黑白、无彩）被否，方向改为温暖、明亮、积极。以下为核对过仓库内容的候选，供筛选。

## 风格型（拉进来即定调）

| 候选 | 来源与安装 | 已核对的要点 | 对 lowpass 的贴合 |
|---|---|---|---|
| Terracotta | bergside/awesome-design-skills，`npx typeui.sh pull terracotta` | 日晒陶土色的编辑风：奶油底 #F3E9D8，陶土主色 #C56A3C，墨色 #111827；DM Serif Display 加 JetBrains Mono；面向长文阅读 | 最贴合。暖而不闹，天然容纳文楷期头与等宽元数据 |
| Cafe | 同上，`pull cafe` | 咖啡馆：深棕 #5D4432、奶油 #E9E3DD、底 #F9F7F5、字色 #3E2B1E；Poppins 加 JetBrains Mono | 放松温暖，字体偏圆润，整体更"生活" |
| Claude 暖编辑 | VoltAgent/awesome-design-md 的 design-md/claude/DESIGN.md；rohitg00/awesome-claude-design 归入 Warm Editorial 家族 | 奶油 #f4f3ee、珊瑚 #c96442、墨 #191817，衬线大标 | 暖、人文、克制。品牌启发系统，只取色调与字体逻辑，不照搬 |
| Riso | 同 bergside，`pull riso` | 双色 risograph 印刷感：荧光粉 #F237A1 做交互、深蓝 #2C40A7 做层级，暖白底；Space Grotesk | 最阳光、最有个性，印刷感与"刊"契合；风险是花 |
| Friendly | 同 bergside，`pull friendly` | 柔和粉彩：玫瑰 #F2D9DC 与薄荷 #D9F2D8，白底，圆角；Noto Serif Display | 亲切但偏可爱，对技术资讯略轻 |
| Claymorphism | ifiokjr/oh-pi 或 telagod/oh-pi（LobeHub） | 黏土质感：大圆角 20 到 50、双层内阴影、方向外阴影；含 tokens 与卡片、按钮、输入、开关 | 友好有触感，但泡泡感伤阅读密度，只适合登录页与空态点缀 |
| Neubrutalism | telagod/oh-pi（LobeHub） | 粗边、偏移实心阴影、高饱和填色、平面 | 积极有力，但"硬"多于"暖" |

## 生成型（按关键词出一套暖系统）

| 候选 | 来源与安装 | 要点 | 贴合 |
|---|---|---|---|
| ui-ux-pro-max | nextlevelbuilder/ui-ux-pro-max-skill，`npm i -g ui-ux-pro-max-cli && uipro init --ai claude` | 79 种风格、192 套配色、74 组字体搭配，可用 playful、vibrant、warm、calm pastel 等词检索，输出含反模式的设计系统 | 能定制，但依赖重、通用感强 |
| Anthropic frontend-design | 本会话已装 | 先定调再写码，tone 可选 soft/pastel、organic/natural、playful | 零安装，风格由我们自己定义，例如"晨光橘黄" |

## 加成型（不是风格，是往暖处推）

pbakaus/impeccable 的 `bolder`（加视觉重量）与 `delight`（微动效），配合上面任一风格使用。

## 排除

- ericzakariasson/scandinavian-design：已否。
- 101mare/skill-library 的 warmgold-frontend：文档未给出任何色值与字体，无法核对。

## 建议

先试三套：Terracotta、Riso、Claude 暖编辑。把同一张日刊页各出一稿放到画布上比较。
