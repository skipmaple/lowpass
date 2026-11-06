# 既有动效令牌对齐

设计 skill「动效」与交付自检 8 规定：时间动画仅用 120 / 240 / 360ms 和 `--ease-out` / `--ease-move`；D35 直接跟随滚动位置。本次修正既有声明里未遵守该约定的值，不增加交互或视觉装置。

## 浏览器前后证据

基线为 `c1f47954b56f4d8c08d58f02a9beab0ee61b8081`。在独立工作区的开发服务上，用隔离的无头 Chrome 155.0.8059.85、正常开发登录，读取真实 React 组件的 `getComputedStyle`；桌面 1440 × 1000，移动端 390 × 844。

| 实际组件 / 属性 | 修改前 | 修改后 |
| --- | --- | --- |
| 账户头像 / opacity | 160ms `ease` | 120ms `--ease-out` |
| HN 评论链接 / color | 160ms `ease` | 120ms `--ease-out` |
| 移动端筛选箭头 / transform | 120ms `ease` | 120ms `--ease-move` |
| 条目标题、搜索原文链接 / 下划线、color | 120ms `linear` | 120ms `--ease-out` |
| 菜单项、返回目录链接 / 下划线、color | 120ms `linear` | 120ms `--ease-out` |
| 描边控件 / color；分段控件 / 下划线 | 120ms `linear` | 120ms `--ease-out` |

`--ease-out` 实测为 `cubic-bezier(0.2, 0.7, 0.2, 1)`，`--ease-move` 为 `cubic-bezier(0.65, 0, 0.35, 1)`。验证了头像菜单打开与 Escape 关闭、评论悬停与键盘聚焦、标题/按钮/未选中分段项悬停、筛选开合。正常与减少动态效果模式共 31 处采样，过渡属性、交互终态、宽高与基线完全一致，浏览器无页面脚本错误。按钮墨层仍为既有的 240ms `--ease-out`。

减少动态效果模式仍沿用全局 1ms 收尾；头像、评论和箭头的 `transition-property` 为 `none`。菜单与筛选可直接到达相同终态。

头像用浏览器拦截的同源 `X-Inertia` JSON 响应夹具补充：仅将当前 QA 用户的 `avatar_url` 替换为内嵌 1px PNG，让真实 `AccountMenu` 渲染头像。未改数据库头像或刊期条目；交互验证只产生正常开发登录的 QA 用户/会话与搜索日志，未操作收藏、模型或后台写入口。临时脚本及原始采样保存在 `/tmp/lowpass-motion-token-alignment/`。

## 范围与检查

仅替换两份 CSS 中的七处过渡声明。D35 的空间进度计算、位移、尺寸、内容、减少动态效果规则均未修改；没有新增字面 CSS 值的镜像单元测试。

- `git diff --check` 通过。
- 浏览器基线、修改后正常/减少动态效果检查及 31 处前后断言通过。
- 完整 `bin/ci` 一次通过（2026-10-23）：前端 454 项、Rails 856 项 / 3763 断言、系统 77 项 / 8044 断言，均无失败、错误或跳过；首屏 264.56 KB / 300 KB。Ruby 风格、类型、构建、Gem audit、Brakeman、gitleaks 与 seeds 均通过。npm audit 按现有 high 门禁通过，同时报告现有 Vitest 相关的两项 moderate 告警；依赖与门禁未改。
