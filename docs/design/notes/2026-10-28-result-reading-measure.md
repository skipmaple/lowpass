# 搜索与收藏的阅读列

## 现场与选择

生产 `/search?q=Rust`，1270px 视口：一条 129 字符的 Hackaday 标题横跨整页；标题盒宽 1160px，摘要 820px，译文 780px。搜索与收藏共用同一组结果样式，日周刊则已有 780px 阅读列、1920px 以上 920px 阅读列。

标题、对应译文、摘要属于一个阅读单元，应共用行长；分隔线、底部操作与右侧书签仍属于全页列表。复用既有 780/920px，不新增卡片、不放大首条、不改变字体、色彩、内容与动作。

补齐同一版面的极端内容：连续英文长词允许必要时断开；来源名允许完整换行并增高，短来源名仍为 44px 目标。仅作用于搜索来源按钮，不改变被动标签。已选来源的移动筛选摘要也允许断行。

## 八项回看

本轮实际打开的参考：

- [Seasoned — Start with strategy](https://seasoned.koto.studio/book/start-with-strategy/)：主体文字限定在明确区域，纸材表现服务于阅读节奏。获奖入口：[Awwwards](https://www.awwwards.com/sites/seasoned)。本轮官方页面抓取超时，不把该抓取作为新的获奖事实证明。
- [The Trace 正文](https://www.thetrace.org/2026/10/gun-violence-redlining-jacksonville-fl/)：正文列与周边操作区分离，段落行长稳定。[Webby 2026 News & Politics 获奖记录](https://winners.webbyawards.com/winners/websites-and-mobile-sites/general-desktop-mobile-sites/news-politics)。
- [The Content Architecture 正文](https://www.contentarchitecture.dev/blog/the-content-architecture-four-months-in)：标题和正文遵循同一内容区域，字级承担主次；[FWA 获奖页](https://thefwa.com/cases/the-content-architecture)，本轮官方 RSS 明确列为 2026-10-20 FWA of the Day。

| 项目 | 本轮判断与动作 |
| --- | --- |
| 排版 | 结果标题没有阅读列约束是可复现差距；与译文、摘要统一，长词完整换行。 |
| 留白 | 正文右侧留白成为阅读列外的稳定空间；全宽墨线和操作行保持列表整体性。 |
| 视觉层次 | 同条标题与解释不再分属三种行长；标题、次墨正文和底部操作原有层级保留。 |
| 色彩 | 沿用纸／墨／次墨，选中来源仍反白；不照搬参考站的颜色。 |
| 动效 | 本轮未新增动画，筛选与翻页现有行为不变；静态对照不能证明整体动效已无差距。 |
| 微交互 | 长来源键盘 Enter 可筛选并保留焦点；需回归既有标题命中区与书签操作。 |
| 响应式 | 320/375/768px 长内容、481px 筛选展开断点、1440/1920px 阅读列回归。真实手机按用户要求跳过，Windows 未验收。 |
| 原创性 | 把纸报既有阅读列延伸到检索与收藏，维持跨页面的材料和字体角色；不是以复制参考站的构图证明原创。 |

这轮修正有明确收益，但八项整体获奖目标仍未证明完成，尤其整体动效与原创性不能用此次几何测试代替。

## 验证

- 修改前，3 项浏览器回归均因对应问题失败：宽屏标题 1160px 对译文 780px、320px 长词溢出、100 字来源名溢出。
- 修改后，检查搜索及收藏的阅读列与全宽书签、完整长词文字与实际字形边界、长来源的键盘选中及焦点、短来源 44px 高度。
- 独立只读评审未发现阻断问题；按其建议补上筛选后焦点与短名称高度验证。
- 完整本地 CI、远端门禁与部署后现场结果以本 PR 的实际运行记录为准。
