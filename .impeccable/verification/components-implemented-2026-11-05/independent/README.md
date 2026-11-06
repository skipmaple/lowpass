# 独立组件验收（2026-11-05）

环境：实际 Rails/Vite 前端 `http://127.0.0.1:3000`，Chrome。不是设计预览，也没有注入展示 CSS。

## 已完成

- A/B/C × 320px、768px × 登录、搜索、收藏、设置、新建来源：30 个页面组合。
- 30/30 无页面横向溢出、无表单控件越界；检查到的控件触区均不少于 44px。页面未报告 JavaScript error。
- 搜索展开筛选后再次检查；14px 来源多选标签在 320/768 均自然换行，选中前后宽度不变。
- 切换主题保留未提交搜索文字、搜索 URL/刊物筛选、收藏来源筛选、收藏搜索草稿、来源表单未保存名称；来源表单 DOM 未重挂载。
- 主题和账户菜单互斥；Escape 关闭并将焦点还给触发器；外部点击关闭；主题弹层未越过视口。
- 真实 Tab 验证登录字段、来源字段焦点可见；注销确认仅打开/取消，没有执行注销。
- 新增后台导航专项：A/B/C × 320/390，从页面起点连续 Tab 到最后项，再 Shift+Tab 返回首项；各项文字与焦点可见，导航内部滚动，页面纵向 scrollY 始终 0。

## 验收中发现并修正

1. C320 两行刊头主题按钮 top=0，2px 焦点环加 3px offset 超出视口 5px。仅在 <=360px 的 C 刊头增加 8px 顶部空间；复测按钮 top=8px，焦点环 top=3px。
2. 三套后台导航在 320px 下 Tab 到“任务队列”仍被横向裁切。主代理已补导航自身的最近距离滚动；320/390 正反 Tab 复测通过。
3. 来源表单保存按钮在 pending 时从 64px 增长至 109px。新增小型 PendingLabel 预留各自文案的最大尺寸，覆盖所有变更等待文案的后台操作和注销确认；三主题保存复测均为 109px→109px。额外后台 24 个组合（四页 × 三主题 × 320/768）无越界。

## 状态验收边界

常规 30 页与导航验收只使用 GET，所有非 GET/HEAD 请求均拦截。补充来源表单 pending/error 验收，在浏览器 route 中截获保存 POST，暂停后返回模拟 Inertia 字段错误；没有请求到服务器，没有保存、抓取或模型调用。相关截图文件名明确带 `mocked-response`。

- 只读仓库字段来自真实“阮一峰周刊”表单：可以 Tab 聚焦与选择复制，保留 readOnly，未被 disabled 代替。
- 模拟错误回包后，名称字段 aria-invalid=true，错误描述关联完整，焦点回到该字段。三主题错误颜色与字形按各自皮肤呈现。

## 证据入口

- `acceptance-results.json`：30 个组合的最终结果；收藏项来自等待筛选 GET 完成后的重测。
- `source-chip-final.json`：14px 字号、44px 触区、换行和选中稳定宽度。
- `focus-final.json`：C320 顶部焦点环修复后的测量。
- `admin-nav-keyboard-final.json`：320/390 连续 Tab 与反向 Shift+Tab。
- `form-states-mocked-response.json`：只读、pending、错误态；错误回包后等待 300ms 过渡完成再截图量测；明确标记 simulated 与 backendWrites=0。
- `pending-layout-final.json`：来源列表/新建来源/刊物管理/后台设置的 24 个组合，在全部等待文案已预留宽度后无溢出。
- `scripts/`：验收脚本，可复跑。
- `*-320-login-representative.png`、`*-320-search-final.png`：真实窄屏页面。
- `*-320-admin-nav-keyboard-final.png`：最终导航键盘焦点。
- `*-768-readonly-final.png`：真实只读字段。
- `*-768-pending-mocked-response.png` / `*-768-error-mocked-response.png`：实际 React 状态渲染，服务端回包由验收脚本模拟。

最初 `responsive-keyboard.json` 的六个收藏失败是验收等待条件错误：未等待 Inertia 筛选 GET 回包就输入草稿，晚到的响应覆盖草稿。修正脚本为等待 URL 和加载状态后，六个组合全部通过，记录在 `favorites-state-recheck.json`。不将这六个最初结果当作应用缺陷。

PendingLabel 与 Dialog 的可访问名称/禁用语义和受影响后台页面测试：8 个文件、69 项通过（2026-11-05 21:01）。隐藏占位文案不参与按钮可访问名称；当前状态文案完整保留。
